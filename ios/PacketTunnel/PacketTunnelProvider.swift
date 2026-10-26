import Darwin
import LibXray
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private static let appGroupIdentifier = "group.com.speednetwork.iplookupapp"
  private static let lastErrorKey = "vpn.lastError"
  private static let lastStageKey = "vpn.lastStage"
  private let worker = DispatchQueue(
    label: "com.speednetwork.iplookupapp.PacketTunnel.worker",
    qos: .userInitiated
  )
  private var xrayRunning = false

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    Self.record(stage: "正在读取 VPN 配置")
    do {
      let configuration = try TunnelConfiguration(
        protocolConfiguration: protocolConfiguration
      )
      setTunnelNetworkSettings(makeNetworkSettings()) { [weak self] error in
        guard let self else {
          let failure = Self.error("VPN 扩展已终止")
          Self.record(stage: "VPN 扩展启动", error: failure)
          completionHandler(failure)
          return
        }
        if let error {
          Self.record(stage: "应用系统网络设置", error: error)
          completionHandler(error)
          return
        }
        Self.record(stage: "正在取得系统 TUN 接口")
        guard let fileDescriptor = Self.findTunnelFileDescriptor() else {
          let failure = Self.error("无法取得系统 VPN 网络接口")
          Self.record(stage: "取得系统 TUN 接口", error: failure)
          completionHandler(failure)
          return
        }
        self.worker.async {
          do {
            Self.record(stage: "正在启动 Xray 内核")
            let xrayJSON = try configuration.makeXrayJSON(
              tunnelFileDescriptor: fileDescriptor
            )
            try Self.invoke(method: "runXray", xrayJSON: xrayJSON)
            self.xrayRunning = true
            Self.record(stage: "VPN 已连接")
            completionHandler(nil)
          } catch {
            Self.record(stage: "启动 Xray 内核", error: error)
            completionHandler(error)
          }
        }
      }
    } catch {
      Self.record(stage: "读取 VPN 配置", error: error)
      completionHandler(error)
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    worker.async { [weak self] in
      if self?.xrayRunning == true {
        try? Self.invoke(method: "stopXray")
      }
      self?.xrayRunning = false
      completionHandler()
    }
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)?
  ) {
    let response: [String: Any] = ["running": xrayRunning]
    completionHandler?(try? JSONSerialization.data(withJSONObject: response))
  }

  override func sleep(completionHandler: @escaping () -> Void) {
    completionHandler()
  }

  override func wake() {}

  private func makeNetworkSettings() -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(
      tunnelRemoteAddress: "198.18.0.1"
    )
    settings.mtu = 1400

    let ipv4 = NEIPv4Settings(
      addresses: ["198.18.0.2"],
      subnetMasks: ["255.254.0.0"]
    )
    ipv4.includedRoutes = [NEIPv4Route.default()]
    settings.ipv4Settings = ipv4

    let ipv6 = NEIPv6Settings(
      addresses: ["fd00::2"],
      networkPrefixLengths: [64]
    )
    ipv6.includedRoutes = [NEIPv6Route.default()]
    settings.ipv6Settings = ipv6

    let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
    dns.matchDomains = [""]
    settings.dnsSettings = dns
    return settings
  }

  private static func findTunnelFileDescriptor() -> Int32? {
    for descriptor in 0...1024 {
      var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
      var length = socklen_t(name.count)
      let result = getsockopt(Int32(descriptor), 2, 2, &name, &length)
      if result == 0, String(cString: name).hasPrefix("utun") {
        return Int32(descriptor)
      }
    }
    return nil
  }

  private static func invoke(method: String, xrayJSON: String? = nil) throws {
    var payload: [String: Any] = [:]
    if let xrayJSON { payload["xrayJson"] = xrayJSON }
    let request: [String: Any] = [
      "apiVersion": 3,
      "method": method,
      "payload": payload,
    ]
    let data = try JSONSerialization.data(withJSONObject: request)
    guard let requestJSON = String(data: data, encoding: .utf8),
          let requestPointer = strdup(requestJSON)
    else { throw error("无法编码 Xray 请求") }
    defer { free(requestPointer) }

    guard let responsePointer = CGoInvoke(requestPointer) else {
      throw error("Xray 内核没有返回结果")
    }
    defer { CGoFree(responsePointer) }

    let responseText = String(cString: responsePointer)
    guard let responseData = responseText.data(using: .utf8),
          let response = try JSONSerialization.jsonObject(with: responseData)
            as? [String: Any]
    else { throw error("Xray 内核返回格式无效") }
    guard response["success"] as? Bool == true else {
      let message = response["error"] as? String ?? "Xray 内核启动失败"
      throw error(message)
    }
  }

  fileprivate static func error(_ message: String) -> NSError {
    NSError(
      domain: "com.speednetwork.iplookupapp.PacketTunnel",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }

  private static func record(stage: String, error: Error? = nil) {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
      return
    }
    defaults.set(stage, forKey: lastStageKey)
    if let error {
      defaults.set("\(stage)：\(error.localizedDescription)", forKey: lastErrorKey)
    } else if stage == "正在读取 VPN 配置" || stage == "VPN 已连接" {
      defaults.removeObject(forKey: lastErrorKey)
    }
  }
}

