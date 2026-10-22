# iOS 1.4 发布清单

## 构建信息

- App 版本：`1.4.0`
- 构建号：`9`
- 发布标签：`v1.4.0-build9`
- Bundle ID：`com.speednetwork.iplookupapp`
- Flutter：`3.47.5`
- Dart：`3.13.4`

## 本版变更

- 新增网络信息与账号概览首页。
- 优化公网 IP 检测入口、检测结果和查询历史导航。
- 登录用户可在首页查看套餐状态、流量使用和最新公告。
- 改善手机和 Web 宽屏布局。
- IP 检测仍由用户主动发起，不请求 GPS 定位权限。

## 能力边界

本版本不包含：

- VPN 连接、VPN 配置或 Network Extension
- 服务器或节点选择
- 账号注册
- 购买、续费、充值或外部购买链接
- 设备 GPS 定位权限

## 隐私与安全核对

1. IP 查询无需登录，账号功能为可选的只读功能。
2. 密码不落盘，登录 Token 仅保存在 iOS Keychain。
3. 普通本地缓存不保存完整订阅地址、Token、密码或用户 UUID。
4. 订阅地址默认隐藏，退出登录时清除账号缓存。
5. 公告内容在展示前移除 HTML、script 和 style 内容。
6. App 内提供可直接访问的隐私说明。
7. `Info.plist` 声明不使用非豁免加密，不声明未使用的隐私权限。

## App Review Notes

```text
Version 1.4.0 introduces a redesigned network and account overview home screen, clearer navigation for public IP lookup and local lookup history, responsive layouts, and a concise read-only summary for signed-in users.

The app's primary public IP lookup features remain fully available without signing in. Public IP detection only starts after the user taps the detection button. The app does not request or use the device's GPS location. The displayed location is an approximate network location returned by the IP information service.

Signing in is optional and uses the service provider's own email/password account system. Signed-in users can view read-only plan status, aggregate traffic usage, expiration information, and sanitized system announcements. Authentication credentials remain protected by the iOS Keychain, passwords are not stored, and signing out clears locally cached account data.

The app does not provide:
- account registration
- purchases, renewals, top-ups, pricing, or external purchase links
- VPN connection or VPN configuration functionality
- Network Extension or NEVPNManager functionality
- server or node selection

Review steps for the optional account area:
1. Open the "我的" tab.
2. Enter the active review account credentials provided in App Store Connect.
3. Tap "登录".
4. Return to the home tab to view the read-only plan and traffic summary.
5. Open the account tab to review traffic trends, account details, and announcements.

The review account must remain active during review and must not require CAPTCHA, two-factor authentication, or an additional verification step.
```

## 上传前验证

- [ ] 确认 App Store Connect 中审核账号仍可登录。
- [ ] 确认 App Store Connect 隐私信息与当前 App 行为一致。
- [ ] 确认年龄分级问题已按新规则回答。
- [ ] 确认隐私政策 URL 正常可访问。
- [ ] `flutter analyze` 通过。
- [ ] `flutter test` 通过。
- [ ] GitHub Actions 使用 Xcode 26 及 iOS 26 SDK 构建。
- [ ] 标签构建成功上传 App Store Connect。
