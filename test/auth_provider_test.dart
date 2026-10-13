import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/services/auth_service.dart';
import 'package:ip_lookup_app/services/session_storage.dart';

void main() {
  test('login stores session and exposes only the subscription URL', () async {
    final service = _FakeAuthService(
      loginToken: 'server-token',
      subscribeUrl: 'https://example.com/sub/secret',
    );
    final storage = _MemorySessionStorage();
    final provider = AuthProvider(service: service, storage: storage);

    final success = await provider.login(
      email: ' user@example.com ',
      password: 'password',
    );

    expect(success, isTrue);
    expect(provider.status, AuthStatus.signedIn);
    expect(provider.email, 'user@example.com');
    expect(provider.subscribeUrl, 'https://example.com/sub/secret');
    expect(storage.token, 'server-token');
    expect(storage.email, 'user@example.com');
    expect(service.requestedToken, 'server-token');
  });

  test('restores an existing session and refreshes its subscription URL',
      () async {
    final service = _FakeAuthService(
      subscribeUrl: 'https://example.com/sub/restored',
    );
    final storage = _MemorySessionStorage(
      token: 'saved-token',
      email: 'saved@example.com',
    );
    final provider = AuthProvider(service: service, storage: storage);

    await provider.initialize();

    expect(provider.status, AuthStatus.signedIn);
    expect(provider.email, 'saved@example.com');
    expect(provider.subscribeUrl, 'https://example.com/sub/restored');
  });

  test('clears an expired session after an unauthorized response', () async {
    final service = _FakeAuthService(
      subscribeError: const AuthException(
        '登录已失效，请重新登录',
        isUnauthorized: true,
      ),
    );
    final storage = _MemorySessionStorage(
      token: 'expired-token',
      email: 'saved@example.com',
    );
    final provider = AuthProvider(service: service, storage: storage);

    await provider.initialize();

    expect(provider.status, AuthStatus.signedOut);
    expect(provider.error, '登录已失效，请重新登录');
    expect(storage.token, isNull);
    expect(storage.email, isNull);
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    this.loginToken = 'token',
    this.subscribeUrl = '',
    this.subscribeError,
  });

  final String loginToken;
  final String subscribeUrl;
  final AuthException? subscribeError;
  String? requestedToken;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    return LoginResult(token: loginToken);
  }

  @override
  Future<String> getSubscribeUrl(String token) async {
    requestedToken = token;
    if (subscribeError != null) throw subscribeError!;
    return subscribeUrl;
  }
}

class _MemorySessionStorage implements SessionStorage {
  _MemorySessionStorage({this.token, this.email});

  String? token;
  String? email;

  @override
  Future<void> clear() async {
    token = null;
    email = null;
  }

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> save({required String token, required String email}) async {
    this.token = token;
    this.email = email;
  }
}
