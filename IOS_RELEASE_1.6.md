# iOS 1.6.0 (Build 14) Submission Notes

## Purpose of this build

This build addresses the App Review feedback for Guideline 2.5.19 by making the VPN capability explicit to both users and App Review.

## App Store metadata

### Promotional text

查询公网 IP 与近似归属地，登录后可选择线路并开启 VPN 安全连接，同时查看套餐、流量与连接状态。

### What's New

新增首次连接前的 VPN 功能与数据路径说明；优化安全连接状态、线路选择和错误提示；提升网络检测与页面稳定性。

### Description addition

登录用户可在首页使用“VPN 安全连接”：选择可用线路后主动开启连接，iOS 会提示添加 VPN 配置。连接期间，设备网络流量会通过用户选择的线路传输；用户可随时使用同一开关断开。应用不会读取设备 GPS，页面显示的位置来自公网 IP 的近似归属地。

## App Review notes

Hello App Review Team,

This build intentionally includes a user-facing VPN secure connection feature. It is not hidden, dormant, or remotely activated.

The feature uses Apple's public NetworkExtension APIs through `NETunnelProviderManager` and the bundled `PacketTunnelProvider` extension. LibXray and the VLESS transport implementation are compiled into the submitted binary. The app does not download or execute additional code after review; the server only returns account and node configuration data.

Review steps:

1. Sign in with the review account provided in App Review Information.
2. On the Home tab, locate the clearly labeled “VPN 安全连接” section directly below the public IP card.
3. Tap “选择连接线路” and select an available VLESS line.
4. Turn on the “VPN 安全连接” switch.
5. Review the first-connection disclosure explaining that device network traffic will pass through the selected line and that iOS will request permission to add a VPN configuration.
6. Tap “同意并连接”, then allow the iOS VPN configuration prompt.
7. The Home screen displays the live connection status and selected line. Use the same switch to disconnect at any time.

No VPN functionality is concealed behind a remote flag. The App Store description, What's New text, screenshots, and these review notes explicitly disclose the feature. The app is not distributed in mainland China or France.

## Submission checklist

- Select build 14 for App Store version 1.6.0.
- Keep the review account active and confirm it has an available plan and at least one online VLESS line.
- Upload a screenshot showing the Home screen “VPN 安全连接” switch and selected line.
- Confirm App Privacy answers cover account data, identifiers, diagnostics, and network data used to provide the service.
- Confirm availability still excludes mainland China and France.
- Do not submit until a TestFlight device test confirms connect, public-IP change, disconnect, relaunch status, and first-connection disclosure.
