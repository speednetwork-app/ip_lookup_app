import Flutter
import NetworkExtension

final class VpnBridge: NSObject {
  private static let channelName = "com.speednetwork.iplookupapp/vpn"
  private static let providerBundleIdentifier = "com.speednetwork.iplookupapp.PacketTunnel"
  private static let appGroupIdentifier = "group.com.speednetwork.iplookupapp"
  private static let lastErrorKey = "vpn.lastError"
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      loadManager { response in
        switch response {
        case .success(let manager):
          result(Self.statusName(manager?.connection.status ?? .disconnected))
        case .failure(let error):
          result(Self.flutterError(error))
        }
      }
    case "lastError":
      result(
        UserDefaults(suiteName: Self.appGroupIdentifier)?
          .string(forKey: Self.lastErrorKey)
      )
    case "connect":
      guard let configuration = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_configuration", message: "VPN 配置格式无效", details: nil))
        return
      }
      connect(configuration: configuration, result: result)
    case "disconnect":
      loadManager { response in
        switch response {
        case .success(let manager):
          manager?.connection.stopVPNTunnel()
          result(nil)
        case .failure(let error):
          result(Self.flutterError(error))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func connect(configuration: [String: Any], result: @escaping FlutterResult) {
    UserDefaults(suiteName: Self.appGroupIdentifier)?
      .removeObject(forKey: Self.lastErrorKey)
    loadManager { response in
      switch response {
      case .failure(let error):
        result(Self.flutterError(error))
      case .success(let existing):
        let manager = existing ?? NETunnelProviderManager()
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = Self.providerBundleIdentifier
        tunnelProtocol.serverAddress = configuration["address"] as? String ?? "Pikayun"
        tunnelProtocol.providerConfiguration = configuration
        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = "皮卡云安全连接"
        manager.isEnabled = true
        manager.saveToPreferences { error in
          if let error {
            result(Self.flutterError(error))
            return
          }
          manager.loadFromPreferences { error in
            if let error {
              result(Self.flutterError(error))
              return
            }
            do {
              try manager.connection.startVPNTunnel()
              result(nil)
            } catch {
              result(Self.flutterError(error))
            }
          }
        }
      }
    }
  }

  private func loadManager(
    completion: @escaping (Result<NETunnelProviderManager?, Error>) -> Void
  ) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error {
        completion(.failure(error))
        return
      }
      let manager = managers?.first { candidate in
        guard let tunnelProtocol = candidate.protocolConfiguration as? NETunnelProviderProtocol else {
          return false
        }
        return tunnelProtocol.providerBundleIdentifier == Self.providerBundleIdentifier
      }
      completion(.success(manager))
    }
  }

  private static func statusName(_ status: NEVPNStatus) -> String {
    switch status {
    case .invalid: return "invalid"
    case .disconnected: return "disconnected"
    case .connecting: return "connecting"
    case .connected: return "connected"
    case .reasserting: return "reasserting"
    case .disconnecting: return "disconnecting"
    @unknown default: return "invalid"
    }
  }

  private static func flutterError(_ error: Error) -> FlutterError {
    FlutterError(code: "vpn_error", message: error.localizedDescription, details: nil)
  }
}
