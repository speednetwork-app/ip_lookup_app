import 'package:flutter/foundation.dart';

import '../models/network_node.dart';
import '../services/vpn_service.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting }

class VpnProvider with ChangeNotifier {
  VpnProvider({VpnService? service}) : _service = service ?? const VpnService();

  final VpnService _service;
  VpnStatus _status = VpnStatus.disconnected;
  NetworkNode? _selectedNode;
  String _error = '';

  VpnStatus get status => _status;
  NetworkNode? get selectedNode => _selectedNode;
  String get error => _error;
  bool get isBusy =>
      _status == VpnStatus.connecting || _status == VpnStatus.disconnecting;

  void selectNode(NetworkNode node) {
    if (isBusy || _selectedNode?.id == node.id) return;
    _selectedNode = node;
    _error = '';
    notifyListeners();
  }

  Future<void> connect() async {
    final node = _selectedNode;
    if (node == null) {
      _error = '请先选择一条线路';
      notifyListeners();
      return;
    }
    if (!node.isOnline) {
      _error = '该线路目前不可用，请选择在线线路';
      notifyListeners();
      return;
    }

    _status = VpnStatus.connecting;
    _error = '';
    notifyListeners();
    try {
      await _service.connect(node.id);
      _status = VpnStatus.connected;
    } on VpnServiceException catch (error) {
      _status = VpnStatus.disconnected;
      _error = error.message;
    } catch (_) {
      _status = VpnStatus.disconnected;
      _error = '连接失败，请稍后重试';
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (_status != VpnStatus.connected) return;
    _status = VpnStatus.disconnecting;
    _error = '';
    notifyListeners();
    try {
      await _service.disconnect();
      _status = VpnStatus.disconnected;
    } on VpnServiceException catch (error) {
      _status = VpnStatus.connected;
      _error = error.message;
    } catch (_) {
      _status = VpnStatus.connected;
      _error = '断开失败，请稍后重试';
    }
    notifyListeners();
  }

  void reset() {
    _status = VpnStatus.disconnected;
    _selectedNode = null;
    _error = '';
    notifyListeners();
  }
}
