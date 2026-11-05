import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_brand.dart';
import '../models/mobile_vpn_config.dart';
import '../models/account_overview.dart';
import '../models/account_notice.dart';
import '../models/traffic_trend.dart';
import '../models/network_node.dart';
import '../models/registration_config.dart';
import '../models/store_plan.dart';
import '../services/account_cache.dart';
import '../services/apple_purchase_controller.dart';
import '../services/apple_purchase_audit.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../services/vpn_service.dart';

enum AuthStatus { initializing, signedOut, signingIn, signedIn }

class _VpnCancelled implements Exception {
  const _VpnCancelled();
}

class AuthProvider with ChangeNotifier {
  AuthProvider({
    AuthService? service,
    SessionStorage? storage,
    AccountCache? cache,
    VpnService? vpnService,
    AppleStoreGateway? appleStore,
  })  : _service = service ?? AuthService(),
        _storage = storage ?? SecureSessionStorage(),
        _cache = cache ?? SharedPreferencesAccountCache(),
        _vpnService = vpnService ?? MethodChannelVpnService() {
    _applePurchases = ApplePurchaseController(
      session: () => isSignedIn ? _token : '',
      statusRequest: _service.getAppleIapStatus,
      prepareRequest: _service.prepareApplePurchase,
      verifyRequest: _service.verifyApplePurchase,
      audit: ApplePurchaseAudit(
        service: _service,
        storage: SecureAppleAuditStorage(),
        owner: () => _email,
        session: () => isSignedIn ? _token : '',
      ),
      onEntitled: refreshAccountData,
      store: appleStore,
    );
    _applePurchases.addListener(_onApplePurchaseChanged);
  }

  late final ApplePurchaseController _applePurchases;
  ApplePurchaseController get applePurchases => _applePurchases;
  void _onApplePurchaseChanged() {
    if (!_storeDisposed && _token.isNotEmpty) notifyListeners();
  }

  final AuthService _service;
  final SessionStorage _storage;
  final AccountCache _cache;
  final VpnService _vpnService;

  AuthStatus _status = AuthStatus.initializing;
  String _email = '';
  String _token = '';
  int _storeRequest = 0;
  bool _storeDisposed = false;
  List<StorePlan> _storePlans = const [];
  bool _storeLoading = false;
  bool _storeLoaded = false;
  String _storeError = '';
  List<StorePlan> get storePlans => _storePlans;
  bool get storeLoading => _storeLoading;
  bool get storeLoaded => _storeLoaded;
  String get storeError => _storeError;
  AccountOverview? _overview;
  String _error = '';
  bool _refreshing = false;
  bool _initialized = false;
  TrafficRange _selectedTrafficRange = TrafficRange.sevenDays;
  final Map<TrafficRange, TrafficTrend> _trafficTrends = {};
  bool _trafficLoading = false;
  List<AccountNotice> _notices = const [];
  List<NetworkNode> _networkNodes = const [];
  bool _nodesLoading = false;
  String _nodesError = '';
  String? _selectedNetworkNodeId;
  VpnConnectionStatus _vpnStatus = VpnConnectionStatus.disconnected;
  bool _vpnBusy = false;
  String _vpnError = '';
  Timer? _vpnStatusTimer;
  bool _vpnCertificateUnverified = false;
  bool get vpnCertificateUnverified => _vpnCertificateUnverified;
  // The view owns presentation; the provider never connects unverified HY2
  // without a current user's affirmative answer. Not persisted across sessions.
  Future<bool> Function(String nodeName)? confirmInsecureHy2;

