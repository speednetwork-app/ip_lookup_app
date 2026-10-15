# iOS 1.2 发布清单

## 构建信息

- App 版本：`1.2.0`
- 构建号：`7`
- 新增能力：已有账号的只读账号概览、流量进度、有效期和使用限制
- 保留能力：免登录 IP 查询、默认隐藏的订阅地址
- 未包含：注册、购买、充值、价格、节点列表、第三方客户端跳转、VPN 配置或 VPN 连接

## 上传前验证

1. `GET /api/v1/user/mobile-overview` 仅返回移动端白名单字段。
2. 审核账号无需验证码或双重验证，并在审核期间保持有效。
3. 海外网络可访问登录和账号概览接口。
4. IP 查询无需登录，登录页仅面向已有账号。
5. 订阅地址默认隐藏，不在商店截图中展示。
6. App Store 隐私信息与邮箱、用户 ID、账号概览数据的实际处理方式一致。
7. 隐私政策 URL 已部署本次更新后的 `docs/privacy.html`。

## 此版本的新增内容

> 新增只读账号概览。登录已有账号后，可查看账号状态、流量使用情况、有效期、重置时间及使用限制；同时优化下拉刷新和异常提示。

## 产品描述补充

> 除免登录的 IP 查询功能外，已有账号用户可选择登录，查看账号状态、流量使用情况、有效期和使用限制。本 App 不提供账号注册、套餐购买或充值功能。

## App Review Notes

```text
Version 1.2.0 adds a read-only account overview for existing users.

The primary IP lookup features remain available without signing in. Signing in is optional and is only required to view an existing account's plan status, traffic usage, expiration date, reset date, device limit, and speed limit.

The app does not provide:
- account registration
- purchases, renewals, or external purchase links
- VPN connection functionality
- Network Extension or NEVPNManager functionality
- server or node selection

The existing subscription address is treated as a confidential account credential. It is masked by default and is only revealed after an explicit user action.

Review steps:
1. Open the “我的” tab.
2. Enter the review account credentials provided in App Store Connect.
3. Tap “登录”.
4. View the read-only account overview.
5. Pull down to refresh the account information.

The review account does not require two-factor authentication, CAPTCHA, or additional verification.
```

## 发布前命令

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release
```
