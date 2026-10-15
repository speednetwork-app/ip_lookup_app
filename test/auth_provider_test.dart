import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/models/account_overview.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/services/auth_service.dart';
import 'package:ip_lookup_app/services/session_storage.dart';

void main() {
  test('login stores session and exposes the account overview', () async {
    final service = _FakeAuthService(overview: _overview());
    final storage = _MemorySessionStorage();
    final provider = AuthProvider(service: service, storage: storage);

    final success = await provider.login(
      email: ' user@example.com ',
      password: 'password',
    );

    expect(success, isTrue);
    expect(provider.status, AuthStatus.signedIn);
    expect(provider.email, 'user@example.com');
    expect(provider.overview?.planName, 'Example Plan');
    expect(provider.subscribeUrl, 'https://example.com/sub/secret');
    expect(storage.token, 'server-token');
    expect(service.requestedToken, 'server-token');
  });

  test('restores an existing session and refreshes its overview', () async {
    final service = _FakeAuthService(overview: _overview());
    final storage = _MemorySessionStorage(
      token: 'saved-token',
      email: 'saved@example.com',
    );
    final provider = AuthProvider(service: service, storage: storage);

    await provider.initialize();

    expect(provider.status, AuthStatus.signedIn);
    expect(provider.email, 'saved@example.com');
    expect(provider.overview?.traffic.totalBytes, 1000);
  });

  test('keeps stale overview after a non-auth refresh failure', () async {
    final service = _FakeAuthService(overview: _overview());
    final storage = _MemorySessionStorage(
      token: 'saved-token',
      email: 'saved@example.com',
    );
    final provider = AuthProvider(service: service, storage: storage);
    await provider.initialize();
    service.overviewError = const AuthException('网络错误');

    await provider.refreshOverview();

    expect(provider.status, AuthStatus.signedIn);
    expect(provider.overview, isNotNull);
    expect(provider.error, '网络错误');
  });

  test('clears an expired session after an unauthorized response', () async {
    final service = _FakeAuthService(
      overviewError: const AuthException(
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

AccountOverview _overview() => const AccountOverview(
      state: AccountState.active,
      planName: 'Example Plan',
      traffic: TrafficOverview(
        usedBytes: 100,
        remainingBytes: 900,
        totalBytes: 1000,
        usagePercent: 10,
      ),
      expiredAt: null,
      remainingDays: null,
      nextResetAt: null,
      deviceLimit: 3,
      speedLimitMbps: 0,
      subscribeUrl: 'https://example.com/sub/secret',
    );

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    this.overview,
    this.overviewError,
  });

  final AccountOverview? overview;
  AuthException? overviewError;
  String? requestedToken;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    return const LoginResult(token: 'server-token');
  }

  @override
  Future<AccountOverview> getMobileOverview(String token) async {
    requestedToken = token;
    if (overviewError != null) throw overviewError!;
    return overview!;
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
