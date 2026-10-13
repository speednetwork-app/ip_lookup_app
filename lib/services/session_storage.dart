import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStorage {
  Future<String?> readToken();
  Future<String?> readEmail();
  Future<void> save({required String token, required String email});
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'account_auth_token';
  static const _emailKey = 'account_email';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<String?> readEmail() => _storage.read(key: _emailKey);

  @override
  Future<void> save({required String token, required String email}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _emailKey, value: email);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
  }
}
