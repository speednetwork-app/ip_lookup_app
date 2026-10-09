import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('does not query public IP automatically on launch',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('查询当前公网 IP'), findsOneWidget);
    expect(find.text('查询我的公网 IP'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows one clear IP lookup flow', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('查询').last);
    await tester.pumpAndSettle();

    expect(find.text('开始查询'), findsOneWidget);
    expect(find.textContaining('ipwho.is'), findsOneWidget);
    expect(find.textContaining('批量'), findsNothing);
  });

  testWidgets('shows complete in-app privacy disclosure', (tester) async {
    await tester.pumpWidget(const MyApp());
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
      find.textContaining('ipwho.is、ipapi.co、OpenStreetMap'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.textContaining('不申请 GPS 定位权限'), findsOneWidget);
    expect(
        find.textContaining('ipwho.is、ipapi.co、OpenStreetMap'), findsOneWidget);
  });
}
