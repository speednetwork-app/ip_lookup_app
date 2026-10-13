import 'package:dio/dio.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.isUnauthorized = false});

  final String message;
  final bool isUnauthorized;

  @override
  String toString() => message;
}

class LoginResult {
  const LoginResult({required this.token});

  final String token;
}

/// Minimal API client for the first account release.
///
/// Deliberately only understands the login token and `subscribe_url`. Plan,
/// traffic and billing fields returned by the server are ignored.
class AuthService {
  AuthService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://app.pikayun.com/api/v1',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                headers: const {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/passport/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final body = _asMap(response.data);
      if (body['status'] != 'success') {
        throw AuthException(_message(body, fallback: '邮箱或密码不正确'));
      }

      final data = _asMap(body['data']);
      final authData = data['auth_data'];
      final plainToken = data['token'];
      final token = authData is String && authData.trim().isNotEmpty
          ? authData.trim()
          : plainToken is String && plainToken.trim().isNotEmpty
              ? plainToken.trim()
              : '';
      if (token.isEmpty) {
        throw const AuthException('登录成功，但服务器没有返回登录凭证');
      }
      return LoginResult(token: token);
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      throw _friendlyDioError(error, loginRequest: true);
    } catch (_) {
      throw const AuthException('登录失败，请稍后重试');
    }
  }

  Future<String> getSubscribeUrl(String token) async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/getSubscribe',
        options: Options(headers: {'Authorization': _bearer(token)}),
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      );
      final body = _asMap(response.data);
      if (body['status'] != 'success') {
        throw AuthException(_message(body, fallback: '获取订阅地址失败'));
      }

      final data = _asMap(body['data']);
      final value = data['subscribe_url'];
      if (value is! String || value.trim().isEmpty) {
        throw const AuthException('当前账号暂无可用订阅地址');
      }
      final url = value.trim();
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const AuthException('服务器返回的订阅地址无效');
      }
      return url;
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      throw _friendlyDioError(error);
    } catch (_) {
      throw const AuthException('获取订阅地址失败，请稍后重试');
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _message(
    Map<String, dynamic> body, {
    required String fallback,
  }) {
    final value = body['message'];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  static String _bearer(String token) {
    final trimmed = token.trim();
    return trimmed.toLowerCase().startsWith('bearer ')
        ? trimmed
        : 'Bearer $trimmed';
  }

  static AuthException _friendlyDioError(
    DioException error, {
    bool loginRequest = false,
  }) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return AuthException(
        loginRequest ? '邮箱或密码不正确' : '登录已失效，请重新登录',
        isUnauthorized: true,
      );
    }

    final responseBody = _asMap(error.response?.data);
    final serverMessage = _message(responseBody, fallback: '');
    if (serverMessage.isNotEmpty && statusCode != null && statusCode < 500) {
      return AuthException(serverMessage);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AuthException('连接服务器超时，请稍后重试');
      case DioExceptionType.connectionError:
        return const AuthException('无法连接服务器，请检查网络');
      default:
        return AuthException(loginRequest ? '登录失败，请稍后重试' : '获取订阅地址失败，请稍后重试');
    }
  }
}
