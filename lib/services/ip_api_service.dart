import 'package:dio/dio.dart';
import '../models/ip_info.dart';

/// 接口明确给出了结论（如"这不是合法 IP"），重试别的数据源也是同样结果。
class IpLookupException implements Exception {
  IpLookupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// IP 查询服务。
///
/// 两个数据源都走 HTTPS —— iOS 的 App Transport Security 默认拦截明文 HTTP，
/// 用 HTTP 的接口（如 ip-api.com 免费版）在真机上会直接失败。
class IpApiService {
  IpApiService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  /// 查询本机公网 IP。传 null 给 [_fetch] 表示查自己。
  Future<IpInfo> getMyIp() => _fetch(null);

  Future<IpInfo> queryIp(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) {
      throw IpLookupException('请输入 IP 地址');
    }
    return _fetch(trimmed);
  }

  /// 先试主数据源。只有在"连不上"时才退到备用源——如果主源已经明确
  /// 判定这个 IP 非法，换个数据源也是同样答案，不如直接把原因告诉用户。
  Future<IpInfo> _fetch(String? ip) async {
    try {
      return await _get('https://ipwho.is/${ip ?? ''}');
    } on IpLookupException {
      rethrow;
    } catch (_) {
      try {
        final path = ip == null ? 'json/' : '$ip/json/';
        return await _get('https://ipapi.co/$path');
      } on IpLookupException {
        rethrow;
      } catch (_) {
        throw IpLookupException('查询失败，请检查网络连接后重试');
      }
    }
  }

  Future<IpInfo> _get(String url) async {
    final response = await _dio.get(url);
    final data = response.data;

    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw Exception('接口返回异常');
    }

    // ipwho.is 用 success:false、ipapi.co 用 error:true 表示查询被拒，
    // 两者此时 HTTP 状态码仍是 200，必须单独判断。
    if (data['success'] == false || data['error'] == true) {
      final reason = data['message'] ?? data['reason'];
      // 限流是服务端的临时状态，不是这个 IP 的结论，应该让调用方去试备用源。
      if (reason.toString().contains('RateLimited')) {
        throw Exception('rate limited');
      }
      throw IpLookupException(_friendly(reason));
    }

    return IpInfo.fromJson(data);
  }

  String _friendly(dynamic reason) {
    final text = reason?.toString() ?? '';
    if (text.toLowerCase().contains('invalid')) return '这不是一个有效的 IP 地址';
    return text.isEmpty ? '查询失败' : text;
  }
}
