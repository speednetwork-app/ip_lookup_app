import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/services/auth_service.dart';

void main() {
  test('uses the existing login contract and accepts auth_data', () async {
    late RequestOptions request;
    final dio = _stubDio((options) {
      request = options;
      return {
        'status': 'success',
        'data': {'auth_data': 'Bearer server-token'},
      };
    });
    final service = AuthService(dio: dio);

    final result = await service.login(
      email: 'user@example.com',
      password: 'password',
    );

    expect(request.path, '/passport/auth/login');
    expect(request.method, 'POST');
    expect(request.data, {
      'email': 'user@example.com',
      'password': 'password',
    });
    expect(result.token, 'Bearer server-token');
  });

  test('reads only subscribe_url from the subscription response', () async {
    late RequestOptions request;
    final dio = _stubDio((options) {
      request = options;
      return {
        'status': 'success',
        'data': {
          'subscribe_url': 'https://example.com/sub/secret',
          'plan': {'name': 'ignored'},
          'transfer_enable': 123,
          'd': 45,
        },
      };
    });
    final service = AuthService(dio: dio);

    final url = await service.getSubscribeUrl('plain-token');

    expect(request.path, '/user/getSubscribe');
    expect(request.headers['Authorization'], 'Bearer plain-token');
    expect(url, 'https://example.com/sub/secret');
  });

  test('rejects a non-HTTPS subscription URL', () async {
    final dio = _stubDio((_) {
      return {
        'status': 'success',
        'data': {'subscribe_url': 'http://example.com/sub/secret'},
      };
    });
    final service = AuthService(dio: dio);

    expect(
      service.getSubscribeUrl('token'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          '服务器返回的订阅地址无效',
        ),
      ),
    );
  });
}

Dio _stubDio(dynamic Function(RequestOptions options) responseBuilder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.pikayun.com/api/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: responseBuilder(options),
          ),
        );
      },
    ),
  );
  return dio;
}
