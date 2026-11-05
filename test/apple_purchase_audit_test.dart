import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/services/apple_purchase_audit.dart';
import 'package:ip_lookup_app/services/auth_service.dart';

const product = 'isolated.monthly';
const appleToken = '33333333-2222-4333-8444-555555555555';

class MemoryAuditStorage implements AppleAuditStorage {
  String? value;
  bool unavailable = false;
  @override
  Future<String?> read() async {
    if (unavailable) throw StateError('ISOLATED_STORAGE_OUTAGE');
    return value;
  }

  @override
  Future<void> write(String text) async {
    value = text;
  }
}

class AuditFixture {
  AuditFixture() {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, handler) {
      calls.add(r);
      if ((r.path.endsWith('/event') && eventOffline) ||
          (r.path.endsWith('/prepare') && prepareOffline)) {
        handler.reject(DioException(
            requestOptions: r, type: DioExceptionType.connectionError));
        return;
      }
      final data = Map<String, dynamic>.from(r.data as Map);
      handler.resolve(Response(requestOptions: r, data: {
        'status': 'success',
        'data': r.path.endsWith('/prepare')
            ? {
                'product_id': data['product_id'],
                'app_account_token': appleToken,
                'attempt_id': attempts.putIfAbsent(
                    data['request_id'] as String, ApplePurchaseAudit.newId),
              }
            : {'acknowledged': true, 'active': true},
      }));
    }));
    service = AuthService(dio: dio);
  }
  final storage = MemoryAuditStorage();
  final calls = <RequestOptions>[];
  final attempts = <String, String>{};
  late final AuthService service;
  String account = 'ISOLATED_OWNER_A', key = 'ISOLATED_AUTH_A';
  bool eventOffline = false, prepareOffline = false;
  ApplePurchaseAudit create() => ApplePurchaseAudit(
      service: service,
      storage: storage,
      owner: () => account,
      session: () => key);
  List<Map<String, dynamic>> payloads(String suffix) => calls
      .where((r) => r.path.endsWith(suffix))
      .map((r) => Map<String, dynamic>.from(r.data as Map))
      .toList();
  Future<String> launch(ApplePurchaseAudit audit) async {
    final intent = await audit.prepare(key, product);
    await audit.launched(key, product, intent['attempt_id'] as String);
    return intent['attempt_id'] as String;
  }
}

void main() {
  test('UUID idempotency identifiers are random UUID v4', () {
    final ids = List.generate(50, (_) => ApplePurchaseAudit.newId());
    expect(ids.toSet(), hasLength(50));
    expect(
        ids.every((id) => RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id)),
        isTrue);
  });

  test('lost prepare response reuses request ID after restart', () async {
    final f = AuditFixture()..prepareOffline = true;
    await expectLater(
        f.create().prepare(f.key, product), throwsA(isA<AuthException>()));
    f.prepareOffline = false;
    await f.create().prepare(f.key, product);
    final calls = f.payloads('/prepare');
    expect(calls[0]['request_id'], calls[1]['request_id']);
    expect(calls[0].containsKey('price'), isFalse);
  });

  test(
      'unlaunched prepared intent is reused rather than creating another attempt',
      () async {
    final f = AuditFixture();
    final first = await f.create().prepare(f.key, product);
    final next = await f.create().prepare(f.key, product);
    expect(first['attempt_id'], next['attempt_id']);
  });

  test('cancel then retry creates a fresh attempt linked to the original',
      () async {
    final f = AuditFixture(), a = f.create();
    final first = await f.launch(a);
    await a.report(f.key, product, 'cancelled');
    final next = await f.launch(a);
    expect(next, isNot(first));
    expect(f.payloads('/prepare').last['previous_attempt_id'], first);
    expect(f.payloads('/event').single['event'], 'cancelled');
  });

  test('offline event is persisted and retried with its same event ID',
      () async {
    final f = AuditFixture()..eventOffline = true;
    final a = f.create();
    await f.launch(a);
    await a.report(f.key, product, 'timeout');
    final original = f.payloads('/event').single;
    f.eventOffline = false;
    await f.create().flush(f.key);
    expect(f.payloads('/event').last, original);
    expect((jsonDecode(f.storage.value!) as List).single['events'], isEmpty);
  });

  test(
      'pending state survives restart; observed native cancellation resolves it',
      () async {
    final f = AuditFixture(), a = f.create();
    await f.launch(a);
    await a.report(f.key, product, 'pending');
    final restored = f.create();
    expect(await restored.hasUnresolved(f.key), isTrue);
    await restored.report(f.key, product, 'cancelled');
    expect(await restored.hasUnresolved(f.key), isFalse);
  });

  test(
      'live receipt links to attempt; exact receipt recovery preserves that link',
      () async {
    final f = AuditFixture(), a = f.create();
    final id = await f.launch(a);
    await a.verify(f.key, 'ISOLATED.SIGNED.RECEIPT',
        product: product, purchaseId: '90000001', liveCheckout: true);
    await f.create().verify(f.key, 'ISOLATED.SIGNED.RECEIPT',
        product: product, purchaseId: '90000001', liveCheckout: false);
    expect(f.payloads('/verify').every((r) => r['attempt_id'] == id), isTrue);
    expect(await a.hasUnresolved(f.key), isFalse);
  });

  test(
      'restored older receipt never guesses the pending attempt from product alone',
      () async {
    final f = AuditFixture(), a = f.create();
    await f.launch(a);
    await a.verify(f.key, 'ISOLATED.OLD.RECEIPT',
        product: product, purchaseId: '90000000', liveCheckout: false);
    expect(f.payloads('/verify').single.containsKey('attempt_id'), isFalse);
    expect(await a.hasUnresolved(f.key), isTrue);
  });

  test('another login never flushes or attaches the old owner records',
      () async {
    final f = AuditFixture()..eventOffline = true;
    final a = f.create();
    await f.launch(a);
    await a.report(f.key, product, 'timeout');
    final count = f.calls.length;
    f.account = 'ISOLATED_OWNER_B';
    f.key = 'ISOLATED_AUTH_B';
    f.eventOffline = false;
    final b = f.create();
    await b.flush(f.key);
    expect(f.calls, hasLength(count));
    expect(await b.hasUnresolved(f.key), isFalse);
    await b.verify(f.key, 'ISOLATED.SIGNED.RECEIPT',
        product: product, purchaseId: '90000001', liveCheckout: false);
    expect(f.payloads('/verify').single.containsKey('attempt_id'), isFalse);
  });

  test('journal never persists credential, JWS, Apple account token or price',
      () async {
    final f = AuditFixture(), a = f.create();
    await f.launch(a);
    await a.verify(f.key, 'ISOLATED.SIGNED.RECEIPT',
        product: product, purchaseId: '90000001', liveCheckout: true);
    final value = f.storage.value!;
    for (final sensitive in [
      f.key,
      appleToken,
      'ISOLATED.SIGNED.RECEIPT',
      'price',
      'signed_transaction'
    ]) {
      expect(value, isNot(contains(sensitive)));
    }
  });

  test('journal outage cannot block verification of an already paid receipt',
      () async {
    final f = AuditFixture();
    f.storage.unavailable = true;
    final result = await f.create().verify(f.key, 'ISOLATED.SIGNED.RECEIPT',
        product: product, purchaseId: '90000001', liveCheckout: false);
    expect(result['acknowledged'], isTrue);
    expect(f.payloads('/verify').single.containsKey('attempt_id'), isFalse);
  });
}
