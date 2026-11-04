import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/main.dart';
import 'package:ip_lookup_app/models/store_plan.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/services/auth_service.dart';
import 'package:ip_lookup_app/services/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> planJson({String? channel = 'apple'}) => {
      'id': 800,
      'name': '隔离测试套餐',
      'sales_channel': channel,
      'show': true,
      'sell': true,
      'transfer_enable': 500,
      'speed_limit': 0,
      'device_limit': 0,
      'month_price': 1800,
      'quarter_price': null,
      'year_price': 18800,
      'onetime_price': 6600,
      'reset_traffic_method': 0,
      'apple_products': <Map<String, dynamic>>[
        {
          'period': 'monthly',
          'product_id': 'isolated.monthly',
          'currency': 'USD',
          'storefront': 'USA',
          'price_minor': 299,
          'price_source': 'merchant_config',
        },
        {
          'period': 'yearly',
          'product_id': 'isolated.yearly',
          'currency': 'USD',
          'storefront': 'USA',
          'price_minor': 2999,
          'price_source': 'merchant_config',
        },
      ],
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'Apple catalogue requests exact authenticated GET and rejects other channels',
      () async {
    late RequestOptions request;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      request = options;
      handler.resolve(Response(requestOptions: options, data: {
        'status': 'success',
        'data': [
          planJson(),
          planJson(channel: 'web'),
          planJson(channel: 'android'),
          planJson(channel: null)
        ]
      }));
    }));
    final plans = await AuthService(dio: dio).getApplePlans('test-only-token');
    expect(request.path, '/user/apple/plan/fetch');
    expect(request.method, 'GET');
    expect(request.headers['Authorization'], 'Bearer test-only-token');
    expect(request.queryParameters['sales_channel'], 'apple');
    expect(plans, hasLength(1));
    expect(plans.single.offers.first.usdDisplayPrice, '\$2.99');
    expect(plans.single.offers.map((o) => o.period),
        [StorePeriod.monthly, StorePeriod.yearly]);
  });

  for (final field in ['show', 'sell']) {
    test('does not display $field disabled plans', () {
      expect(StorePlan.fromAppleJson(planJson()..[field] = false), isNull);
    });
  }
  test('does not invent missing periods or display nonrecurring prices', () {
    final raw = planJson()
      ..['month_price'] = null
      ..['year_price'] = null;
    expect(StorePlan.fromAppleJson(raw), isNull);
    expect(StorePlan.fromAppleJson(planJson())!.offers.length, 2);
  });
  test(
      'Apple store only offers monthly/yearly even if legacy periods are returned',
      () {
    final raw = {
      ...planJson(),
      'quarter_price': 4900,
      'half_year_price': 8800,
      'two_year_price': 30000,
      'three_year_price': 50000,
    };
    final plan = StorePlan.fromAppleJson(raw)!;
    expect(plan.offers.map((o) => o.period),
        [StorePeriod.monthly, StorePeriod.yearly]);
    expect(plan.offers.map((o) => o.usdPriceMinor), [299, 2999]);
    raw['month_price'] = null;
    raw['year_price'] = null;
    expect(StorePlan.fromAppleJson(raw), isNull);
  });
  test('missing USD products never reinterpret legacy CNY prices as USD', () {
    final plan = StorePlan.fromAppleJson(planJson()..remove('apple_products'))!;
    expect(plan.offers.length, 2);
    expect(plan.offers.every((o) => o.usdDisplayPrice == null), isTrue);
  });
  test('rejects ambiguous, invalid or non-US dollar price metadata', () {
    for (final edit in <Map<String, dynamic>>[
      {'currency': 'CNY'},
      {'storefront': 'JPN'},
      {'price_minor': 0},
      {'price_minor': '299'},
      {'price_minor': 299.5},
      {'product_id': ''},
      {'price_source': 'unknown'},
    ]) {
      final raw = planJson();
      final products = raw['apple_products'] as List;
      products[0] = Map<String, dynamic>.from(products[0] as Map)..addAll(edit);
      expect(
          StorePlan.fromAppleJson(raw)!.offers.first.usdDisplayPrice, isNull);
    }
    final raw = planJson();
    final products = raw['apple_products'] as List;
    products.add(Map<String, dynamic>.from(products.first as Map));
    expect(StorePlan.fromAppleJson(raw)!.offers.first.usdDisplayPrice, isNull);
  });
  test('monthly reset label follows backend reset rule, never annual total',
      () {
    for (final method in [0, 1]) {
      final plan = StorePlan.fromAppleJson(
          planJson()..['reset_traffic_method'] = method)!;
      expect(plan.resetsMonthly, isTrue);
      expect(plan.trafficGb, 500);
    }
    for (final method in [null, 2, 3, 4]) {
      expect(
          StorePlan.fromAppleJson(
                  planJson()..['reset_traffic_method'] = method)!
              .resetsMonthly,
          isFalse);
    }
  });
  test('rejects malformed identity, quota and non-finite price', () {
    for (final edit in <Map<String, dynamic>>[
      {'id': 0},
      {'name': ''},
      {'transfer_enable': 'NaN'},
      {'month_price': 'Infinity', 'year_price': -1},
    ]) {
      expect(StorePlan.fromAppleJson({...planJson(), ...edit}), isNull);
    }
  });
  test('catalogue rejects malformed success payload', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) => h.resolve(Response(
            requestOptions: o, data: {'status': 'success', 'data': {}}))));
    await expectLater(AuthService(dio: dio).getApplePlans('token'),
        throwsA(isA<AuthException>()));
  });
  test('signed-out catalogue performs no request', () async {
    final service = _PendingCatalog();
    final auth = AuthProvider(service: service, storage: _Session());
    addTearDown(auth.dispose);
    await auth.refreshStorePlans();
    expect(service.calls, 0);
  });
  test('discard late catalogue response after logout', () async {
    final service = _PendingCatalog();
    final auth =
        _SessionAuth(service: service, storage: _Session('test-only-token'));
    addTearDown(auth.dispose);
    await auth.initialize();
    final pending = auth.refreshStorePlans();
    expect(auth.storeLoading, isTrue);
    await auth.refreshStorePlans();
    expect(service.calls, 1);
    await auth.logout();
    service.result.complete([StorePlan.fromAppleJson(planJson())!]);
    await pending;
    expect(auth.storePlans, isEmpty);
    expect(auth.storeLoading, isFalse);
    expect(auth.storeLoaded, isFalse);
  });
  test('expired store session clears data and notifies signed-out UI',
      () async {
    final service = _PendingCatalog();
    final auth =
        _SessionAuth(service: service, storage: _Session('test-only-token'));
    addTearDown(auth.dispose);
    await auth.initialize();
    var notifiedSignedOut = false;
    auth.addListener(() {
      if (!auth.isSignedIn) notifiedSignedOut = true;
    });
    final pending = auth.refreshStorePlans();
    service.result
        .completeError(const AuthException('登录已失效', isUnauthorized: true));
    await pending;
    expect(notifiedSignedOut, isTrue);
    expect(auth.storeLoading, isFalse);
    expect(auth.storePlans, isEmpty);
  });
  test('late store response does not notify disposed provider', () async {
    final service = _PendingCatalog();
    final auth =
        _SessionAuth(service: service, storage: _Session('test-only-token'));
    await auth.initialize();
    final pending = auth.refreshStorePlans();
    auth.dispose();
    service.result.complete([StorePlan.fromAppleJson(planJson())!]);
    await pending;
  });
  for (final dark in [false, true]) {
    testWidgets(
        'store renders real-shaped metadata, disabled checkout, large text $dark',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.platformBrightnessTestValue =
          dark ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(MyApp(authProvider: _UiAuth()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('商城').last);
      await tester.pumpAndSettle();
      expect(find.text('隔离测试套餐'), findsOneWidget);
      expect(find.text('\$2.99 / 月'), findsOneWidget);
      expect(find.textContaining('后台参考价'), findsNothing);
      expect(find.textContaining('¥'), findsNothing);
      expect(find.text('季付'), findsNothing);
      expect(find.text('半年付'), findsNothing);
      await tester.ensureVisible(find.text('年付'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('年付'));
      await tester.pumpAndSettle();
      expect(find.text('\$29.99 / 年'), findsOneWidget);
      expect(find.textContaining('每月重置 500 GB'), findsOneWidget);
      await tester.ensureVisible(find.text('月付'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('月付'));
      await tester.pumpAndSettle();
      expect(find.text('\$2.99 / 月'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('请在 iPhone／iPad App 内订阅'), 150,
          scrollable: find.byType(Scrollable).last);
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '请在 iPhone／iPad App 内订阅'));
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('each preview plan switches periods without enabling checkout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _UiAuth(multiplePlans: true);
    await tester.pumpWidget(MyApp(authProvider: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('商城').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('可切换月付／年付'), findsOneWidget);
    expect(auth.applePurchases.supported, isFalse);
    for (final id in [800, 801]) {
      for (final period in StorePeriod.values) {
        final target = find.byKey(ValueKey('store-period-$id-${period.name}'));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.widget<OutlinedButton>(target).onPressed, isNotNull);
      }
    }
    await tester.tap(find.byKey(const ValueKey('store-period-800-yearly')));
    await tester.pumpAndSettle();
    expect(find.text('\$29.99 / 年'), findsOneWidget);
    expect(find.text('\$7.99 / 月'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store-period-801-yearly')));
    await tester.pumpAndSettle();
    expect(find.text('\$29.99 / 年'), findsOneWidget);
    expect(find.text('\$79.99 / 年'), findsOneWidget);
    for (final id in [800, 801]) {
      await tester.tap(find.byKey(ValueKey('store-period-$id-monthly')));
      await tester.pumpAndSettle();
    }
    expect(find.text('\$2.99 / 月'), findsOneWidget);
    expect(find.text('\$7.99 / 月'), findsOneWidget);
    for (final button in tester.widgetList<FilledButton>(
        find.widgetWithText(FilledButton, '请在 iPhone／iPad App 内订阅'))) {
      expect(button.onPressed, isNull);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing dollar configuration shows no invented price',
      (tester) async {
    await tester.pumpWidget(MyApp(authProvider: _UiAuth(withPrices: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('商城').last);
    await tester.pumpAndSettle();
    expect(find.text('美元价格待同步'), findsOneWidget);
    expect(find.textContaining('\$'), findsNothing);
    expect(find.textContaining('¥'), findsNothing);
    expect(find.textContaining('后台参考价'), findsNothing);
  });
  testWidgets(
      'history remains accessible from IP toolbar with return to detection',
      (tester) async {
    await tester.pumpWidget(MyApp(authProvider: _UiAuth()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(NavigationDestination, '历史'), findsNothing);
    await tester.tap(find.text('IP 检测').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('查询历史'));
    await tester.pumpAndSettle();
    expect(find.text('还没有查询记录'), findsOneWidget);
    await tester.tap(find.text('立即检测 IP'));
    await tester.pumpAndSettle();
    expect(find.text('查询我的公网 IP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PendingCatalog extends AuthService {
  int calls = 0;
  final result = Completer<List<StorePlan>>();
  @override
  Future<List<StorePlan>> getApplePlans(String token) {
    calls++;
    return result.future;
  }
}

class _SessionAuth extends AuthProvider {
  _SessionAuth({required super.service, required super.storage});
  @override
  Future<void> refreshAccountData() async {}
}

class _UiAuth extends AuthProvider {
  _UiAuth({this.withPrices = true, this.multiplePlans = false});
  final bool withPrices;
  final bool multiplePlans;
  @override
  AuthStatus get status => AuthStatus.signedIn;
  @override
  bool get isSignedIn => true;
  @override
  List<StorePlan> get storePlans => [
        StorePlan.fromAppleJson(
            withPrices ? planJson() : (planJson()..remove('apple_products')))!,
        if (multiplePlans)
          StorePlan.fromAppleJson(planJson()
            ..['id'] = 801
            ..['name'] = '隔离测试套餐二'
            ..['transfer_enable'] = 1500
            ..['apple_products'] = [
              {
                'period': 'monthly',
                'product_id': 'isolated.second.monthly',
                'currency': 'USD',
                'storefront': 'USA',
                'price_minor': 799,
                'price_source': 'merchant_config',
              },
              {
                'period': 'yearly',
                'product_id': 'isolated.second.yearly',
                'currency': 'USD',
                'storefront': 'USA',
                'price_minor': 7999,
                'price_source': 'merchant_config',
              },
            ])!,
      ];
  @override
  bool get storeLoaded => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> initializeVpn() async {}
  @override
  Future<void> refreshStorePlans() async {}
}

class _Session implements SessionStorage {
  _Session([this.token]);
  String? token;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<String?> readEmail() async => 'test-only@example.com';
  @override
  Future<void> clear() async {
    token = null;
  }

  @override
  Future<void> save({required String token, required String email}) async {
    this.token = token;
  }
}
