import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'apple_purchase_audit.dart';

abstract class AccountDeletionStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> operation);
  Future<void> clear();
}

class SecureAccountDeletionStorage implements AccountDeletionStorage {
  static const _key = 'account_deletion_operation_v1';
  static const _pendingKey = 'account_deletion_pending_v1';
  final _storage = const FlutterSecureStorage();
  @override
  Future<Map<String, dynamic>?> read() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_pendingKey) != true) return null;
    final value =
        await _storage.read(key: _key).timeout(const Duration(seconds: 5));
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<void> write(Map<String, dynamic> operation) async {
    // A non-sensitive hint only. Set it first so a process interruption cannot
    // hide a pending secure operation. It never authorizes deletion or cleanup.
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_pendingKey, true)) {
      throw StateError('Deletion marker unavailable');
    }
    await _storage
        .write(key: _key, value: jsonEncode(operation))
        .timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key).timeout(const Duration(seconds: 5));
    await (await SharedPreferences.getInstance()).remove(_pendingKey);
  }
}

Map<String, dynamic> newDeletionOperation(String owner) => {
      'owner': owner,
      'request_id': ApplePurchaseAudit.newId(),
      'receipt_secret': List.generate(32, (_) => Random.secure().nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    };
