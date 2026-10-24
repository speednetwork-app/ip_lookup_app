import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private let notConfiguredError = NSError(
    domain: "com.speednetwork.iplookupapp.PacketTunnel",
    code: 1,
    userInfo: [
      NSLocalizedDescriptionKey:
        "The secure tunnel core has not been configured for this build."
    ]
  )

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    // Establish the extension and signing path before linking a protocol core.
    // Never report a connection until packets are actually being forwarded.
    completionHandler(notConfiguredError)
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)?
  ) {
    completionHandler?(nil)
  }

  override func sleep(completionHandler: @escaping () -> Void) {
    completionHandler()
  }

  override func wake() {}
}
