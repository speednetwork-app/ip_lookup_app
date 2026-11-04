import 'package:dio/dio.dart';

import '../models/account_overview.dart';
import '../models/account_notice.dart';
import '../models/traffic_trend.dart';
import '../models/network_node.dart';
import '../models/mobile_vpn_config.dart';
import '../models/registration_config.dart';
import '../models/store_plan.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.isUnauthorized = false, this.code});

  final String message;
  final bool isUnauthorized;
  final String? code;

  @override
  String toString() => message;
}

class LoginResult {
  const LoginResult({required this.token});

  final String token;
}

class AuthService {
  AuthService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.pikayun.com/api/v1',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                headers: const {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;

  Future<Map<String, dynamic>> getAppleIapStatus(String token) =>
      _appleIapRequest(token, '/status');

  Future<Map<String, dynamic>> prepareApplePurchase(
          String token, String productId) =>
      _appleIapRequest(token, '/prepare', data: {'product_id': productId});

  Future<Map<String, dynamic>> verifyApplePurchase(
          String token, String signed) =>
      _appleIapRequest(token, '/verify', data: {'signed_transaction': signed});

  Future<Map<String, dynamic>> _appleIapRequest(String token, String path,
      {Map<String, dynamic>? data}) async {
    try {
      final options = Options(
        headers: {'Authorization': _bearer(token)},
        receiveTimeout: const Duration(seconds: 60),
      );
      final response = data == null
          ? await _dio.get<dynamic>('/user/apple/iap$path', options: options)
          : await _dio.post<dynamic>('/user/apple/iap$path',
              data: data, options: options);
      final body = _asMap(response.data);
      if (body['status'] != 'success' || body['data'] is! Map) {
        throw const AuthException('Apple 购买服务暂不可用，请稍后重试');
      }
      return Map<String, dynamic>.from(body['data'] as Map);
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      if (error.response?.statusCode == 409 &&
          _asMap(error.response?.data)['error_code'] ==
              'APPLE_ACCOUNT_MISMATCH') {
        throw const AuthException(
            '此 Apple 购买记录与当前皮卡云账号不匹配。请切回原购买账号恢复；取消自动续订不会转移订单。',
            code: 'APPLE_ACCOUNT_MISMATCH');
      }
      throw _friendlyDioError(error);
    } catch (_) {
      throw const AuthException('Apple 购买尚未验证完成，请稍后重试');
    }
  }

