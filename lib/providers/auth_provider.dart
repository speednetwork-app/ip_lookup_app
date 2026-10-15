import 'package:flutter/foundation.dart';

import '../models/account_overview.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';

enum AuthStatus { initializing, signedOut, signingIn, signedIn }

class AuthProvider with ChangeNotifier {
  AuthProvider({AuthService? service, SessionStorage? storage})
      : _service = service ?? AuthService(),
        _storage = storage ?? SecureSessionStorage();

  final AuthService _service;
  final SessionStorage _storage;

  AuthStatus _status = AuthStatus.initializing;
  String _email = '';
  String _token = '';
  AccountOverview? _overview;
  String _error = '';
  bool _refreshing = false;
  bool _initialized = false;

  AuthStatus get status => _status;
  String get email => _email;
  AccountOverview? get overview => _overview;
  String get subscribeUrl => _overview?.subscribeUrl ?? '';
  String get error => _error;
  bool get isRefreshing => _refreshing;
  bool get isSignedIn => _status == AuthStatus.signedIn;

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
      notifyListeners();
      await refreshOverview();
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
      await _storage.save(token: result.token, email: normalizedEmail);
      _token = result.token;
      _email = normalizedEmail;
      _status = AuthStatus.signedIn;
      notifyListeners();
      await refreshOverview();
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
    } on AuthException catch (error) {
      if (error.isUnauthorized) {
        try {
          await _storage.clear();
        } catch (_) {}
        _clearMemorySession();
        _status = AuthStatus.signedOut;
      }
      _error = error.message;
    } catch (_) {
      _error = '获取账号信息失败，请稍后重试';
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _storage.clear();
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
  }
}
