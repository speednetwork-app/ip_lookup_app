import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/main.dart';
import 'package:ip_lookup_app/models/account_overview.dart';
import 'package:ip_lookup_app/models/network_node.dart';
import 'package:ip_lookup_app/models/traffic_trend.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Presentation fixtures stay in tests; the production app always uses its APIs.
class _UiAuth extends AuthProvider {
  String _selection = '1';
  final bool longName;
  _UiAuth({this.longName = false});

  @override
  AuthStatus get status => AuthStatus.signedIn;
  @override
  bool get isSignedIn => true;
  @override
  String get email => 'ui-test@example.com';
  @override
  VpnConnectionStatus get vpnStatus => VpnConnectionStatus.disconnected;
  @override
  String get selectedNetworkNodeId => _selection;
  @override
  TrafficTrend get trafficTrend => TrafficTrend(
        range: TrafficRange.sevenDays,
        periodStart: DateTime(2026, 10, 20),
        periodEnd: DateTime(2026, 10, 26),
        updatedAt: DateTime(2026, 10, 26),
        uploadBytes: 1073741824,
        downloadBytes: 2147483648,
        usedBytes: 3221225472,
        averageDailyBytes: 460175067,
        daily: const [],
      );
  @override
  AccountOverview get overview => const AccountOverview(
        state: AccountState.active,
        planName: '测试套餐',
        traffic: TrafficOverview(
            usedBytes: 1073741824,
            remainingBytes: 9663676416,
            totalBytes: 10737418240,
            usagePercent: 10),
        expiredAt: null,
        remainingDays: null,
        nextResetAt: null,
        deviceLimit: 0,
        speedLimitMbps: 0,
        subscribeUrl: 'https://example.com/sub/ui-test-only',
      );
  @override
  List<NetworkNode> get networkNodes => List.generate(
      12,
      (i) => NetworkNode(
            id: '${i + 1}',
            name: longName
                ? '测试节点 ${(i + 1).toString().padLeft(2, '0')} 超长地区与完整线路名称必须保持可读'
                : '测试节点 ${(i + 1).toString().padLeft(2, '0')}',
            protocol: 'VLESS',
            rate: 0.1,
            availability:
                i == 11 ? NodeAvailability.offline : NodeAvailability.online,
            loadLevel: 'relaxed',
            loadEstimated: false,
            lastCheckAt: null,
          ));
  @override
  Future<void> initialize() async {}
  @override
  Future<void> initializeVpn() async {}
  @override
  Future<void> refreshNetworkNodes() async {}
  @override
  void selectNetworkNode(NetworkNode node) {
    _selection = node.id;
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('compact nodes keep telemetry honest and selection functional',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _UiAuth();
    await tester.pumpWidget(MyApp(authProvider: auth));
    await tester.pumpAndSettle();
    expect(find.text('VPN 未连接'), findsOneWidget);
    expect(find.text('VPN 已连接'), findsNothing);
    await tester.tap(find.text('线路').last);
    await tester.pumpAndSettle();
    expect(find.text('测试节点 08').hitTestable(), findsOneWidget);
    expect(find.text('未测'), findsWidgets);
    expect(find.text('暂无数据'), findsWidgets);
    expect(find.text('28 ms'), findsNothing);
    await tester.tap(find.text('测试节点 02'));
    await tester.pumpAndSettle();
    expect(auth.selectedNetworkNodeId, '2');
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'all tabs handle 2x text and long names in ${dark ? "dark" : "light"} mode',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.platformBrightnessTestValue =
          dark ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final app = MyApp(authProvider: _UiAuth(longName: true));
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: app,
      ));
      await tester.pumpAndSettle();
      for (final label in ['线路', 'IP 检测', '历史', '我的', '首页']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '$label must not overflow');
        if (label == '我的') {
          await tester.scrollUntilVisible(find.text('退出登录'), 300,
              scrollable: find.byType(Scrollable).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'Account details must support large text');
        }
      }
    });
  }

  testWidgets('account keeps subscription hidden until explicitly revealed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MyApp(authProvider: _UiAuth()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/sub/ui-test-only'), findsNothing);
    expect(find.text('剩余可用'), findsOneWidget);
    await tester.tap(find.byTooltip('显示订阅地址'));
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/sub/ui-test-only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