  AuthStatus get status => _status;
  String get email => _email;
  AccountOverview? get overview => _overview;
  String get subscribeUrl => _overview?.subscribeUrl ?? '';
  String get error => _error;
  bool get isRefreshing => _refreshing;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  TrafficRange get selectedTrafficRange => _selectedTrafficRange;
  TrafficTrend? get trafficTrend => _trafficTrends[_selectedTrafficRange];
  bool get isTrafficLoading => _trafficLoading;
  List<AccountNotice> get notices => _notices;
  List<NetworkNode> get networkNodes => _networkNodes;
  bool get nodesLoading => _nodesLoading;
  String get nodesError => _nodesError;
  String? get selectedNetworkNodeId => _selectedNetworkNodeId;
  VpnConnectionStatus get vpnStatus => _vpnStatus;
  bool get vpnBusy => _vpnBusy;
  String get vpnError => _vpnError;
  bool get isVpnConnected => _vpnStatus == VpnConnectionStatus.connected;
  TrafficTrend? trafficTrendFor(TrafficRange range) => _trafficTrends[range];

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final values = await Future.wait([
        _storage.readToken(),
        _storage.readEmail(),
      ]);
      _token = values[0] ?? '';
      _email = values[1] ?? '';
      if (_token.isEmpty) {
        _status = AuthStatus.signedOut;
        notifyListeners();
        return;
      }

