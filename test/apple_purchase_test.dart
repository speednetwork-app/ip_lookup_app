import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ip_lookup_app/main.dart';
import 'package:ip_lookup_app/models/store_plan.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/services/apple_purchase_controller.dart';
import 'package:ip_lookup_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const token = '11111111-2222-4333-8444-555555555555';
const plan = StorePlan(
    id: 800,
    name: 'ISOLATED',
    trafficGb: 500,
    speedLimitMbps: null,
    deviceLimit: null,
    offers: [
      StoreOffer(
          period: StorePeriod.monthly,
          productId: 'isolated.monthly',
          usdPriceMinor: 299)
    ]);

PurchaseDetails purchase([PurchaseStatus status = PurchaseStatus.purchased]) =>
    PurchaseDetails(
        purchaseID: '90000001',
        productID: 'isolated.monthly',
        verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'isolated.signed.fixture',
            source: 'app_store'),
        transactionDate: '123456',
        status: status)
      ..pendingCompletePurchase = true;

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final activeSubscription = <String, dynamic>{
    'product_id': 'isolated.monthly',
    'plan_id': 800,
    'environment': 'Sandbox',
    'status': 1,
    'active': true,
    'expires_at': 1900000000,
    'last_checked_at': 1800000000,
    'auto_renew_enabled': false,
  };

  for (final dark in [false, true]) {
    testWidgets('subscription controls remain usable with 2x text, dark=$dark',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.platformBrightnessTestValue =
          dark ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final controller = make(_Store(),
          status: (_) async => {
                'purchase_enabled': true,
                'restore_enabled': true,
                'subscription': {
                  ...activeSubscription,
                  'auto_renew_enabled': true,
                  'auto_renew_product_id': 'isolated.yearly'
                },
              });
      addTearDown(controller.dispose);
      await controller.load([plan]);
      await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MyApp(authProvider: _UiAuth(controller))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('商城').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('管理当前订阅'), 250,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(find.text('管理当前订阅').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('verified subscription is visible and cannot be purchased again',
      (tester) async {
    final store = _Store();
    final controller = make(store,
        status: (_) async => {
              'purchase_enabled': true,
              'restore_enabled': true,
              'subscription': activeSubscription,
            });
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.buy('isolated.monthly');
    expect(store.buyCalls, 0);
    await tester.pumpWidget(MyApp(authProvider: _UiAuth(controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('商城').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('沙盒测试'), findsOneWidget);
    expect(find.text('✓ 当前已订阅'), findsOneWidget);
    expect(find.text('管理当前订阅'), findsOneWidget);
    expect(find.text('通过 Apple 订阅'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('acknowledged subscription survives a display-refresh outage', () async {
    final store = _Store();
    final controller = make(store,
        status: (_) async => throw StateError('isolated outage'),
        verify: (_, __) async => {
              'acknowledged': true,
              'active': true,
              'subscription': activeSubscription
            });
    addTearDown(controller.dispose);
    store.events.add([purchase()]);
    await flush();
    expect(store.completions, 1);
    expect(controller.currentSubscription?.active, isTrue);
    expect(controller.canBuy('isolated.monthly'), isFalse);
    expect(controller.error, contains('刷新失败'));
    controller.sessionChanged();
    expect(controller.currentSubscription, isNull);
  });

  test('late pre-purchase status cannot erase the acknowledged subscription',
      () async {
    final store = _Store();
    final beforePurchase = Completer<Map<String, dynamic>>();
    var reads = 0;
    final controller = make(store,
        status: (_) async {
          if (++reads == 1) return beforePurchase.future;
          return {
            'purchase_enabled': true,
            'restore_enabled': true,
            'subscription': activeSubscription
          };
        },
        verify: (_, __) async => {
              'acknowledged': true,
              'active': true,
              'subscription': activeSubscription
            });
    addTearDown(controller.dispose);
    final loading = controller.load([plan]);
    store.events.add([purchase()]);
    await flush();
    beforePurchase.complete({
      'purchase_enabled': true,
      'restore_enabled': true,
      'subscription': null
    });
    await loading;
    expect(controller.currentSubscription?.productId, 'isolated.monthly');
    expect(controller.canBuy('isolated.monthly'), isFalse);
  });

  test('refresh updates cancellation and expiry without granting locally',
      () async {
    final store = _Store();
    var state = activeSubscription;
    final controller = make(store,
        status: (_) async => {
              'purchase_enabled': true,
              'restore_enabled': true,
              'subscription': state
            });
    addTearDown(controller.dispose);
    await controller.load([plan]);
    expect(controller.currentSubscription?.autoRenewEnabled, isFalse);
    state = {...activeSubscription, 'active': false, 'status': 5};
    await controller.refreshStatus();
    expect(controller.currentSubscription?.stateLabel, '订阅已撤销');
    expect(controller.canBuy('isolated.monthly'), isTrue);
  });

  for (final currency in ['USD', 'EUR']) {
    testWidgets('store distinguishes live Apple quote from USD list: $currency',
        (tester) async {
      final controller = make(_Store(quote: 4.99, currency: currency));
      addTearDown(controller.dispose);
      await controller.load([plan]);
      await tester.pumpWidget(MyApp(authProvider: _UiAuth(controller)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('商城').last);
      await tester.pumpAndSettle();
      if (currency == 'USD') {
        expect(find.text('\$4.99 / 月'), findsOneWidget);
        expect(find.text('\$2.99 / 月'), findsNothing);
        expect(find.textContaining('US\$'), findsNothing);
      } else {
        expect(find.text('\$2.99 / 月'), findsOneWidget);
        expect(find.text('Apple 结算价：€4.99 / 月'), findsOneWidget);
      }
      expect(find.text('恢复购买'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('Apple API uses authenticated endpoints, never sends a client price',
      () async {
    final calls = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      calls.add(request);
      handler.resolve(Response(requestOptions: request, data: {
        'status': 'success',
        'data': {'acknowledged': true}
      }));
    }));
    final api = AuthService(dio: dio);
    await api.getAppleIapStatus('session-only-fixture');
    await api.prepareApplePurchase('session-only-fixture', 'isolated.monthly');
    await api.verifyApplePurchase(
        'session-only-fixture', 'isolated.signed.fixture');
    expect(calls.map((r) => r.path), [
      '/user/apple/iap/status',
      '/user/apple/iap/prepare',
      '/user/apple/iap/verify'
    ]);
    expect(calls.map((r) => r.method), ['GET', 'POST', 'POST']);
    expect(
        calls.every(
            (r) => r.headers['Authorization'] == 'Bearer session-only-fixture'),
        isTrue);
    expect(calls[1].data, {'product_id': 'isolated.monthly'});
    expect(calls[2].data, {'signed_transaction': 'isolated.signed.fixture'});
  });

  test('purchase stays closed when backend flag is off', () async {
    final store = _Store();
    final controller = make(store, enabled: false);
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.buy('isolated.monthly');
    expect(controller.canBuy('isolated.monthly'), isFalse);
    expect(store.buyCalls, 0);
    expect(store.completions, 0);
  });

  test('only server issued UUID is passed to Apple purchase', () async {
    final store = _Store();
    final controller = make(store);
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.buy('isolated.monthly');
    expect(store.accountToken, token);
    expect(store.buyCalls, 1);
    expect(controller.busy, isTrue);
    expect(store.completions, 0);
  });

  test(
      'unknown products and invalid server account token cannot start purchase',
      () async {
    final store = _Store();
    final controller = make(store,
        prepare: (_, __) async => {
              'product_id': 'isolated.monthly',
              'app_account_token': 'not-a-uuid'
            });
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.buy('unknown');
    await controller.buy('isolated.monthly');
    expect(store.buyCalls, 0);
    expect(controller.error, isNotEmpty);
  });

  for (final status in [PurchaseStatus.purchased, PurchaseStatus.restored]) {
    test('completes $status only after durable server acknowledgement',
        () async {
      final store = _Store();
      final gate = Completer<Map<String, dynamic>>();
      final controller = make(store, verify: (_, __) => gate.future);
      addTearDown(controller.dispose);
      store.events.add([purchase(status)]);
      await flush();
      expect(store.completions, 0);
      gate.complete({'acknowledged': true, 'active': true});
      await flush();
      expect(store.completions, 1);
      expect(controller.message, contains('套餐已更新'));
    });
  }

  test('verification failure leaves transaction unfinished for retry',
      () async {
    final store = _Store();
    var available = false;
    final controller = make(store, verify: (_, __) async {
      if (!available) throw StateError('isolated outage');
      return {'acknowledged': true, 'active': true};
    });
    addTearDown(controller.dispose);
    store.events.add([purchase()]);
    await flush();
    expect(store.completions, 0);
    expect(controller.error, isNotEmpty);
    expect(controller.message, isEmpty);
    expect(controller.busy, isFalse);
    available = true;
    store.events.add([purchase(PurchaseStatus.restored)]);
    await flush();
    expect(store.completions, 1);
  });

  test(
      'verification timeout releases recovery and ignores late acknowledgement',
      () async {
    final store = _Store()..unfinishedRecords = [purchase()];
    final stalled = Completer<Map<String, dynamic>>();
    var recovered = false;
    final controller = make(store,
        verificationWait: const Duration(milliseconds: 15),
        verify: (_, __) => recovered
            ? Future.value({'acknowledged': true, 'active': true})
            : stalled.future);
    addTearDown(controller.dispose);
    await controller.load([plan]);
    expect(controller.busy, isFalse);
    expect(controller.message, isEmpty);
    expect(controller.error, contains('超时'));
    expect(controller.canRestore, isTrue);
    expect(controller.canBuy('isolated.monthly'), isFalse);
    stalled.complete({'acknowledged': true, 'active': true});
    await flush();
    expect(store.completions, 0);
    recovered = true;
    await controller.checkPurchases();
    expect(store.completions, 1);
    expect(controller.needsRecovery, isFalse);
  });

  test('restore timeout ends progress without dropping unfinished transactions',
      () async {
    final store = _Store()..restoreAction = () => Completer<void>().future;
    final controller =
        make(store, operationWait: const Duration(milliseconds: 15));
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.restore();
    expect(controller.busy, isFalse);
    expect(controller.message, isEmpty);
    expect(controller.error, isNotEmpty);
    expect(controller.canRestore, isTrue);
    expect(store.completions, 0);
    store.events.add([purchase()]);
    await flush();
    expect(store.completions, 1);
  });

  test('foreign-account receipt is retained without futile restore loops',
      () async {
    final store = _Store()..unfinishedRecords = [purchase()];
    var session = 'different-account';
    var verifies = 0;
    final controller = make(store,
        session: () => session,
        verify: (_, __) async {
          verifies++;
          if (session == 'different-account') {
            throw const AuthException('请切回原购买账号恢复',
                code: 'APPLE_ACCOUNT_MISMATCH');
          }
          return {'acknowledged': true, 'active': true};
        });
    addTearDown(controller.dispose);
    await controller.load([plan]);
    expect(controller.accountMismatch, isTrue);
    expect(controller.message, isEmpty);
    expect(controller.busy, isFalse);
    await controller.checkPurchases();
    await controller.restore();
    expect(verifies, 1);
    expect(store.restoreCalls, 0);
    expect(store.completions, 0);
    expect(controller.error, contains('原购买账号'));
    expect(controller.canBuy('isolated.monthly'), isFalse);
    session = 'original-account';
    controller.sessionChanged();
    await controller.load([plan]);
    expect(controller.accountMismatch, isFalse);
    expect(verifies, 2);
    expect(store.completions, 1);
  });

  testWidgets('failed verification offers a working route out of the store',
      (tester) async {
    final store = _Store()..unfinishedRecords = [purchase()];
    final controller = make(store, verify: (_, __) async {
      throw const AuthException('请切回原购买账号恢复', code: 'APPLE_ACCOUNT_MISMATCH');
    });
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await tester.pumpWidget(MyApp(authProvider: _UiAuth(controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('商城').last);
    await tester.pumpAndSettle();
    expect(find.text('正在验证 Apple 购买…'), findsNothing);
    await tester.tap(find.text('前往我的，切换原购买账号'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);
    expect(store.completions, 0);
    expect(tester.takeException(), isNull);
  });

  test(
      'closing native subscription management refreshes cancellation, not expiry',
      () async {
    final store = _Store();
    var autoRenew = true;
    store.manageAction = () async {
      autoRenew = false;
    };
    final controller = make(store,
        status: (_) async => {
              'purchase_enabled': true,
              'restore_enabled': true,
              'subscription': {
                ...activeSubscription,
                'auto_renew_enabled': autoRenew
              },
            });
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.manageSubscriptions();
    expect(store.manageCalls, 1);
    expect(controller.currentSubscription?.autoRenewEnabled, isFalse);
    expect(controller.currentSubscription?.active, isTrue);
    expect(controller.canBuy('isolated.monthly'), isFalse);
    expect(controller.canManage, isTrue);
    expect(store.completions, 0);
  });

  test(
      'known account conflict is not treated as login expiry or raw server text',
      () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      handler.reject(DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: request, statusCode: 409, data: {
            'error_code': 'APPLE_ACCOUNT_MISMATCH',
            'message': 'PRIVATE_SENTINEL'
          })));
    }));
    try {
      await AuthService(dio: dio)
          .verifyApplePurchase('isolated-session', 'isolated.signed.fixture');
      fail('Expected account conflict');
    } on AuthException catch (error) {
      expect(error.code, 'APPLE_ACCOUNT_MISMATCH');
      expect(error.isUnauthorized, isFalse);
      expect(error.message, isNot(contains('PRIVATE_SENTINEL')));
    }
  });

  test('unacknowledged server response never finishes transaction', () async {
    final store = _Store();
    final controller = make(store, verify: (_, __) async => {'active': true});
    addTearDown(controller.dispose);
    store.events.add([purchase()]);
    await flush();
    expect(store.completions, 0);
  });

  test(
      'logout during verification cannot finish or report success to another account',
      () async {
    final store = _Store();
    var session = 'original-session';
    final gate = Completer<Map<String, dynamic>>();
    final controller =
        make(store, session: () => session, verify: (_, __) => gate.future);
    addTearDown(controller.dispose);
    store.events.add([purchase()]);
    await flush();
    session = 'different-session';
    controller.sessionChanged();
    gate.complete({'acknowledged': true, 'active': true});
    await flush();
    expect(store.completions, 0);
    expect(controller.message, isEmpty);
  });

  test('disposed controller ignores late verifier result', () async {
    final store = _Store();
    final gate = Completer<Map<String, dynamic>>();
    final controller = make(store, verify: (_, __) => gate.future);
    store.events.add([purchase()]);
    await flush();
    controller.dispose();
    gate.complete({'acknowledged': true, 'active': true});
    await flush();
    expect(store.completions, 0);
  });

  test('pending and cancelled events never grant or finish purchases',
      () async {
    final store = _Store();
    var verifies = 0;
    final controller = make(store, verify: (_, __) async {
      verifies++;
      return {'acknowledged': true};
    });
    addTearDown(controller.dispose);
    store.events.add([purchase(PurchaseStatus.pending)]);
    await flush();
    expect(controller.busy, isFalse);
    expect(controller.awaitingApple, isTrue);
    store.events.add([purchase(PurchaseStatus.canceled)]);
    await flush();
    expect(controller.busy, isFalse);
    expect(controller.awaitingApple, isFalse);
    expect(verifies, 0);
    expect(store.completions, 0);
  });

  test('restore request without transactions does not claim restored access',
      () async {
    final store = _Store();
    final controller = make(store);
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.restore();
    expect(store.restoreCalls, 1);
    expect(controller.message, isNot(contains('套餐已更新')));
    expect(store.completions, 0);
  });

  test('cancelled and failed checkout can be retried without granting access',
      () async {
    final store = _Store();
    final controller = make(store);
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.buy('isolated.monthly');
    store.events.add([purchase(PurchaseStatus.canceled)]);
    await flush();
    expect(controller.canBuy('isolated.monthly'), isTrue);
    await controller.buy('isolated.monthly');
    store.events.add([purchase(PurchaseStatus.error)]);
    await flush();
    expect(controller.canBuy('isolated.monthly'), isTrue);
    expect(store.buyCalls, 2);
    expect(store.completions, 0);
  });

  test('real pending approval never times out into a new purchase', () async {
    final store = _Store();
    final controller = make(store);
    addTearDown(controller.dispose);
    await controller.load([plan]);
    store.events.add([purchase(PurchaseStatus.pending)]);
    await flush();
    expect(controller.canRestore, isTrue);
    await controller.checkPurchases();
    await controller.buy('isolated.monthly');
    expect(controller.awaitingApple, isTrue);
    expect(controller.busy, isFalse);
    expect(store.buyCalls, 0);
    expect(store.completions, 0);
  });

  test(
      'duplicate native transaction recovers original, never auto charges again',
      () async {
    final store = _Store();
    Map<String, dynamic>? subscription;
    final gate = Completer<Map<String, dynamic>>();
    final controller = make(store,
        status: (_) async => {
              'purchase_enabled': true,
              'restore_enabled': true,
              'subscription': subscription
            },
        verify: (_, __) async {
          final result = await gate.future;
          subscription = activeSubscription;
          return result;
        });
    addTearDown(controller.dispose);
    await controller.load([plan]);
    store.unfinishedRecords = [purchase()];
    store.buyError =
        PlatformException(code: 'storekit_duplicate_product_object');
    final attempt = controller.buy('isolated.monthly');
    await flush();
    expect(store.completions, 0);
    gate.complete({
      'acknowledged': true,
      'active': true,
      'subscription': activeSubscription
    });
    await attempt;
    expect(store.completions, 1);
    expect(store.buyCalls, 1);
    expect(controller.currentSubscription?.active, isTrue);
    expect(controller.canBuy('isolated.monthly'), isFalse);
  });

  test(
      'unfinished scan after relaunch never finishes an unacknowledged payment',
      () async {
    final store = _Store()..unfinishedRecords = [purchase()];
    final controller = make(store,
        verify: (_, __) async => throw StateError('isolated verify outage'));
    addTearDown(controller.dispose);
    await controller.load([plan]);
    expect(store.completions, 0);
    expect(controller.needsRecovery, isTrue);
    expect(controller.canBuy('isolated.monthly'), isFalse);
  });

  test('scan outage blocks new payment until a successful recovery check',
      () async {
    final store = _Store()..failScan = true;
    final controller = make(store);
    addTearDown(controller.dispose);
    await controller.load([plan]);
    expect(controller.canBuy('isolated.monthly'), isFalse);
    store.failScan = false;
    await controller.checkPurchases();
    expect(controller.canBuy('isolated.monthly'), isTrue);
  });

  test('long checkout unlocks status actions, not a duplicate payment',
      () async {
    final store = _Store();
    final controller =
        make(store, checkoutWait: const Duration(milliseconds: 20));
    addTearDown(controller.dispose);
    await controller.load([plan]);
    await controller.buy('isolated.monthly');
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(controller.busy, isFalse);
    expect(controller.canRestore, isTrue);
    expect(controller.awaitingApple, isTrue);
    expect(controller.canBuy('isolated.monthly'), isFalse);
    store.events.add([purchase(PurchaseStatus.canceled)]);
    await flush();
    expect(controller.canBuy('isolated.monthly'), isTrue);
    expect(store.completions, 0);
  });
}

ApplePurchaseController make(AppleStoreGateway store,
        {bool enabled = true,
        String Function()? session,
        Duration checkoutWait = const Duration(seconds: 90),
        Duration verificationWait = const Duration(seconds: 65),
        Duration operationWait = const Duration(seconds: 20),
        Future<Map<String, dynamic>> Function(String, String)? prepare,
        Future<Map<String, dynamic>> Function(String)? status,
        Future<Map<String, dynamic>> Function(String, String)? verify}) =>
    ApplePurchaseController(
        store: store,
        checkoutWait: checkoutWait,
        verificationWait: verificationWait,
        operationWait: operationWait,
        session: session ?? () => 'isolated-session',
        statusRequest: status ??
            (_) async =>
                {'purchase_enabled': enabled, 'restore_enabled': enabled},
        prepareRequest: prepare ??
            (_, id) async => {'product_id': id, 'app_account_token': token},
        verifyRequest:
            verify ?? (_, __) async => {'acknowledged': true, 'active': true},
        onEntitled: () async {});

class _Store implements AppleStoreGateway {
  _Store({this.quote = 2.99, this.currency = 'USD'});
  final double quote;
  final String currency;
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  int completions = 0, buyCalls = 0, restoreCalls = 0, manageCalls = 0;
  Future<void> Function()? restoreAction, manageAction;
  String? accountToken;
  List<PurchaseDetails> unfinishedRecords = [];
  Object? buyError;
  bool failScan = false;
  @override
  bool get supported => true;
  @override
  Stream<List<PurchaseDetails>> get updates => events.stream;
  @override
  Future<bool> available() async => true;
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: [
        ProductDetails(
            id: 'isolated.monthly',
            title: 'ISOLATED',
            description: 'ISOLATED',
            price:
                '${currency == 'USD' ? '\$' : '€'}${quote.toStringAsFixed(2)}',
            rawPrice: quote,
            currencyCode: currency)
      ], notFoundIDs: []);
  @override
  Future<bool> buy(ProductDetails product, String token) async {
    buyCalls++;
    if (buyError != null) throw buyError!;
    accountToken = token;
    return true;
  }

  @override
  Future<List<PurchaseDetails>> unfinished() async {
    if (failScan) throw StateError('isolated scan outage');
    return unfinishedRecords.toList();
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
    await restoreAction?.call();
  }

  @override
  Future<void> manageSubscriptions() async {
    manageCalls++;
    await manageAction?.call();
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    completions++;
    unfinishedRecords.removeWhere((p) => p.purchaseID == purchase.purchaseID);
  }
}

class _UiAuth extends AuthProvider {
  _UiAuth(this.controller);
  final ApplePurchaseController controller;
  @override
  ApplePurchaseController get applePurchases => controller;
  @override
  AuthStatus get status => AuthStatus.signedIn;
  @override
  bool get isSignedIn => true;
  @override
  List<StorePlan> get storePlans => [plan];
  @override
  bool get storeLoaded => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> initializeVpn() async {}
  @override
  Future<void> refreshStorePlans() async {}
}
