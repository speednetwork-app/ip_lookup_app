import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ip_lookup_app/models/registration_config.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/screens/register_screen.dart';
import 'package:ip_lookup_app/services/auth_service.dart';
import 'package:ip_lookup_app/services/session_storage.dart';
import 'package:ip_lookup_app/theme/pikayun_theme.dart';

// All identities, credentials and HTTP responses below are isolated fixtures.
// These tests must never create production accounts or send real email.
class _Backend {
  final requests = <RequestOptions>[];
  final config = <String, dynamic>{
    'is_email_verify': 0,
    'is_invite_force': 0,
    'simple_captcha_enable': 1,
    'is_captcha': 0,
    'email_whitelist_suffix': ['example.com'],
  };
  bool rejectRegistration = false;
  bool failConfig = false;
  int captchaCalls = 0;

  late final service = AuthService(
      dio: Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api/v1'))
        ..interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
          requests.add(request);
          final dynamic data;
          var status = 200;
          switch (request.path) {
            case '/guest/comm/config':
              data = failConfig
                  ? {'status': 'fail', 'message': '配置暂不可用'}
                  : {'status': 'success', 'data': config};
            case '/guest/comm/simpleCaptcha':
              captchaCalls++;
              data = {
                'status': 'success',
                'data': {
                  'token': 'challenge-$captchaCalls',
                  'question': '2 + 3 = ?',
                  'ttl': 300
                }
              };
            case '/passport/comm/sendEmailVerify':
              data = {'status': 'success', 'data': true};
            case '/passport/auth/register':
              status = rejectRegistration ? 422 : 200;
              data = rejectRegistration
                  ? {'status': 'fail', 'message': '验证码不正确'}
                  : {
                      'status': 'success',
                      'data': {'auth_data': 'fixture-session'}
                    };
            case '/user/mobile-overview':
              data = {
                'status': 'success',
                'data': {'account_status': 'inactive', 'traffic': {}}
              };
            case '/user/mobile-traffic':
              data = {
                'status': 'success',
                'data': {'range': request.queryParameters['range'], 'daily': []}
              };
            default:
              data = {'status': 'success', 'data': []};
          }
          if (status >= 400) {
            handler.reject(DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                    requestOptions: request, statusCode: status, data: data)));
          } else {
            handler.resolve(Response(
                requestOptions: request, statusCode: status, data: data));
          }
        })));
}

class _Storage implements SessionStorage {
  String? token;
  String? email;
  bool failSave = false;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<String?> readEmail() async => email;
  @override
  Future<void> clear() async {
    token = null;
    email = null;
  }

  @override
  Future<void> save({required String token, required String email}) async {
    if (failSave) throw Exception('storage unavailable');
    this.token = token;
    this.email = email;
  }
}

