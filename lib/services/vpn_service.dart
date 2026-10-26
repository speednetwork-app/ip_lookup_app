import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/mobile_vpn_config.dart';

enum VpnConnectionStatus {
  unsupported,
  invalid,
  disconnected,
  connecting,
  connected,
  reasserting,
  disconnecting,
}

abstract class VpnService {
  Future<VpnConnectionStatus> status();

  Future<String?> lastError();

  Future<void> connect(MobileVpnConfig config);

  Future<void> disconnect();
}

class MethodChannelVpnService implements VpnService {
  MethodChannelVpnService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.speednetwork.iplookupapp/vpn';
  final MethodChannel _channel;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<VpnConnectionStatus> status() async {
    if (!_isSupported) return VpnConnectionStatus.unsupported;
    final value = await _channel.invokeMethod<String>('status');
    return VpnConnectionStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => VpnConnectionStatus.invalid,
    );
  }

  @override
  Future<String?> lastError() async {
    if (!_isSupported) return null;
    return _channel.invokeMethod<String>('lastError');
  }

  @override
  Future<void> connect(MobileVpnConfig config) async {
    if (!_isSupported) {
      throw PlatformException(
        code: 'unsupported_platform',
        message: 'VPN 连接仅支持 iPhone 和 iPad',
      );
    }
    await _channel.invokeMethod<void>('connect', config.toPlatformMap());
  }

  @override
  Future<void> disconnect() async {
    if (!_isSupported) return;
    await _channel.invokeMethod<void>('disconnect');
  }
}
