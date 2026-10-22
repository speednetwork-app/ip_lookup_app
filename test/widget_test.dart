import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/main.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/services/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('does not query public IP automatically on launch',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('皮卡云'), findsOneWidget);
    expect(find.text('了解当前网络'), findsOneWidget);
    expect(find.textContaining('VPN'), findsNothing);
    await tester.tap(find.text('IP 检测').last);
    await tester.pumpAndSettle();

    expect(find.text('查询当前公网 IP'), findsOneWidget);
    expect(find.text('查询我的公网 IP'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows one clear IP lookup flow', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('IP 检测').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('查询指定 IP'));
    await tester.pumpAndSettle();

    expect(find.text('开始查询'), findsOneWidget);
    expect(find.textContaining('ipwho.is'), findsOneWidget);
    expect(find.textContaining('批量'), findsNothing);
  });

  testWidgets('keeps IP lookup available without signing in', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('IP 检测').last);
    await tester.pumpAndSettle();
    expect(find.text('查询当前公网 IP'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('登录已有账号'), findsOneWidget);
    expect(find.textContaining('IP 查询功能无需登录'), findsOneWidget);
    expect(find.textContaining('密码不会保存在本机'), findsOneWidget);
    expect(find.textContaining('登录凭证安全存储在 iOS 钥匙串中'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.textContaining('注册'), findsOneWidget);
    expect(find.textContaining('购买入口'), findsOneWidget);
  });

  testWidgets('shows complete in-app privacy disclosure', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('IP 检测').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐私'));
    await tester.pumpAndSettle();

    expect(find.text('隐私与数据'), findsOneWidget);
    expect(find.text('公网 IP 与查询内容'), findsOneWidget);
    expect(find.text('IP 估算位置'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('本地查询历史'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('本地查询历史'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('api.pikayun.com、ipwho.is、ipapi.co、OpenStreetMap'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.textContaining('不申请 GPS 定位权限'), findsOneWidget);
    expect(
      find.textContaining(
        'api.pikayun.com、ipwho.is、ipapi.co、OpenStreetMap',
      ),
      findsOneWidget,
    );
  });
}

Widget _testApp() {
  return MyApp(
    authProvider: AuthProvider(storage: _EmptySessionStorage()),
  );
}

class _EmptySessionStorage implements SessionStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readEmail() async => null;

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> save({required String token, required String email}) async {}
}