Future<AuthProvider> _show(WidgetTester tester, _Backend backend,
    {double scale = 1, bool dark = false}) async {
  final auth = AuthProvider(service: backend.service, storage: _Storage());
  await auth.initialize();
  addTearDown(auth.dispose);
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        theme: dark ? PikayunTheme.dark() : PikayunTheme.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen())),
                  child: const Text('测试宿主页'),
                ))),
      )));
  await tester.pumpAndSettle();
  await tester.tap(find.text('测试宿主页'));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _fill(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'user@example.com');
  await tester.enterText(fields.at(1), 'fixture-password');
  await tester.enterText(fields.at(2), 'fixture-password');
  await tester.enterText(fields.at(3), '5');
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('configuration respects backend verification and email restrictions',
      () {
    final config = RegistrationConfig.fromJson({
      'is_email_verify': '1',
      'is_invite_force': true,
      'is_captcha': 1,
      'simple_captcha_enable': 1,
      'email_whitelist_suffix': ['example.com'],
    });
    expect(config.emailVerification, isTrue);
    expect(config.inviteRequired, isTrue);
    expect(config.externalCaptcha, isFalse); // same priority as CaptchaService
    expect(config.validateEmail('USER@EXAMPLE.COM'), isNull);
    expect(config.validateEmail('user@other.invalid'), isNotNull);
    expect(config.validateEmail('user@'), isNotNull);
  });

  test('register uses exact backend contract and returns real session payload',
      () async {
    final backend = _Backend();
    final result = await backend.service.register(const RegistrationInput(
        email: ' user@example.com ',
        password: ' pass1234 ',
        captchaToken: 'challenge-1',
        captchaAnswer: '5',
        inviteCode: 'invite',
        emailCode: '123456'));
    final request = backend.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/passport/auth/register');
    expect(request.data, {
      'email': 'user@example.com',
      'password': ' pass1234 ',
      'simple_captcha_token': 'challenge-1',
      'simple_captcha_answer': '5',
      'invite_code': 'invite',
      'email_code': '123456',
    });
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(result.token, 'fixture-session');
  });

  test('server rejection never creates a signed-in state', () async {
    final backend = _Backend()..rejectRegistration = true;
    final storage = _Storage();
    final auth = AuthProvider(service: backend.service, storage: storage);
    addTearDown(auth.dispose);
    expect(
        await auth.register(const RegistrationInput(
            email: 'user@example.com', password: 'fixture-password')),
        isFalse);
    expect(auth.isSignedIn, isFalse);
    expect(storage.token, isNull);
    expect(auth.error, '验证码不正确');
  });

  test('registration reuses secure session storage and account refresh',
      () async {
    final backend = _Backend();
    final storage = _Storage();
    final auth = AuthProvider(service: backend.service, storage: storage);
    addTearDown(auth.dispose);
    expect(
        await auth.register(const RegistrationInput(
            email: ' user@example.com ', password: 'fixture-password')),
        isTrue);
    expect(storage.email, 'user@example.com');
    expect(storage.token, 'fixture-session');
    expect(auth.overview, isNotNull);
    expect(backend.requests.where((r) => r.path == '/user/mobile-overview'),
        hasLength(1));
  });

  test(
      'storage failure clears registration session instead of claiming success',
      () async {
    final backend = _Backend();
    final storage = _Storage()..failSave = true;
    final auth = AuthProvider(service: backend.service, storage: storage);
    addTearDown(auth.dispose);
    expect(
        await auth.register(const RegistrationInput(
            email: 'user@example.com', password: 'fixture-password')),
        isFalse);
    expect(auth.isSignedIn, isFalse);
    expect(storage.token, isNull);
  });

  testWidgets(
      'fields are conditional and validation sends no invalid registration',
      (tester) async {
    final backend = _Backend();
    await _show(tester, backend);
    expect(find.text('2 + 3 = ?'), findsOneWidget);
    expect(find.text('邮箱验证码'), findsNothing);
    await tester.ensureVisible(find.text('创建账号并登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建账号并登录'));
    await tester.pumpAndSettle();
    expect(find.text('请输入邮箱'), findsOneWidget);
    expect(backend.requests.where((r) => r.path.contains('/auth/register')),
        isEmpty);
  });

  testWidgets(
      'failed registration refreshes the consumed captcha and preserves form',
      (tester) async {
    final backend = _Backend()..rejectRegistration = true;
    final auth = await _show(tester, backend);
    await _fill(tester);
    await tester.ensureVisible(find.text('创建账号并登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建账号并登录'));
    await tester.pumpAndSettle();
    expect(auth.isSignedIn, isFalse);
    expect(find.text('验证码不正确'), findsOneWidget);
    expect(backend.captchaCalls, 2);
    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller!.text, 'user@example.com');
    expect(fields[3].controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful registration returns to the signed-in host',
      (tester) async {
    final backend = _Backend();
    final auth = await _show(tester, backend);
    await _fill(tester);
    await tester.ensureVisible(find.text('创建账号并登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建账号并登录'));
    await tester.pumpAndSettle();
    expect(auth.isSignedIn, isTrue);
    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('账号已创建并登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'email verification sends only after consent and respects resend cooldown',
      (tester) async {
    final backend = _Backend();
    backend.config['is_email_verify'] = 1;
    await _show(tester, backend);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), '5');
    await tester.ensureVisible(find.text('发送邮箱验证码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送邮箱验证码'));
    await tester.pumpAndSettle();
    expect(find.text('请先阅读并同意隐私政策'), findsOneWidget);
    expect(backend.requests.where((r) => r.path.endsWith('sendEmailVerify')),
        isEmpty);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('发送邮箱验证码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送邮箱验证码'));
    await tester.pumpAndSettle();
    expect(backend.requests.where((r) => r.path.endsWith('sendEmailVerify')),
        hasLength(1));
    expect(backend.captchaCalls, 2);
    expect(find.text('60 秒后重发'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unsupported external captcha fails closed', (tester) async {
    final backend = _Backend();
    backend.config['simple_captcha_enable'] = 0;
    backend.config['is_captcha'] = 1;
    await _show(tester, backend);
    expect(find.textContaining('当前客户端暂不支持'), findsOneWidget);
    expect(find.text('创建账号并登录'), findsNothing);
    expect(backend.captchaCalls, 0);
  });

  testWidgets(
      'config failure offers retry instead of an unverified signup form',
      (tester) async {
    final backend = _Backend()..failConfig = true;
    await _show(tester, backend);
    expect(find.text('重新获取注册配置'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    backend.failConfig = false;
    await tester.tap(find.text('重新获取注册配置'));
    await tester.pumpAndSettle();
    expect(find.text('创建账号并登录'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'registration supports 2x text at 320pt ${dark ? "dark" : "light"}',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = _Backend();
      backend.config['is_email_verify'] = 1;
      backend.config['is_invite_force'] = 1;
      await _show(tester, backend, scale: 2, dark: dark);
      await tester.scrollUntilVisible(find.text('已有账号？返回登录'), 220,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('native iOS theme resolves SF system family with PingFang fallback', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final theme = PikayunTheme.light();
    expect(theme.textTheme.bodyLarge!.fontFamily, 'CupertinoSystemText');
    expect(theme.textTheme.bodyLarge!.fontSize, 17);
    expect(theme.textTheme.titleLarge!.fontFamily, 'CupertinoSystemDisplay');
    expect(
        theme.textTheme.bodyLarge!.fontFamilyFallback, contains('PingFang SC'));
    expect(theme.textTheme.titleMedium!.letterSpacing, 0);
  });
}