  Future<List<StorePlan>> getApplePlans(String token) async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/apple/plan/fetch',
        options: Options(headers: {'Authorization': _bearer(token)}),
        queryParameters: {
          'sales_channel': 'apple',
          't': DateTime.now().millisecondsSinceEpoch
        },
      );
      final body = _asMap(response.data);
      if (body['status'] != 'success' || body['data'] is! List) {
        throw const AuthException('获取商城套餐失败，请重试');
      }
      return (body['data'] as List)
          .whereType<Map>()
          .map((item) =>
              StorePlan.fromAppleJson(Map<String, dynamic>.from(item)))
          .whereType<StorePlan>()
          .toList(growable: false);
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      throw _friendlyDioError(error);
    } catch (_) {
      throw const AuthException('获取商城套餐失败，请稍后重试');
    }
  }

  Future<RegistrationConfig> getRegistrationConfig() async {
    final body = await _registrationRequest('/guest/comm/config');
    final data = _asMap(body['data']);
    if (body['data'] is! Map ||
        !data.containsKey('is_email_verify') ||
        !data.containsKey('is_invite_force') ||
        !data.containsKey('simple_captcha_enable') ||
        !(data.containsKey('is_captcha') || data.containsKey('is_recaptcha'))) {
      throw const AuthException('注册配置无效，请重试');
    }
    return RegistrationConfig.fromJson(data);
  }

  Future<RegistrationCaptcha> getRegistrationCaptcha() async {
    final body = await _registrationRequest('/guest/comm/simpleCaptcha');
    final data = _asMap(body['data']);
    final token = data['token'];
    final question = data['question'];
    final ttl = int.tryParse('${data['ttl']}') ?? 0;
    if (token is! String ||
        token.isEmpty ||
        question is! String ||
        question.isEmpty ||
        ttl <= 0) {
      throw const AuthException('验证码获取失败，请重试');
    }
    return RegistrationCaptcha(
      token: token,
      question: question,
      expiresAt: DateTime.now().add(Duration(seconds: ttl)),
    );
  }

  Future<void> sendRegistrationEmailCode({
    required String email,
    String captchaToken = '',
    String captchaAnswer = '',
  }) async {
    final body = await _registrationRequest(
      '/passport/comm/sendEmailVerify',
      data: {
        'email': email.trim(),
        if (captchaToken.isNotEmpty) 'simple_captcha_token': captchaToken,
        if (captchaAnswer.trim().isNotEmpty)
          'simple_captcha_answer': captchaAnswer.trim(),
      },
    );
    if (body['data'] != true) {
      throw const AuthException('邮件发送未获确认，请稍后重试');
    }
  }

  Future<LoginResult> register(RegistrationInput input) async {
    final body = await _registrationRequest(
      '/passport/auth/register',
      data: input.toJson(),
    );
    final data = _asMap(body['data']);
    final authData = data['auth_data'];
    final plainToken = data['token'];
    final token = authData is String && authData.trim().isNotEmpty
        ? authData.trim()
        : plainToken is String
            ? plainToken.trim()
            : '';
    if (token.isEmpty) {
      // Do not retry registration: the server may already have created it.
      throw const AuthException('服务器未返回登录凭证；如账号已创建，请返回登录');
    }
    return LoginResult(token: token);
  }

  Future<Map<String, dynamic>> _registrationRequest(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = data == null
          ? await _dio.get<dynamic>(path,
              queryParameters: {'t': DateTime.now().millisecondsSinceEpoch})
          : await _dio.post<dynamic>(path, data: data);
      final body = _asMap(response.data);
      if (body['status'] != 'success') {
        throw AuthException(_message(body, fallback: '注册请求失败，请稍后重试'));
      }
      return body;
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final message = _message(_asMap(error.response?.data), fallback: '');
      if (status != null && status < 500 && message.isNotEmpty) {
        throw AuthException(message);
      }
      if (status == 429) {
        throw const AuthException('操作过于频繁，请稍后重试');
      }
      if (status == null) throw _friendlyDioError(error);
      throw const AuthException('注册服务暂不可用，请稍后重试');
    } catch (_) {
      throw const AuthException('注册请求失败，请稍后重试');
    }
  }

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

  Future<AccountOverview> getMobileOverview(String token) async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/mobile-overview',
        options: Options(headers: {'Authorization': _bearer(token)}),
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      );
      final body = _asMap(response.data);
      if (body['status'] != 'success') {
        throw AuthException(_message(body, fallback: '获取账号信息失败'));
      }

      final overview = AccountOverview.fromJson(_asMap(body['data']));
      if (overview.subscribeUrl.isNotEmpty) {
        final uri = Uri.tryParse(overview.subscribeUrl);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
          throw const AuthException('服务器返回的订阅地址无效');
        }
      }
      return overview;
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      throw _friendlyDioError(error);
    } catch (_) {
      throw const AuthException('获取账号信息失败，请稍后重试');
    }
  }

  Future<TrafficTrend> getMobileTraffic(
    String token,
    TrafficRange range,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/mobile-traffic',
        options: Options(headers: {'Authorization': _bearer(token)}),
        queryParameters: {
          'range': range.apiValue,
          't': DateTime.now().millisecondsSinceEpoch,
        },
      );
      final body = _asMap(response.data);
      if (body['status'] != 'success') {
        throw AuthException(_message(body, fallback: '获取流量趋势失败'));
      }
      return TrafficTrend.fromJson(_asMap(body['data']));
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      throw _friendlyDioError(error);
    } catch (_) {
      throw const AuthException('获取流量趋势失败，请稍后重试');
    }
  }

  Future<List<AccountNotice>> getAccountNotices(String token) async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/notice/fetch',
        options: Options(headers: {'Authorization': _bearer(token)}),
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      );
      final body = _asMap(response.data);
      final rawData = body['data'];
      if (body['status'] != 'success' || rawData is! List) {
        throw AuthException(_message(body, fallback: '获取系统公告失败'));
      }
      return rawData
          .whereType<Map>()
          .map((item) => AccountNotice.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((notice) => notice.isVisible)
          .take(5)
          .toList(growable: false);
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      throw _friendlyDioError(error);
    } catch (_) {
      throw const AuthException('获取系统公告失败，请稍后重试');
    }
  }

  Future<List<NetworkNode>> getNetworkNodes(String token) async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/server/fetch',
        options: Options(headers: {'Authorization': _bearer(token)}),
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      );
      final body = response.data;
      final rawList = body is List
          ? body
          : body is Map
              ? body['data']
              : null;
      if (rawList is! List) {
        throw const AuthException('获取线路列表失败');
      }

      return rawList
          .whereType<Map>()
          .map((item) => NetworkNode.fromJson(Map<String, dynamic>.from(item)))
          .where((node) => node.id.isNotEmpty && node.protocol != 'TUIC')
          .toList(growable: false);
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      throw _friendlyDioError(error);
    } catch (_) {
      throw const AuthException('获取线路列表失败，请稍后重试');
    }
  }

  Future<MobileVpnConfig> getMobileVpnConfig(
    String token, {
    required int nodeId,
    String? appVersion,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/user/mobile-vpn/config',
        data: {
          'node_id': nodeId,
          'platform': 'ios',
          'capabilities': ['hy2-insecure-v1'],
          if (appVersion != null && appVersion.trim().isNotEmpty)
            'app_version': appVersion.trim(),
        },
        options: Options(headers: {'Authorization': _bearer(token)}),
      );
      final body = _asMap(response.data);
      if (body['status'] != 'success') {
        throw AuthException(_message(body, fallback: '获取 VPN 配置失败'));
      }
      return MobileVpnConfig.fromJson(_asMap(body['data']));
    } on AuthException {
      rethrow;
    } on DioException catch (error) {
      throw _friendlyDioError(error);
    } on FormatException {
      throw const AuthException('服务器返回的 VPN 配置无效');
    } catch (_) {
      throw const AuthException('获取 VPN 配置失败，请稍后重试');
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
        return AuthException(loginRequest ? '登录失败，请稍后重试' : '获取账号信息失败，请稍后重试');
    }
  }
}
