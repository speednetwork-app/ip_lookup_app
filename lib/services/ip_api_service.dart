import 'package:dio/dio.dart';
import '../models/ip_info.dart';

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
      throw Exception('请输入 IP 地址');
    }
    return _fetch(trimmed);
  }

  /// 先试主数据源，失败再退到备用源；两个都挂了才抛错。
  Future<IpInfo> _fetch(String? ip) async {
    try {
      return await _get('https://ipwho.is/${ip ?? ''}');
    } catch (_) {
      try {
        final path = ip == null ? 'json/' : '$ip/json/';
        return await _get('https://ipapi.co/$path');
      } catch (_) {
        throw Exception('查询失败，请检查网络或 IP 地址是否正确');
      }
    }
  }

  Future<IpInfo> _get(String url) async {
    final response = await _dio.get(url);
    final data = response.data;

    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw Exception('接口返回异常');
    }

    // ipwho.is 用 success:false、ipapi.co 用 error:true 表示无效 IP，
    // 两者此时 HTTP 状态码仍是 200，必须单独判断。
    if (data['success'] == false || data['error'] == true) {
      throw Exception(data['message'] ?? data['reason'] ?? '无效的 IP 地址');
    }

    return IpInfo.fromJson(data);
  }
}
