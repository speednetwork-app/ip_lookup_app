import Foundation

@main
struct NativeVpnConfigurationTests {
  static func main() throws {
    let base: [String: Any] = [
      "schema_version": 1, "protocol": "hysteria2", "transport": "quic", "security": "tls",
      "address": "node.example.com", "port": 443, "server_name": "tls.example.com",
      "password": "fixture-password", "allow_insecure": false, "obfs_password": "",
      "server_ports": "", "hop_interval": 5, "up_mbps": 0, "down_mbps": 0,
    ]
    var cases: [[String: Any]] = []
    for name in ["hy2", "hy2-obfs", "hy2-hop"] {
      var values = base
      if name == "hy2-obfs" { values["obfs_password"] = "fixture-obfs" }
      if name == "hy2-hop" {
        values["server_ports"] = "20000-21000"
        values["up_mbps"] = 10
        values["down_mbps"] = 100
      }
      let config = try TunnelConfiguration(values: values)
      let outbound = config.makeProxyOutbound()
      let stream = outbound["streamSettings"] as! [String: Any]
      precondition((stream["tlsSettings"] as! [String: Any])["allowInsecure"] == nil)
      precondition((stream["hysteriaSettings"] as! [String: Any])["auth"] as? String == "fixture-password")
      let json = try config.makeXrayJSON(tunnelFileDescriptor: 12)
      let full = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
      precondition((full["outbounds"] as! [[String: Any]]).count == 3)
      cases.append(["name": name, "outbound": outbound])
    }
    for key in ["password", "allow_insecure", "protocol", "server_name"] {
      var invalid = base
      invalid.removeValue(forKey: key)
      do {
        _ = try TunnelConfiguration(values: invalid)
        fatalError("Accepted missing \(key)")
      } catch { /* expected, without emitting configuration secrets */ }
    }
    var pinned = base
    pinned["allow_insecure"] = true
    do {
      _ = try TunnelConfiguration(values: pinned)
      fatalError("Accepted insecure HY2 without a trusted pin")
    } catch { /* expected */ }
    pinned["pinned_peer_cert_sha256"] = String(repeating: "a", count: 64)
    let tls = try TunnelConfiguration(values: pinned).makeProxyOutbound()["streamSettings"] as! [String: Any]
    precondition((tls["tlsSettings"] as! [String: Any])["pinnedPeerCertSha256"] as? String == String(repeating: "a", count: 64))
    var compatibility = base
    compatibility["allow_insecure"] = true
    compatibility["hy2_insecure_consent"] = true
    let compatConfig = try TunnelConfiguration(values: compatibility)
    precondition(compatConfig.usesHy2Compatibility)
    do {
      _ = try compatConfig.makeXrayJSON(tunnelFileDescriptor: 12)
      fatalError("Compatibility requires an authenticated internal bridge")
    } catch { /* expected */ }
    let compatJSON = try compatConfig.makeXrayJSON(tunnelFileDescriptor: 12,
        compatibilityEndpoint: ["port": 12345, "user": "fixture", "password": "fixture-only"])
    precondition(compatJSON.contains("socks"))
    var vless = base
    vless["protocol"] = "vless"; vless["transport"] = "raw"; vless["security"] = "reality"
    vless["user_id"] = "11111111-2222-4333-8444-555555555555"
    vless["public_key"] = String(repeating: "A", count: 43)
    cases.append(["name": "vless", "outbound": try TunnelConfiguration(values: vless).makeProxyOutbound()])
    let output = try JSONSerialization.data(withJSONObject: cases)
    FileHandle.standardOutput.write(output)
  }
}