      _status = AuthStatus.signedIn;
      await _restoreSafeCache();
      notifyListeners();
      await refreshAccountData();
      if (!_storeDisposed && isSignedIn && _applePurchases.supported) {
        unawaited(refreshStorePlans());
      }
    } catch (_) {
      _status = AuthStatus.signedOut;
      _error = '无法读取安全登录信息，请重新登录';
      notifyListeners();
    }
  }

  Future<RegistrationConfig> getRegistrationConfig() =>
      _service.getRegistrationConfig();

  Future<RegistrationCaptcha> getRegistrationCaptcha() =>
      _service.getRegistrationCaptcha();

  Future<void> sendRegistrationEmailCode({
    required String email,
    String captchaToken = '',
    String captchaAnswer = '',
  }) =>
      _service.sendRegistrationEmailCode(
        email: email,
        captchaToken: captchaToken,
        captchaAnswer: captchaAnswer,
      );

  Future<bool> register(RegistrationInput input) => _authenticate(
        email: input.email,
        request: () => _service.register(input),
        isRegistration: true,
      );

  Future<bool> login({required String email, required String password}) =>
      _authenticate(
          email: email,
          request: () => _service.login(email: email, password: password));

  Future<bool> _authenticate({
    required String email,
    required Future<LoginResult> Function() request,
    bool isRegistration = false,
  }) async {
    if (_status == AuthStatus.signingIn) return false;

    _status = AuthStatus.signingIn;
    _error = '';
    notifyListeners();

    try {
      final result = await request();
      final normalizedEmail = email.trim();
      await _cache.clear();
      await _storage.save(token: result.token, email: normalizedEmail);
      _token = result.token;
      _email = normalizedEmail;
      _status = AuthStatus.signedIn;
      notifyListeners();
      await refreshAccountData();
      if (!_storeDisposed && isSignedIn && _applePurchases.supported) {
        unawaited(refreshStorePlans());
      }
      return isSignedIn;
    } on AuthException catch (error) {
      _status = AuthStatus.signedOut;
      _error = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      try {
        await _storage.clear();
      } catch (_) {}
      _clearMemorySession();
      _status = AuthStatus.signedOut;
      _error =
          isRegistration ? '账号可能已创建，但无法安全保存登录信息，请返回登录' : '无法安全保存登录信息，请稍后重试';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshOverview() async {
    if (_token.isEmpty || _refreshing) return;

    _refreshing = true;
    _error = '';
    notifyListeners();
    try {
      _overview = await _service.getMobileOverview(_token);
      await _cache.writeOverview(_overview!);
    } on AuthException catch (error) {
      await _handleRefreshError(error);
    } catch (_) {
      _error = '获取账号信息失败，请稍后重试';
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshAccountData() async {
    if (_token.isEmpty || _refreshing) return;
    _refreshing = true;
    _trafficLoading = true;
    _error = '';
    notifyListeners();

    try {
      _overview = await _service.getMobileOverview(_token);
      await _cache.writeOverview(_overview!);
    } on AuthException catch (error) {
      await _handleRefreshError(error);
    } catch (_) {
      _error = '获取账号信息失败，请稍后重试';
    }

    if (_status == AuthStatus.signedIn) {
      notifyListeners();
      await Future.wait([
        _refreshTrafficTrends(),
        _refreshNotices(),
      ]);
    }

    _refreshing = false;
    _trafficLoading = false;
    notifyListeners();
  }

  Future<void> selectTrafficRange(TrafficRange range) async {
    if (_selectedTrafficRange == range && _trafficTrends[range] != null) return;
    _selectedTrafficRange = range;
    _error = '';
    notifyListeners();

    if (_trafficTrends[range] == null) {
      final cached = await _cache.readTrend(range);
      if (cached != null) {
        _trafficTrends[range] = cached;
        notifyListeners();
      }
    }
    await _loadTraffic(range);
  }

  Future<void> refreshNetworkNodes() async {
    if (_token.isEmpty || _nodesLoading) return;
    _nodesLoading = true;
    _nodesError = '';
    notifyListeners();
    try {
      _networkNodes = await _service.getNetworkNodes(_token);
      final selectedStillAvailable = _networkNodes.any(
        (node) => node.id == _selectedNetworkNodeId && node.canConnect,
      );
      if (!selectedStillAvailable) {
        _selectedNetworkNodeId = _networkNodes
            .where((node) => node.canConnect)
            .map((node) => node.id)
            .firstOrNull;
      }
    } on AuthException catch (error) {
      if (error.isUnauthorized) {
        await _handleRefreshError(error);
      } else {
        _nodesError = error.message;
      }
    } catch (_) {
      _nodesError = '获取线路列表失败，请稍后重试';
    } finally {
      _nodesLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStorePlans() async {
    if (_storeDisposed || !isSignedIn || _token.isEmpty || _storeLoading) {
      return;
    }
    final token = _token;
    final request = ++_storeRequest;
    _storeLoading = true;
    _storeError = '';
    notifyListeners();
    try {
      final plans = await _service.getApplePlans(token);
      if (_token != token || request != _storeRequest || !isSignedIn) return;
      _storePlans = plans;
      _storeLoaded = true;
      await _applePurchases.load(plans);
    } on AuthException catch (error) {
      if (_token != token || request != _storeRequest) return;
      _storeError = error.message;
      if (error.isUnauthorized) await _handleRefreshError(error);
    } catch (_) {
      if (_token != token || request != _storeRequest) return;
      _storeError = '获取商城套餐失败，请重试';
    } finally {
      if (request == _storeRequest) {
        _storeLoading = false;
      }
      // Session expiry invalidates the request as well; still notify the view
      // about sign-out, but never deliver a callback after provider disposal.
      if (!_storeDisposed) notifyListeners();
    }
  }

  Future<void> initializeVpn() async {
    await refreshVpnStatus();
    if (_vpnStatus == VpnConnectionStatus.unsupported) return;
    _vpnStatusTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshVpnStatus(notify: true),
    );
  }

  Future<void> refreshVpnStatus({bool notify = true}) async {
    try {
      final next = await _vpnService.status();
      final unverified = (next == VpnConnectionStatus.connected ||
              next == VpnConnectionStatus.connecting ||
              next == VpnConnectionStatus.reasserting)
          ? await _vpnService.certificateVerificationSkipped()
          : false;
      if (next == VpnConnectionStatus.disconnected &&
          (_vpnStatus == VpnConnectionStatus.connecting ||
              _vpnStatus == VpnConnectionStatus.reasserting)) {
        final nativeError = await _vpnService.lastError();
        if (nativeError != null && nativeError.isNotEmpty) {
          _vpnError = nativeError;
        }
      }
      if (_vpnStatus == next && _vpnCertificateUnverified == unverified) {
        if (notify && _vpnError.isNotEmpty) notifyListeners();
        return;
      }
      _vpnStatus = next;
      _vpnCertificateUnverified = unverified;
      if (notify) notifyListeners();
    } catch (_) {
      if (_vpnStatus != VpnConnectionStatus.invalid) {
        _vpnStatus = VpnConnectionStatus.invalid;
        if (notify) notifyListeners();
      }
    }
  }

  void selectNetworkNode(NetworkNode node) {
    if (_vpnBusy ||
        !node.canConnect ||
        !_networkNodes.any(
            (candidate) => candidate.id == node.id && candidate.canConnect) ||
        node.id == _selectedNetworkNodeId) {
      return;
    }
    if (_vpnStatus == VpnConnectionStatus.connected ||
        _vpnStatus == VpnConnectionStatus.connecting ||
        _vpnStatus == VpnConnectionStatus.reasserting) {
      unawaited(_switchNetworkNode(node));
      return;
    }
    _selectedNetworkNodeId = node.id;
    _vpnError = '';
    notifyListeners();
  }

  Future<void> toggleVpn() async {
    if (_vpnBusy) return;
    _vpnBusy = true;
    _vpnError = '';
    notifyListeners();

    try {
      if (_vpnStatus == VpnConnectionStatus.connected ||
          _vpnStatus == VpnConnectionStatus.connecting ||
          _vpnStatus == VpnConnectionStatus.reasserting) {
        await _vpnService.disconnect();
      } else {
        if (!isSignedIn) throw const AuthException('请先登录后再连接 VPN');
        if (_networkNodes.isEmpty) await refreshNetworkNodes();
        final node = _networkNodes.firstWhere(
          (candidate) =>
              candidate.id == _selectedNetworkNodeId && candidate.canConnect,
          orElse: () => _networkNodes.firstWhere(
            (candidate) => candidate.canConnect,
            orElse: () => throw const AuthException('当前没有可连接的 VLESS 或 HY2 线路'),
          ),
        );
        _selectedNetworkNodeId = node.id;
        final config = await _configurationFor(node);
        _vpnStatus = VpnConnectionStatus.connecting;
        notifyListeners();
        await _vpnService.connect(config);
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await refreshVpnStatus(notify: false);
    } on _VpnCancelled {
      _vpnError = '';
    } on AuthException catch (error) {
      _vpnError = error.message;
    } on PlatformException catch (error) {
      _vpnError = error.message ?? '无法启动系统 VPN';
    } catch (_) {
      _vpnError = 'VPN 操作失败，请稍后重试';
    } finally {
      _vpnBusy = false;
      notifyListeners();
    }
  }

  Future<MobileVpnConfig> _configurationFor(NetworkNode node) async {
    final nodeId = int.tryParse(node.id);
    if (nodeId == null) throw const AuthException('线路编号无效');
    final token = _token;
    if (!isSignedIn || token.isEmpty) throw const AuthException('请先登录后再连接 VPN');
    final config = await _service.getMobileVpnConfig(
      token,
      nodeId: nodeId,
      appVersion: '${AppBrand.version}+${AppBrand.buildNumber}',
    );
    if (!isSignedIn || _token != token) {
      throw const AuthException('登录状态已变更，请重试');
    }
    final expected =
        node.protocol.toUpperCase() == 'VLESS' ? 'vless' : 'hysteria2';
    if (config.nodeId != nodeId || config.protocol != expected) {
      throw const AuthException('服务器返回的线路配置不匹配');
    }
    if (config.requiresInsecureConsent) {
      final confirm = confirmInsecureHy2;
      if (confirm == null) throw const AuthException('HY2 兼容连接需要确认服务器证书风险');
      if (!await confirm(node.name)) throw const _VpnCancelled();
      if (!isSignedIn || _token != token) {
        throw const AuthException('登录状态已变更，请重试');
      }
      return config.approveInsecureCompatibility();
    }
    return config;
  }

  Future<void> _switchNetworkNode(NetworkNode node) async {
    _vpnBusy = true;
    _vpnError = '';
    notifyListeners();
    try {
      // Validate first: a rejected HY2 config must not drop a working VLESS tunnel.
      final token = _token;
      final config = await _configurationFor(node);
      await _vpnService.disconnect();
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (true) {
        final status = await _vpnService.status();
        _vpnStatus = status;
        if (status == VpnConnectionStatus.disconnected ||
            status == VpnConnectionStatus.invalid) {
          break;
        }
        if (DateTime.now().isAfter(deadline)) {
          throw const AuthException('原连接尚未断开，请稍后重试');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!isSignedIn || _token != token) {
        throw const AuthException('登录状态已变更，请重试');
      }
      _selectedNetworkNodeId = node.id;
      _vpnStatus = VpnConnectionStatus.connecting;
      notifyListeners();
      await _vpnService.connect(config);
      await refreshVpnStatus(notify: false);
    } on _VpnCancelled {
      _vpnError = '';
    } on AuthException catch (error) {
      _vpnError = error.message;
    } on PlatformException catch (error) {
      _vpnError = error.message ?? '无法切换 VPN 线路';
    } catch (_) {
      _vpnError = '切换线路失败，请稍后重试';
    } finally {
      // Connection status always comes from iOS, never from the selected row.
      await refreshVpnStatus(notify: false);
      _vpnBusy = false;
      notifyListeners();
    }
  }

  Future<void> _loadTraffic(TrafficRange range) async {
    if (_token.isEmpty || _trafficLoading) return;
    _trafficLoading = true;
    notifyListeners();
    try {
      final trend = await _service.getMobileTraffic(_token, range);
      _trafficTrends[range] = trend;
      await _cache.writeTrend(trend);
    } on AuthException catch (error) {
      await _handleRefreshError(error);
    } catch (_) {
      _error = '获取流量趋势失败，请稍后重试';
    } finally {
      _trafficLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshTrafficTrends() async {
    await Future.wait(TrafficRange.values.map(_refreshTrafficTrend));
  }

  Future<void> _refreshTrafficTrend(TrafficRange range) async {
    if (_status != AuthStatus.signedIn) return;
    try {
      final trend = await _service.getMobileTraffic(_token, range);
      _trafficTrends[range] = trend;
      await _cache.writeTrend(trend);
    } on AuthException catch (error) {
      if (error.isUnauthorized) {
        await _handleRefreshError(error);
      } else if (_trafficTrends[_selectedTrafficRange] == null) {
        _error = error.message;
      }
    } catch (_) {
      if (_trafficTrends[_selectedTrafficRange] == null) {
        _error = '获取流量趋势失败，请稍后重试';
      }
    }
  }

  Future<void> _refreshNotices() async {
    try {
      _notices = await _service.getAccountNotices(_token);
    } on AuthException catch (error) {
      if (error.isUnauthorized) await _handleRefreshError(error);
      // Announcements are supplementary and must not block account data.
    } catch (_) {
      // Keep the previous in-memory announcements when the request fails.
    }
  }

  Future<void> _restoreSafeCache() async {
    try {
      final values = await Future.wait<Object?>([
        _cache.readOverview(),
        _cache.readTrend(TrafficRange.sevenDays),
        _cache.readTrend(TrafficRange.thirtyDays),
      ]);
      _overview = values[0] as AccountOverview?;
      for (final value in values.skip(1)) {
        if (value is TrafficTrend) _trafficTrends[value.range] = value;
      }
    } catch (_) {
      // A cache failure must never prevent secure session restoration.
    }
  }

  Future<void> _handleRefreshError(AuthException error) async {
    if (error.isUnauthorized) {
      try {
        await Future.wait([_storage.clear(), _cache.clear()]);
      } catch (_) {}
      _clearMemorySession();
      _status = AuthStatus.signedOut;
    }
    _error = error.message;
  }

  Future<void> logout() async {
    try {
      await _vpnService.disconnect();
    } catch (_) {}
    try {
      await Future.wait([_storage.clear(), _cache.clear()]);
    } catch (_) {
      _error = '无法安全退出，请重试';
      notifyListeners();
      return;
    }
    _clearMemorySession();
    _status = AuthStatus.signedOut;
    _error = '';
    notifyListeners();
  }

  void clearError() {
    if (_error.isEmpty) return;
    _error = '';
    notifyListeners();
  }

  void _clearMemorySession() {
    _storeRequest++;
    _storePlans = const [];
    _storeLoading = false;
    _storeLoaded = false;
    _storeError = '';
    _token = '';
    _applePurchases.sessionChanged();
    _email = '';
    _overview = null;
    _trafficTrends.clear();
    _notices = const [];
    _networkNodes = const [];
    _nodesLoading = false;
    _nodesError = '';
    _selectedNetworkNodeId = null;
    _vpnStatus = VpnConnectionStatus.disconnected;
    _vpnCertificateUnverified = false;
    _vpnBusy = false;
    _vpnError = '';
    _selectedTrafficRange = TrafficRange.sevenDays;
  }

  @override
  void dispose() {
    _storeDisposed = true;
    _applePurchases.removeListener(_onApplePurchaseChanged);
    _applePurchases.dispose();
    _storeRequest++;
    _vpnStatusTimer?.cancel();
    super.dispose();
  }
}
