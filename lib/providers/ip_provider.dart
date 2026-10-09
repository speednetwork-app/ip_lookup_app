import 'package:flutter/foundation.dart';

import '../models/ip_info.dart';
import '../services/ip_api_service.dart';
import 'history_provider.dart';

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

  IpInfo? get myIp => _myIp;
  bool get isMyIpLoading => _myIpLoading;
  String get myIpError => _myIpError;

  IpInfo? get result => _result;
  bool get isLoading => _loading;
  String get error => _error;

  Future<void> loadMyIp() async {
    _myIpLoading = true;
    _myIpError = '';
    notifyListeners();

    try {
      _myIp = await _service.getMyIp();
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

  void clearResults() {
    _result = null;
    _error = '';
    notifyListeners();
  }
}
