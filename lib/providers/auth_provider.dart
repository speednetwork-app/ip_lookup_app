import 'package:flutter/foundation.dart';

import '../models/account_overview.dart';
import '../models/account_notice.dart';
import '../models/traffic_trend.dart';
import '../services/account_cache.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';

enum AuthStatus { initializing, signedOut, signingIn, signedIn }

class AuthProvider with ChangeNotifier {
  AuthProvider({
    AuthService? service,
    SessionStorage? storage,
    AccountCache? cache,
  })  : _service = service ?? AuthService(),
        _storage = storage ?? SecureSessionStorage(),
        _cache = cache ?? SharedPreferencesAccountCache();

  final AuthService _service;
  final SessionStorage _storage;
  final AccountCache _cache;

  AuthStatus _status = AuthStatus.initializing;
  String _email = '';
  String _token = '';
  AccountOverview? _overview;
  String _error = '';
  bool _refreshing = false;
  bool _initialized = false;
  TrafficRange _selectedTrafficRange = TrafficRange.sevenDays;
  final Map<TrafficRange, TrafficTrend> _trafficTrends = {};
  bool _trafficLoading = false;
  List<AccountNotice> _notices = const [];

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
    } catch (_) {
      _status = AuthStatus.signedOut;
      _error = '无法读取安全登录信息，请重新登录';
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    if (_status == AuthStatus.signingIn) return false;

    _status = AuthStatus.signingIn;
    _error = '';
    notifyListeners();

    try {
      final result = await _service.login(email: email, password: password);
      final normalizedEmail = email.trim();
      await _cache.clear();
      await _storage.save(token: result.token, email: normalizedEmail);
      _token = result.token;
      _email = normalizedEmail;
      _status = AuthStatus.signedIn;
      notifyListeners();
      await refreshAccountData();
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
      _error = '无法安全保存登录信息，请稍后重试';
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
    _token = '';
    _email = '';
    _overview = null;
    _trafficTrends.clear();
    _notices = const [];
    _selectedTrafficRange = TrafficRange.sevenDays;
  }
}
