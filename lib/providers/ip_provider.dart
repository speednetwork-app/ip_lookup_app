import 'package:flutter/foundation.dart';

import '../models/ip_info.dart';
import '../services/ip_api_service.dart';
import 'history_provider.dart';

/// 批量查询的进行状态。
class BatchProgress {
  const BatchProgress({required this.done, required this.total});

  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
}

class IpProvider with ChangeNotifier {
  IpProvider({required HistoryProvider history, IpApiService? service})
      : _history = history,
        _service = service ?? IpApiService();

  final IpApiService _service;

  /// 查询成功后写历史统一在这里做，省得每个调用点各记一遍、漏掉一处。
  final HistoryProvider _history;

  IpInfo? _myIp;
  bool _myIpLoading = false;
  String _myIpError = '';

  IpInfo? _result;
  bool _loading = false;
  String _error = '';

  List<BatchResult> _batchResults = [];
  BatchProgress? _batchProgress;

  IpInfo? get myIp => _myIp;
  bool get isMyIpLoading => _myIpLoading;
  String get myIpError => _myIpError;

  IpInfo? get result => _result;
  bool get isLoading => _loading;
  String get error => _error;

  List<BatchResult> get batchResults => List.unmodifiable(_batchResults);
  BatchProgress? get batchProgress => _batchProgress;
  bool get isBatchRunning => _batchProgress != null;

  Future<void> loadMyIp() async {
    _myIpLoading = true;
    _myIpError = '';
    notifyListeners();

    try {
      _myIp = await _service.getMyIp();
      await _history.add(_myIp!);
    } catch (e) {
      _myIpError = e.toString();
    } finally {
      _myIpLoading = false;
      notifyListeners();
    }
  }

  Future<void> lookup(String ip) async {
    _loading = true;
    _error = '';
    _batchResults = [];
    notifyListeners();

    try {
      _result = await _service.queryIp(ip);
      await _history.add(_result!);
    } catch (e) {
      _result = null;
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 批量查询。输入允许换行、逗号、空格混着分隔——用户多半是从别处
  /// 粘贴一坨文本过来的，不该要求他们先手工整理格式。
  Future<void> lookupBatch(String raw) async {
    final ips = raw
        .split(RegExp(r'[\s,;，、]+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (ips.isEmpty) {
      _error = '请至少输入一个 IP 地址';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = '';
    _result = null;
    _batchResults = [];
    _batchProgress = BatchProgress(done: 0, total: ips.length);
    notifyListeners();

    try {
      _batchResults = await _service.queryBatch(
        ips,
        onProgress: (done, total) {
          _batchProgress = BatchProgress(done: done, total: total);
          notifyListeners();
        },
      );
      for (final r in _batchResults.where((r) => r.isSuccess)) {
        await _history.add(r.info!);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      _batchProgress = null;
      notifyListeners();
    }
  }

  void clearResults() {
    _result = null;
    _batchResults = [];
    _error = '';
    notifyListeners();
  }
}
