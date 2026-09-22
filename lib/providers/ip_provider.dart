import 'package:flutter/material.dart';
import '../models/ip_info.dart';
import '../services/ip_api_service.dart';

class IpProvider with ChangeNotifier {
  final IpApiService _service = IpApiService();

  IpInfo? _ipInfo;
  bool _isLoading = false;
  String _errorMessage = '';

  IpInfo? get ipInfo => _ipInfo;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<void> getMyIp() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _ipInfo = await _service.getMyIp();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> queryIp(String ip) async {
    if (ip.isEmpty) {
      _errorMessage = 'Please enter an IP address';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _ipInfo = await _service.queryIp(ip);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _ipInfo = null;
    _errorMessage = '';
    _isLoading = false;
    notifyListeners();
  }
}
