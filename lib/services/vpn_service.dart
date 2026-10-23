import 'package:flutter/services.dart';

class VpnServiceException implements Exception {
  const VpnServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin boundary for the iOS Network Extension implementation.
///
/// The native tunnel target is intentionally kept outside the Flutter UI. Until
/// that signed target is installed, calls fail visibly instead of reporting a
/// connection that does not exist.
class VpnService {
  const VpnService();

  static const _channel = MethodChannel(
    'com.superrobinchao.iplookup/vpn',
  );

  Future<void> connect(String nodeId) async {
    try {
      await _channel.invokeMethod<void>('connect', {'nodeId': nodeId});
    } on MissingPluginException {
      throw const VpnServiceException('当前安装包尚未包含系统连接组件');
    } on PlatformException catch (error) {
      throw VpnServiceException(error.message ?? '无法启动系统连接');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<void>('disconnect');
    } on MissingPluginException {
      throw const VpnServiceException('当前安装包尚未包含系统连接组件');
    } on PlatformException catch (error) {
      throw VpnServiceException(error.message ?? '无法断开系统连接');
    }
  }
}
