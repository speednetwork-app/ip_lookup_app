# iOS 1.3 发布清单

## 构建信息

- App 版本：`1.3.0`
- 构建号：`8`
- 新增能力：7 天/30 天流量趋势、上传/下载拆分、用量洞察、系统公告、状态提醒、只读账号信息安全缓存
- 保留能力：免登录 IP 查询、账号概览、默认隐藏的订阅地址
- 未包含：注册、购买、充值、价格、节点列表、第三方客户端跳转、VPN 配置或 VPN 连接

## 上传前验证

1. `GET /api/v1/user/mobile-traffic?range=7d|30d` 仅返回当前用户的按日流量白名单字段。
2. 非法范围返回 `422`，未登录请求返回 `403`，接口启用限流和 60 秒服务端缓存。
3. 本地普通缓存不包含订阅地址、密码、登录 Token 或用户 UUID；退出登录时清除。
4. 登录凭证仍仅存储在 iOS 钥匙串，密码不落盘。
5. 审核账号无需验证码或双重验证，并在审核期间保持有效。
6. IP 查询仍无需登录，App 内没有注册、购买、充值或外部购买入口。
7. App Store 隐私信息和隐私政策已覆盖只读流量趋势与本地缓存。

## 此版本的新增内容

> 新增 7 天和 30 天流量趋势，可查看上传/下载拆分、期间用量、日均用量、峰值日期和近期变化；新增系统公告、剩余用量估算、流量不足、即将到期及账号异常提醒，并优化弱网环境下的账号信息展示。

## App Review Notes

```text
Version 1.3.0 adds read-only 7-day and 30-day traffic usage trends for existing users, upload/download breakdowns, usage insights, system announcements, account status alerts, and an on-device display cache for previously fetched account summaries.

The primary IP lookup features remain fully available without signing in. Signing in is optional. The traffic chart contains only the signed-in user's aggregated daily upload/download usage. It does not expose server, node, UUID, pricing, payment, or raw authentication data.

The app does not provide:
- account registration
- purchases, renewals, or external purchase links
- VPN connection functionality
- Network Extension or NEVPNManager functionality
- server or node selection

The existing subscription address remains masked by default and is never written to the ordinary account display cache. Authentication credentials remain protected by the iOS Keychain. Signing out clears locally stored account data.

Review steps:
1. Open the “我的” tab.
2. Enter the review account credentials provided in App Store Connect.
3. Tap “登录”.
4. Scroll to “流量趋势”.
5. Switch between “7天” and “30天”.
6. Pull down to refresh the account information.

The review account does not require two-factor authentication, CAPTCHA, or additional verification.
```

## 发布前命令

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release
```
