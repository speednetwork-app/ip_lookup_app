import Foundation

/// Strict, typed configuration only. No executable code or arbitrary Xray JSON
/// can be supplied by the server. Kept Foundation-only for native regression tests.
struct TunnelConfiguration {
  private let values: [String: Any]
  private let isHy2: Bool
  private let address: String
  private let port: Int
  private let serverName: String

  init(values: [String: Any]) throws {
    guard values["schema_version"] as? Int == 1,
          let address = values["address"] as? String, !address.isEmpty,
          let port = values["port"] as? Int, (1...65535).contains(port),
          let serverName = values["server_name"] as? String, !serverName.isEmpty else {
      throw Self.invalid()
    }
    switch values["protocol"] as? String {
    case "vless":
      guard values["transport"] as? String == "raw",
            values["security"] as? String == "reality",
            let id = values["user_id"] as? String, !id.isEmpty,
            let key = values["public_key"] as? String, !key.isEmpty else {
        throw Self.invalid()
      }
      isHy2 = false
    case "hysteria2":
      guard values["transport"] as? String == "quic",
            values["security"] as? String == "tls",
            let password = values["password"] as? String, !password.isEmpty,
            values["allow_insecure"] is Bool else { throw Self.invalid() }
      for key in ["up_mbps", "down_mbps"] {
        guard let speed = values[key] as? Int, (0...1_000_000).contains(speed) else {
          throw Self.invalid()
        }
      }
      guard let interval = values["hop_interval"] as? Int,
            (5...3600).contains(interval),
            let ports = values["server_ports"] as? String,
            let _ = values["obfs_password"] as? String else { throw Self.invalid() }
      if !ports.isEmpty {
        let parts = ports.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let low = Int(parts[0]), let high = Int(parts[1]),
              low >= 1, high <= 65535, low <= high else { throw Self.invalid() }
      }
      isHy2 = true
    default: throw Self.invalid()
    }
    self.values = values
    self.address = address
    self.port = port
    self.serverName = serverName
  }

  func makeProxyOutbound() -> [String: Any] {
    if !isHy2 {
      return [
        "tag": "proxy", "protocol": "vless",
        "settings": [
          "address": address, "port": port,
          "id": values["user_id"] as? String ?? "",
          "encryption": values["encryption"] as? String ?? "none",
          "flow": values["flow"] as? String ?? "", "packetEncoding": "xudp",
        ],
        "streamSettings": [
          "network": "raw", "security": "reality",
          "realitySettings": [
            "serverName": serverName,
            "fingerprint": values["fingerprint"] as? String ?? "chrome",
            "password": values["public_key"] as? String ?? "",
            "shortId": values["short_id"] as? String ?? "",
            "spiderX": values["spider_x"] as? String ?? "/",
          ],
        ],
      ]
    }
    var masks: [[String: Any]] = []
    if let ports = values["server_ports"] as? String, !ports.isEmpty {
      masks.append(["type": "udphop", "settings": [
        "mode": "intervalRemote", "remotePorts": ports,
        "interval": values["hop_interval"] as? Int ?? 30,
      ]])
    }
    if let password = values["obfs_password"] as? String, !password.isEmpty {
      masks.append(["type": "salamander", "settings": ["password": password]])
    }
    var quic: [String: Any] = [
      "congestion": "bbr", "keepAlivePeriod": 10,
      // Standards-compliant HY2, without the optional Chrome-QUIC camouflage.
      "disableChromeParrot": true,
    ]
    let up = values["up_mbps"] as? Int ?? 0
    let down = values["down_mbps"] as? Int ?? 0
    if up > 0 && down > 0 {
      quic["congestion"] = "brutal"
      quic["brutalUp"] = "\(up)mbps"
      quic["brutalDown"] = "\(down)mbps"
    }
    return [
      "tag": "proxy", "protocol": "hysteria",
      "settings": ["version": 2, "address": address, "port": port],
      "streamSettings": [
        "network": "hysteria", "security": "tls",
        "tlsSettings": [
          "serverName": serverName, "alpn": ["h3"],
          // Never infer insecure mode from a missing setting.
          "allowInsecure": values["allow_insecure"] as? Bool ?? false,
        ],
        "hysteriaSettings": ["version": 2, "auth": values["password"] as? String ?? ""],
        "finalmask": ["udp": masks, "quicParams": quic],
      ],
    ]
  }

  func makeXrayJSON(tunnelFileDescriptor: Int32) throws -> String {
    let configuration: [String: Any] = [
      "log": ["loglevel": "warning"],
      "env": ["xray.tun.fd": String(tunnelFileDescriptor)],
      "dns": ["servers": ["1.1.1.1", "8.8.8.8"], "queryStrategy": "UseIP"],
      "inbounds": [[
        "tag": "tun-in", "protocol": "tun",
        "settings": ["mtu": 1400, "gateway": ["198.18.0.1/15", "fd00::1/64"],
                     "dns": ["1.1.1.1", "8.8.8.8"], "userLevel": 0],
        "sniffing": ["enabled": true, "destOverride": ["http", "tls", "quic"]],
      ]],
      "outbounds": [makeProxyOutbound(), ["tag": "direct", "protocol": "freedom"],
                    ["tag": "block", "protocol": "blackhole"]],
      "routing": ["domainStrategy": "IPIfNonMatch", "rules": [[
        "type": "field", "inboundTag": ["tun-in"], "outboundTag": "proxy",
      ]]],
    ]
    return String(decoding: try JSONSerialization.data(withJSONObject: configuration), as: UTF8.self)
  }

  private static func invalid() -> NSError {
    NSError(domain: "com.speednetwork.iplookupapp.PacketTunnel", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "VPN 配置缺失或版本不受支持"])
  }
}
