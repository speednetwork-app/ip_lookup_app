import 'package:flutter_test/flutter_test.dart';
import 'package:ip_lookup_app/services/ip_api_service.dart';

void main() {
  group('IP address validation', () {
    test('accepts valid IPv4 and IPv6 addresses', () {
      expect(IpApiService.isValidIpAddress('8.8.8.8'), isTrue);
      expect(IpApiService.isValidIpAddress('2001:4860:4860::8888'), isTrue);
    });

    test('rejects domains, URLs and malformed addresses', () {
      expect(IpApiService.isValidIpAddress('example.com'), isFalse);
      expect(IpApiService.isValidIpAddress('https://example.com'), isFalse);
      expect(IpApiService.isValidIpAddress('999.1.1.1'), isFalse);
      expect(IpApiService.isValidIpAddress('not an ip'), isFalse);
      expect(IpApiService.isValidIpAddress('fe80::1%en0'), isFalse);
    });

    test('query rejects invalid input before making a request', () {
      final service = IpApiService();

      expect(
        () => service.queryIp('example.com'),
        throwsA(
          isA<IpLookupException>().having(
            (error) => error.message,
            'message',
            '请输入有效的 IPv4 或 IPv6 地址',
          ),
        ),
      );
    });
  });
}
