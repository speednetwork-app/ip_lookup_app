import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';

abstract class AppleAuditStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureAppleAuditStorage implements AppleAuditStorage {
  SecureAppleAuditStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'apple_purchase_audit_v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

/// Private on-device correlation/outbox, NOT an entitlement ledger.
/// No auth token, Apple account token, JWS, price or subscription URL is stored.
/// Owner email and opaque attempt/transaction identifiers stay in Keychain;
/// nothing here is logged or exported. Apple's queue retains the actual receipt.
class ApplePurchaseAudit {
  ApplePurchaseAudit({
    required this.service,
    required this.storage,
    required this.owner,
    required this.session,
    this.reportWait = const Duration(seconds: 5),
  });
  final AuthService service;
  final AppleAuditStorage storage;
  final String Function() owner, session;
  final Duration reportWait;
  Future<void> _writes = Future.value();
  Future<void>? _flushing;
  final Map<String, String> _launches = {};

  static String newId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  bool _current(String key, String account) =>
      key.isNotEmpty &&
      account.isNotEmpty &&
      session() == key &&
      owner() == account;

  Future<T> _edit<T>(T Function(List<Map<String, dynamic>>) action) {
    final result = Completer<T>();
    _writes = _writes.then((_) async {
      try {
        final raw = await storage.read();
        final decoded = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
        final rows =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final value = action(rows);
        // Retain every unresolved operation/outbox; only trim settled rows.
        while (rows.length > 100) {
          final index = rows.indexWhere((r) =>
              ['verified', 'cancelled', 'failed', 'prepare_rejected']
                  .contains(r['phase']) &&
              (r['events'] as List).isEmpty);
          if (index < 0) break;
          rows.removeAt(index);
        }
        await storage.write(jsonEncode(rows));
        result.complete(value);
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<Map<String, dynamic>> prepare(String key, String product) async {
    final account = owner();
    if (!_current(key, account)) throw StateError('Session changed');
    final row = await _edit((rows) {
      // Retry a lost prepare response with its SAME idempotency key. A prior
      // native cancellation gets a fresh request, explicitly linked to the old.
      final previous = rows
          .where((r) => r['owner'] == account && r['product'] == product)
          .toList();
      final last = previous.isEmpty ? null : previous.last;
      if (last != null && ['preparing', 'prepared'].contains(last['phase'])) {
        return Map<String, dynamic>.from(last);
      }
      final created = <String, dynamic>{
        'owner': account,
        'product': product,
        'request': newId(),
        'previous': last?['attempt'],
        'phase': 'preparing',
        'events': <dynamic>[],
      };
      rows.add(created);
      return Map<String, dynamic>.from(created);
    });
    if (!_current(key, account)) throw StateError('Session changed');
    Map<String, dynamic> intent;
    try {
      intent = await service.prepareApplePurchase(key, product,
          requestId: row['request'] as String,
          previousAttemptId: row['previous'] as String?);
    } on AuthException catch (error) {
      // Only an explicit refusal is terminal; a transport timeout is unknown.
      if (error.code == 'APPLE_PREPARE_REJECTED') {
        await _edit((rows) {
          for (final r in rows) {
            if (r['owner'] == account && r['request'] == row['request']) {
              r['phase'] = 'prepare_rejected';
            }
          }
        });
      }
      rethrow;
    }
    final id = intent['attempt_id'];
    if (id is! String || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      throw StateError('Invalid attempt');
    }
    await _edit((rows) {
      final saved = rows.firstWhere(
          (r) => r['owner'] == account && r['request'] == row['request']);
      saved['attempt'] = id;
      saved['phase'] = 'prepared';
    });
    if (!_current(key, account)) throw StateError('Session changed');
    return intent;
  }

  Future<void> launched(String key, String product, String attempt) async {
    final account = owner();
    if (!_current(key, account)) throw StateError('Session changed');
    await _edit((rows) {
      final row = rows.firstWhere((r) =>
          r['owner'] == account &&
          r['attempt'] == attempt &&
          r['product'] == product);
      row['phase'] = 'awaiting_apple';
    });
    if (!_current(key, account)) throw StateError('Session changed');
    _launches[account] = attempt;
  }

  Future<void> report(String key, String product, String event) async {
    final account = owner();
    if (!_current(key, account) ||
        !['pending', 'cancelled', 'failed', 'timeout'].contains(event)) {
      return;
    }
    final active = _launches[account];
    if (active == null) return; // Never guess a restored transaction's attempt.
    await _edit((rows) {
      for (final r in rows) {
        if (r['owner'] != account ||
            r['attempt'] != active ||
            r['product'] != product) {
          continue;
        }
        (r['events'] as List).add({'id': newId(), 'event': event});
        if (r['phase'] != 'verified') {
          r['phase'] = event == 'timeout' ? 'result_unknown' : event;
        }
      }
    });
    if ((event == 'cancelled' || event == 'failed') &&
        _launches[account] == active) {
      _launches.remove(account);
    }
    await flush(key);
  }

  Future<Map<String, dynamic>> verify(String key, String signed,
      {required String product,
      required String purchaseId,
      required bool liveCheckout}) async {
    final account = owner();
    if (!_current(key, account)) throw StateError('Session changed');
    String? attempt;
    // Local correlation failure must not stop verification of a paid receipt.
    try {
      attempt = await _edit((rows) {
        for (final r in rows.reversed) {
          if (r['owner'] != account || r['product'] != product) continue;
          if (r['purchase'] == purchaseId ||
              (liveCheckout &&
                  r['attempt'] == _launches[account] &&
                  r['purchase'] == null)) {
            r['purchase'] = purchaseId;
            return r['attempt'] as String?;
          }
        }
        return null;
      });
    } catch (_) {}
    if (!_current(key, account)) throw StateError('Session changed');
    final response =
        await service.verifyApplePurchase(key, signed, attemptId: attempt);
    if (response['acknowledged'] == true && attempt != null) {
      try {
        await _edit((rows) {
          for (final r in rows) {
            if (r['owner'] == account && r['attempt'] == attempt) {
              r['phase'] = 'verified';
            }
          }
        });
      } catch (_) {
        /* Server acknowledgement, not this journal, is authoritative. */
      }
      if (_launches[account] == attempt) _launches.remove(account);
    }
    return response;
  }

  Future<bool> hasUnresolved(String key) async {
    final account = owner();
    if (!_current(key, account)) return false;
    return _edit((rows) {
      final pending = rows
          .where((r) =>
              r['owner'] == account &&
              ['awaiting_apple', 'pending', 'result_unknown']
                  .contains(r['phase']))
          .toList();
      if (pending.length == 1) {
        _launches[account] = pending.single['attempt'] as String;
      }
      return pending.isNotEmpty;
    });
  }

  Future<void> flush(String key) async {
    if (_flushing != null) {
      return; // Next load/foreground will retry another owner.
    }
    final account = owner();
    if (!_current(key, account)) return;
    final task = _flush(key, account);
    _flushing = task;
    try {
      await task;
    } finally {
      _flushing = null;
    }
  }

  Future<void> _flush(String key, String account) async {
    try {
      final events = await _edit((rows) => [
            for (final r in rows)
              if (r['owner'] == account && r['attempt'] != null)
                for (final e in r['events'] as List)
                  {
                    'attempt': r['attempt'],
                    ...Map<String, dynamic>.from(e as Map)
                  },
          ]);
      for (final event in events) {
        if (!_current(key, account)) return;
        await service
            .reportApplePurchaseEvent(key,
                attemptId: event['attempt'] as String,
                eventId: event['id'] as String,
                event: event['event'] as String)
            .timeout(reportWait);
        // Lost replies are retried with the same event ID, not a fresh event.
        await _edit((rows) {
          for (final r in rows) {
            if (r['owner'] == account && r['attempt'] == event['attempt']) {
              (r['events'] as List)
                  .removeWhere((e) => (e as Map)['id'] == event['id']);
            }
          }
        });
      }
    } catch (_) {
      /* Durable outbox retries on the next authenticated foreground. */
    }
  }
}
