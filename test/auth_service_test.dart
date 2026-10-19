import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/models/account_overview.dart';
import 'package:ip_lookup_app/models/account_notice.dart';
import 'package:ip_lookup_app/models/traffic_trend.dart';
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

  test('reads the sanitized mobile overview contract', () async {
    late RequestOptions request;
    final dio = _stubDio((options) {
      request = options;
      return {
        'status': 'success',
        'data': {
          'account_status': 'active',
          'plan_name': 'Example Plan',
          'traffic': {
            'used_bytes': 100,
            'remaining_bytes': 900,
            'total_bytes': 1000,
            'usage_percent': 10,
          },
          'expired_at': null,
          'remaining_days': null,
          'next_reset_at': 1790784000,
          'device_limit': 3,
          'speed_limit_mbps': 0,
          'subscribe_url': 'https://example.com/sub/secret',
        },
      };
    });
    final service = AuthService(dio: dio);

    final overview = await service.getMobileOverview('plain-token');

    expect(request.path, '/user/mobile-overview');
    expect(request.headers['Authorization'], 'Bearer plain-token');
    expect(overview.state, AccountState.active);
    expect(overview.planName, 'Example Plan');
    expect(overview.traffic.remainingBytes, 900);
    expect(overview.deviceLimit, 3);
    expect(overview.subscribeUrl, 'https://example.com/sub/secret');
  });

  test('rejects a non-HTTPS subscription URL in overview', () async {
    final dio = _stubDio((_) {
      return {
        'status': 'success',
        'data': {
          'traffic': <String, dynamic>{},
          'subscribe_url': 'http://example.com/sub/secret',
        },
      };
    });
    final service = AuthService(dio: dio);

    expect(
      service.getMobileOverview('token'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          '服务器返回的订阅地址无效',
        ),
      ),
    );
  });

  test('reads the sanitized mobile traffic contract', () async {
    late RequestOptions request;
    final dio = _stubDio((options) {
      request = options;
      return {
        'status': 'success',
        'data': {
          'range': '7d',
          'period_start': '2026-10-10',
          'period_end': '2026-10-16',
          'upload_bytes': 100,
          'download_bytes': 200,
          'used_bytes': 300,
          'average_daily_bytes': 43,
          'updated_at': 1792137600,
          'daily': [
            {
              'date': '2026-10-16',
              'upload_bytes': 10,
              'download_bytes': 20,
              'total_bytes': 30,
            }
          ],
        },
      };
    });
    final service = AuthService(dio: dio);

    final trend =
        await service.getMobileTraffic('plain-token', TrafficRange.sevenDays);

    expect(request.path, '/user/mobile-traffic');
    expect(request.queryParameters['range'], '7d');
    expect(request.headers['Authorization'], 'Bearer plain-token');
    expect(trend.usedBytes, 300);
    expect(trend.daily.single.totalBytes, 30);
  });

  test('reads and sanitizes account announcements', () async {
    final dio = _stubDio((options) {
      return {
        'status': 'success',
        'data': [
          {
            'id': 8,
            'title': '<b>维护通知</b>',
            'content': '<p>今晚维护</p><script>bad()</script>请稍后重试',
            'updated_at': 1792137600,
          }
        ],
      };
    });
    final service = AuthService(dio: dio);

    final notices = await service.getAccountNotices('plain-token');

    expect(notices, hasLength(1));
    expect(notices.single, isA<AccountNotice>());
    expect(notices.single.title, '维护通知');
    expect(notices.single.content, '今晚维护\n请稍后重试');
    expect(notices.single.content, isNot(contains('script')));
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
