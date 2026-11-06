import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ip_lookup_app/models/account_deletion.dart';
import 'package:ip_lookup_app/models/account_overview.dart';
import 'package:ip_lookup_app/models/account_notice.dart';
import 'package:ip_lookup_app/models/traffic_trend.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/screens/account_deletion_screen.dart';
import 'package:ip_lookup_app/services/account_deletion_storage.dart';
import 'package:ip_lookup_app/services/apple_purchase_audit.dart';
import 'package:ip_lookup_app/services/auth_service.dart';
import 'package:ip_lookup_app/services/session_storage.dart';
import 'package:ip_lookup_app/widgets/service_data_disclosure.dart';

const fixtureOwner = 'ISOLATED_OWNER@example.invalid';
const deleted = {'confirmed': true, 'deleted': true, 'cleanup_complete': true};
const preview = AccountDeletionPreview(
    hasActivePackage: true,
    balanceMinor: 0,
    commissionMinor: 0,
    requiresSettlement: false,
    hasAppleSubscription: true);

class MemoryDeletion implements AccountDeletionStorage {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> operation) async {
    value = operation;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class MemoryAudit implements AppleAuditStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class MemorySession implements SessionStorage {
  String? token = 'ISOLATED_AUTH', email = fixtureOwner;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<String?> readEmail() async => email;
  @override
  Future<void> save({required String token, required String email}) async {
    this.token = token;
    this.email = email;
  }

  @override
  Future<void> clear() async {
    token = null;
    email = null;
  }
}

class FixtureService extends AuthService {
  bool confirmed = false, reject = false, pending = false;
  int calls = 0;
  @override
  Future<AccountOverview> getMobileOverview(String token) async =>
      AccountOverview.fromJson({});
  @override
  Future<TrafficTrend> getMobileTraffic(
          String token, TrafficRange range) async =>
      throw const AuthException('ISOLATED_NO_TREND');
  @override
  Future<List<AccountNotice>> getAccountNotices(String token) async => [];
  @override
  Future<AccountDeletionPreview> getAccountDeletionPreview(
          String token) async =>
      preview;
  @override
  Future<Map<String, dynamic>> accountDeletionReceipt(
          Map<String, dynamic> operation) async =>
      confirmed
          ? pending
              ? {
                  'confirmed': true,
                  'deleted': false,
                  'pending_settlement': true
                }
              : deleted
          : {'confirmed': false};
  @override
  Future<Map<String, dynamic>> deleteAccount(
      String token, String password, Map<String, dynamic> operation) async {
    calls++;
    if (reject) {
      throw const AuthException('密码不正确，请重新输入', code: 'DELETION_REJECTED');
    }
    confirmed = true;
    return pending
        ? {'confirmed': true, 'deleted': false, 'pending_settlement': true}
        : deleted;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'deletion operation has independent random receipt secret and no password',
      () {
    final a = newDeletionOperation(fixtureOwner),
        b = newDeletionOperation(fixtureOwner);
    expect(a['request_id'], isNot(b['request_id']));
    expect(a['receipt_secret'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(a.keys, unorderedEquals(['owner', 'request_id', 'receipt_secret']));
  });

  test(
      'authenticated POST has fixed confirmation; lost response is recovered without second POST',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) {
      requests.add(r);
      if (r.path == '/user/account/deletion') {
        h.reject(DioException(
            requestOptions: r, type: DioExceptionType.receiveTimeout));
      } else {
        h.resolve(Response(
            requestOptions: r, data: {'status': 'success', 'data': deleted}));
      }
    }));
    final service = AuthService(dio: dio);
    final operation = newDeletionOperation(fixtureOwner);
    expect(
        await service.deleteAccount(
            'ISOLATED_AUTH', 'ISOLATED_PASSWORD', operation),
        deleted);
    expect(requests.length, 2);
    expect(requests.first.headers['Authorization'], 'Bearer ISOLATED_AUTH');
    expect(requests.first.data['confirmation'], 'DELETE');
    expect(requests.first.data['acknowledged'], true);
    expect(requests.first.data.containsKey('user_id'), false);
    expect(requests.last.headers.containsKey('Authorization'), false);
    expect(requests.last.data.keys,
        unorderedEquals(['request_id', 'receipt_secret']));
  });

  test(
      'provider only clears local identity after server confirmation; other audit owner survives',
      () async {
    final service = FixtureService(),
        session = MemorySession(),
        storage = MemoryDeletion(),
        audit = MemoryAudit();
    audit.value = jsonEncode([
      {'owner': fixtureOwner, 'phase': 'verified', 'events': []},
      {'owner': 'ISOLATED_OTHER', 'phase': 'verified', 'events': []},
    ]);
    final provider = AuthProvider(
        service: service,
        storage: session,
        deletionStorage: storage,
        auditStorage: audit);
    addTearDown(provider.dispose);
    await provider.initialize();
    expect(provider.isSignedIn, true);
    expect(
        (await provider.deleteAccount('ISOLATED_PASSWORD'))['deleted'], true);
    expect(service.calls, 1);
    expect(provider.isSignedIn, false);
    expect(provider.overview, null);
    expect(provider.subscribeUrl, isEmpty);
    expect(session.token, null);
    expect(storage.value, null);
    expect(
        (jsonDecode(audit.value!) as List).single['owner'], 'ISOLATED_OTHER');
  });

  test('restart recovers deletion receipt before showing cached subscription',
      () async {
    final service = FixtureService()..confirmed = true;
    final storage = MemoryDeletion()
      ..value = newDeletionOperation(fixtureOwner);
    final provider = AuthProvider(
        service: service,
        storage: MemorySession(),
        deletionStorage: storage,
        auditStorage: MemoryAudit());
    addTearDown(provider.dispose);
    await provider.initialize();
    expect(provider.isSignedIn, false);
    expect(service.calls, 0);
    expect(storage.value, null);
  });

  test('bad reauthentication does not log out or delete local data', () async {
    final service = FixtureService()..reject = true;
    final session = MemorySession(), storage = MemoryDeletion();
    final provider = AuthProvider(
        service: service,
        storage: session,
        deletionStorage: storage,
        auditStorage: MemoryAudit());
    addTearDown(provider.dispose);
    await provider.initialize();
    await expectLater(provider.deleteAccount('ISOLATED_WRONG'),
        throwsA(isA<AuthException>()));
    expect(provider.isSignedIn, true);
    expect(session.token, isNotNull);
    expect(storage.value, null);
  });

  test(
      'funded account gets a pending receipt, not a fake deletion; later completion is recovered',
      () async {
    final service = FixtureService()..pending = true;
    final session = MemorySession(), storage = MemoryDeletion();
    final provider = AuthProvider(
        service: service,
        storage: session,
        deletionStorage: storage,
        auditStorage: MemoryAudit());
    addTearDown(provider.dispose);
    await provider.initialize();
    expect(
        (await provider
            .deleteAccount('ISOLATED_PASSWORD'))['pending_settlement'],
        true);
    expect(provider.isSignedIn, true);
    expect(storage.value, isNotNull);
    service.pending = false;
    await expectLater(
        provider.accountDeletionPreview(), throwsA(isA<AuthException>()));
    expect(provider.isSignedIn, false);
    expect(storage.value, null);
  });

  test('deletion recovery works after session credentials were already cleared',
      () async {
    final service = FixtureService()..confirmed = true;
    final session = MemorySession()
      ..token = null
      ..email = null;
    final storage = MemoryDeletion()
      ..value = newDeletionOperation(fixtureOwner);
    final provider = AuthProvider(
        service: service,
        storage: session,
        deletionStorage: storage,
        auditStorage: MemoryAudit());
    addTearDown(provider.dispose);
    await provider.initialize();
    expect(provider.isSignedIn, false);
    expect(storage.value, null);
  });

  testWidgets(
      'deletion requires password, acknowledgement and final destructive confirmation',
      (tester) async {
    final service = FixtureService()..reject = true;
    final provider = AuthProvider(
        service: service,
        storage: MemorySession(),
        deletionStorage: MemoryDeletion(),
        auditStorage: MemoryAudit());
    await provider.initialize();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: AccountDeletionScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('永久删除账户'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, null);
    await tester.enterText(find.byType(TextField), 'ISOLATED_WRONG');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除账户'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除账户？'), findsOneWidget);
    await tester.tap(find.text('保留账户'));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    await tester.tap(find.text('永久删除账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认永久删除'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.text('密码不正确，请重新输入'), findsOneWidget);
    expect(provider.isSignedIn, true);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  for (final accept in [false, true]) {
    testWidgets('first-use disclosure blocks action unless accepted: $accept',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      child: const Text('ISOLATED_ACTION'),
                      onPressed: () async {
                        if (await ServiceDataDisclosure.ensureAccepted(
                            context)) {
                          calls++;
                        }
                      })))));
      await tester.tap(find.text('ISOLATED_ACTION'));
      await tester.pumpAndSettle();
      expect(find.text('数据使用与隐私'), findsOneWidget);
      expect(find.textContaining('Apple 处理付款'), findsOneWidget);
      await tester.tap(find.text(accept ? '知悉并继续' : '暂不使用'));
      await tester.pumpAndSettle();
      expect(calls, accept ? 1 : 0);
      expect(
          (await SharedPreferences.getInstance())
              .getBool(ServiceDataDisclosure.acceptedKey),
          accept ? true : null);
    });
  }

  testWidgets(
      'deletion and disclosure remain usable at 320pt, dark and 2x text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AuthProvider(
        service: FixtureService(),
        storage: MemorySession(),
        deletionStorage: MemoryDeletion(),
        auditStorage: MemoryAudit());
    await provider.initialize();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: const AccountDeletionScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('永久删除账户'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        ServiceDataDisclosure.ensureAccepted(context),
                    child: const Text('DISCLOSURE'))))));
    provider.dispose();
    await tester.tap(find.text('DISCLOSURE'));
    await tester.pumpAndSettle();
    expect(find.text('知悉并继续'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
