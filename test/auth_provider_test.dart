import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/models/account_overview.dart';
import 'package:ip_lookup_app/models/account_notice.dart';
import 'package:ip_lookup_app/models/traffic_trend.dart';
import 'package:ip_lookup_app/models/network_node.dart';
import 'package:ip_lookup_app/models/mobile_vpn_config.dart';
import 'package:ip_lookup_app/services/vpn_service.dart';
import 'package:ip_lookup_app/app_brand.dart';
import 'package:ip_lookup_app/providers/auth_provider.dart';
import 'package:ip_lookup_app/services/account_cache.dart';
import 'package:ip_lookup_app/services/auth_service.dart';
import 'package:ip_lookup_app/services/session_storage.dart';

void main() {
  for (final failConfig in [false, true]) {
    test('switch VLESS to HY2 with config failure = $failConfig', () async {
      final service = _FakeAuthService(overview: _overview());
      final vpn = _FakeVpn();
      final provider = AuthProvider(
          service: service,
          vpnService: vpn,
          storage:
              _MemorySessionStorage(token: 'saved', email: 'test@example.com'),
          cache: _MemoryAccountCache());
      addTearDown(provider.dispose);
      await provider.initialize();
      await provider.refreshNetworkNodes();
      expect(provider.selectedNetworkNodeId, '1');
      vpn.current = VpnConnectionStatus.connected;
      await provider.refreshVpnStatus();
      service.configError =
          failConfig ? const AuthException('HY2 配置未就绪') : null;
      provider.selectNetworkNode(service.nodes[1]);
      expect(provider.vpnBusy, isTrue);
      // A second tap while busy must not start a competing connection.
      provider.selectNetworkNode(service.nodes[0]);
      for (var i = 0; i < 100 && provider.vpnBusy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(provider.vpnBusy, isFalse);
      if (failConfig) {
        expect(vpn.events, isEmpty);
        expect(provider.selectedNetworkNodeId, '1');
        expect(provider.vpnStatus, VpnConnectionStatus.connected);
        expect(provider.vpnError, 'HY2 配置未就绪');
      } else {
        expect(vpn.events, ['disconnect', 'connect:hysteria2']);
        expect(provider.selectedNetworkNodeId, '2');
        expect(provider.vpnStatus, VpnConnectionStatus.connecting);
        expect(provider.isVpnConnected, isFalse);
        expect(
            service.appVersion, '${AppBrand.version}+${AppBrand.buildNumber}');
      }
    });
  }

  test('select HY2 while disconnected does not connect without consent',
      () async {
    final service = _FakeAuthService(overview: _overview());
    final vpn = _FakeVpn();
    final provider = AuthProvider(
        service: service,
        vpnService: vpn,
        storage:
            _MemorySessionStorage(token: 'saved', email: 'test@example.com'),
        cache: _MemoryAccountCache());
    addTearDown(provider.dispose);
    await provider.initialize();
    await provider.refreshNetworkNodes();
    provider.selectNetworkNode(service.nodes[1]);
    expect(provider.selectedNetworkNodeId, '2');
    expect(vpn.events, isEmpty);
    await provider.refreshNetworkNodes();
    expect(provider.selectedNetworkNodeId, '2');
    await provider.toggleVpn();
    expect(vpn.events, ['connect:hysteria2']);
    expect(provider.isVpnConnected, isFalse);
  });

  test('login stores session and exposes the account overview', () async {
    final service = _FakeAuthService(overview: _overview());
    final storage = _MemorySessionStorage();
    final provider = AuthProvider(
      service: service,
      storage: storage,
      cache: _MemoryAccountCache(),
    );

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
    final provider = AuthProvider(
      service: service,
      storage: storage,
      cache: _MemoryAccountCache(),
    );

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
    final provider = AuthProvider(
      service: service,
      storage: storage,
      cache: _MemoryAccountCache(),
    );
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
    final provider = AuthProvider(
      service: service,
      storage: storage,
      cache: _MemoryAccountCache(),
    );

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
  AuthException? configError;
  String? appVersion;
  final nodes = [
    NetworkNode.fromJson({
      'id': 1,
      'name': 'Fixture VLESS',
      'type': 'vless',
      'available_status': 2
    }),
    NetworkNode.fromJson({
      'id': 2,
      'name': 'Fixture HY2',
      'type': 'hysteria',
      'available_status': 2
    }),
  ];

  @override
  Future<List<NetworkNode>> getNetworkNodes(String token) async => nodes;

  @override
  Future<MobileVpnConfig> getMobileVpnConfig(String token,
      {required int nodeId, String? appVersion}) async {
    this.appVersion = appVersion;
    if (configError != null) throw configError!;
    return MobileVpnConfig(
        schemaVersion: 1,
        issuedAt: DateTime(2026),
        refreshAfter: DateTime(2026),
        protocol: nodeId == 2 ? 'hysteria2' : 'vless',
        nodeId: nodeId,
        nodeName: 'Fixture',
        address: 'node.example.com',
        port: 443,
        userId: 'fixture',
        encryption: 'none',
        flow: '',
        transportType: nodeId == 2 ? 'quic' : 'raw',
        securityType: nodeId == 2 ? 'tls' : 'reality',
        serverName: 'tls.example.com',
        publicKey: 'fixture',
        shortId: '',
        fingerprint: 'chrome',
        spiderX: '/',
        password: nodeId == 2 ? 'fixture-password' : '');
  }

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

  @override
  Future<TrafficTrend> getMobileTraffic(
    String token,
    TrafficRange range,
  ) async {
    return _trend(range);
  }

  @override
  Future<List<AccountNotice>> getAccountNotices(String token) async => const [];
}

class _FakeVpn implements VpnService {
  VpnConnectionStatus current = VpnConnectionStatus.disconnected;
  final events = <String>[];
  @override
  Future<VpnConnectionStatus> status() async => current;
  @override
  Future<String?> lastError() async => null;
  @override
  Future<void> disconnect() async {
    events.add('disconnect');
    current = VpnConnectionStatus.disconnected;
  }

  @override
  Future<void> connect(MobileVpnConfig config) async {
    events.add('connect:${config.protocol}');
    current = VpnConnectionStatus.connecting;
  }
}

TrafficTrend _trend(TrafficRange range) => TrafficTrend(
      range: range,
      periodStart: DateTime(2026, 10, 10),
      periodEnd: DateTime(2026, 10, 16),
      uploadBytes: 100,
      downloadBytes: 200,
      usedBytes: 300,
      averageDailyBytes: 43,
      updatedAt: DateTime(2026, 10, 16, 12),
      daily: const [],
    );

class _MemoryAccountCache implements AccountCache {
  AccountOverview? overview;
  final trends = <TrafficRange, TrafficTrend>{};

  @override
  Future<void> clear() async {
    overview = null;
    trends.clear();
  }

  @override
  Future<AccountOverview?> readOverview() async => overview;

  @override
  Future<TrafficTrend?> readTrend(TrafficRange range) async => trends[range];

  @override
  Future<void> writeOverview(AccountOverview overview) async {
    this.overview = AccountOverview.fromJson(overview.toCacheJson());
  }

  @override
  Future<void> writeTrend(TrafficTrend trend) async {
    trends[trend.range] = trend;
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
