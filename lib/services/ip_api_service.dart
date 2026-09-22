import 'package:dio/dio.dart';
import '../models/ip_info.dart';

class IpApiService {
  final Dio _dio = Dio();
  static const String _apiUrl1 = 'http://ip-api.com/json/';
  static const String _apiUrl2 = 'https://ipapi.co/json/';

  Future<IpInfo> getMyIp() async {
    try {
      final response = await _dio.get(_apiUrl1).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.statusCode == 200) {
        return IpInfo.fromJson(response.data);
      }
      throw Exception('Failed to get IP');
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  Future<IpInfo> queryIp(String ip) async {
    try {
      final response = await _dio.get('$_apiUrl1$ip').timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.statusCode == 200) {
        return IpInfo.fromJson(response.data);
      }
      throw Exception('Failed to query IP');
    } catch (e) {
      try {
        final response2 = await _dio
            .get('$_apiUrl2?ip_address=$ip')
            .timeout(const Duration(seconds: 10));

        if (response2.statusCode == 200) {
          return IpInfo.fromJson(response2.data);
        }
      } catch (_) {
        throw Exception('Error: ${e.toString()}');
      }
      throw Exception('Error: ${e.toString()}');
    }
  }
}
