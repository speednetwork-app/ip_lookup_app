import 'package:dio/dio.dart';
import '../models/ip_info.dart';

/// 接口明确给出了结论（如"这不是合法 IP"），重试别的数据源也是同样结果。
class IpLookupException implements Exception {
  IpLookupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 批量查询里的单条结果——要么成功，要么带着失败原因，
/// 一个 IP 查不到不该让整批都没有结果。
class BatchResult {
  BatchResult.success(this.query, IpInfo this.info) : error = null;
  BatchResult.failure(this.query, String this.error) : info = null;

  final String query;
  final IpInfo? info;
  final String? error;

  bool get isSuccess => info != null;
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

  /// 一次查询最多这么多个，再多就该考虑付费接口了。
  static const maxBatchSize = 20;

  /// 同时在飞的请求数。免费接口按 IP 限流，一次性全发出去很容易被拒，
  /// 分批发既稳妥也不会慢太多。
  static const _batchConcurrency = 3;

  /// 批量查询。单条失败不影响其余，结果顺序与输入一致。
  ///
  /// [onProgress] 每完成一条回调一次，用于驱动进度显示。
  Future<List<BatchResult>> queryBatch(
    List<String> ips, {
    void Function(int done, int total)? onProgress,
  }) async {
    final targets = ips
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet() // 用户粘贴的列表里常有重复，没必要查两遍
        .take(maxBatchSize)
        .toList();

    final results = List<BatchResult?>.filled(targets.length, null);
    var done = 0;

    for (var start = 0; start < targets.length; start += _batchConcurrency) {
      final end = (start + _batchConcurrency).clamp(0, targets.length);
      await Future.wait([
        for (var i = start; i < end; i++)
          _fetch(targets[i]).then(
            (info) => results[i] = BatchResult.success(targets[i], info),
            onError: (Object e) =>
                results[i] = BatchResult.failure(targets[i], e.toString()),
          ).whenComplete(() {
            done++;
            onProgress?.call(done, targets.length);
          }),
      ]);
    }

    return results.whereType<BatchResult>().toList();
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