private struct TunnelConfiguration {
  let address: String
  let port: Int
  let userID: String
  let encryption: String
  let flow: String
  let serverName: String
  let publicKey: String
  let shortID: String
  let fingerprint: String
  let spiderX: String

  init(protocolConfiguration: NEVPNProtocol) throws {
    guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
          let values = tunnelProtocol.providerConfiguration,
          values["schema_version"] as? Int == 1,
          values["protocol"] as? String == "vless",
          values["transport"] as? String == "raw",
          values["security"] as? String == "reality",
          let address = values["address"] as? String,
          !address.isEmpty,
          let port = values["port"] as? Int,
          (1...65535).contains(port),
          let userID = values["user_id"] as? String,
          !userID.isEmpty,
          let serverName = values["server_name"] as? String,
          !serverName.isEmpty,
          let publicKey = values["public_key"] as? String,
          !publicKey.isEmpty
    else {
      throw PacketTunnelProvider.error("VPN 配置缺失或版本不受支持")
    }
    self.address = address
    self.port = port
    self.userID = userID
    encryption = values["encryption"] as? String ?? "none"
    flow = values["flow"] as? String ?? ""
    self.serverName = serverName
    self.publicKey = publicKey
    shortID = values["short_id"] as? String ?? ""
    fingerprint = values["fingerprint"] as? String ?? "chrome"
    spiderX = values["spider_x"] as? String ?? "/"
  }

  func makeXrayJSON(tunnelFileDescriptor: Int32) throws -> String {
    let configuration: [String: Any] = [
      "log": ["loglevel": "warning"],
      "env": ["xray.tun.fd": String(tunnelFileDescriptor)],
      "dns": [
        "servers": ["1.1.1.1", "8.8.8.8"],
        "queryStrategy": "UseIP",
      ],
      "inbounds": [[
        "tag": "tun-in",
        "protocol": "tun",
        "settings": [
          "mtu": 1400,
          "gateway": ["198.18.0.1/15", "fd00::1/64"],
          "dns": ["1.1.1.1", "8.8.8.8"],
          "userLevel": 0,
        ],
        "sniffing": [
          "enabled": true,
          "destOverride": ["http", "tls", "quic"],
        ],
      ]],
      "outbounds": [
        [
          "tag": "proxy",
          "protocol": "vless",
          "settings": [
            "address": address,
            "port": port,
            "id": userID,
            "encryption": encryption,
            "flow": flow,
            "packetEncoding": "xudp",
          ],
          "streamSettings": [
            "network": "raw",
            "security": "reality",
            "realitySettings": [
              "serverName": serverName,
              "fingerprint": fingerprint,
              "password": publicKey,
              "shortId": shortID,
              "spiderX": spiderX,
            ],
          ],
        ],
        ["tag": "direct", "protocol": "freedom"],
        ["tag": "block", "protocol": "blackhole"],
      ],
      "routing": [
        "domainStrategy": "IPIfNonMatch",
        "rules": [[
          "type": "field",
          "inboundTag": ["tun-in"],
          "outboundTag": "proxy",
        ]],
      ],
    ]
    let data = try JSONSerialization.data(withJSONObject: configuration)
    guard let text = String(data: data, encoding: .utf8) else {
      throw PacketTunnelProvider.error("无法编码 Xray 配置")
    }
    return text
  }
}
