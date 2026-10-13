# iOS 1.1 发布清单

## 构建信息

- App 版本：`1.1.0`
- 构建号：`5`
- 最低 iOS：12.0
- 新增能力：已有账号登录、查看和复制订阅地址
- 未包含：注册、购买、充值、第三方客户端跳转、VPN 配置或 VPN 连接

## 上传前必须完成

1. 将 `docs/privacy.html` 部署到 App Store Connect 当前填写的隐私政策 URL。
2. 在真机上使用专用审核账号验证登录、重启后保持登录、复制和退出登录。
3. 确认审核账号在整个审核期间有效，且 `/user/getSubscribe` 返回 HTTPS 地址。
4. App Store Connect 的 App 隐私信息应与服务端实际处理一致；至少重新检查邮箱地址、用户 ID、App 功能用途、是否关联身份及是否用于跟踪。
5. 更新产品描述和截图，明确展示“登录已有账号并查看订阅地址”，不要把它作为隐藏功能。
6. 不在 App 或元数据中加入站外购买、充值或套餐价格引导。

## “此版本的新增内容”建议

> 新增已有账号登录功能，可安全查看和复制订阅地址。IP 查询仍可免登录使用，同时改进了登录凭证保护和隐私说明。

## App 描述需要替换的版本

> IP 位置查询是一款简洁的网络工具，帮助你查询公网 IP 地址及其大致归属信息。
>
> 主要功能
>
> • 主动查询当前网络的公网 IP 地址  
> • 查询任意 IPv4 或 IPv6 地址  
> • 显示 IP 对应的大致国家、地区、城市、时区和网络运营商  
> • 使用 OpenStreetMap 展示 IP 的估算位置  
> • 在设备本地保存用户主动查询的历史记录  
> • 已有账号可选择登录，查看和复制其订阅地址  
>
> 隐私与数据说明
>
> • IP 查询无需注册或登录  
> • 账号登录为可选功能，仅支持已有账号  
> • App 不提供账号注册、套餐购买、充值或站外购买入口  
> • 密码不会保存在设备上，登录凭证保存在 iOS 钥匙串中  
> • 不申请设备 GPS 定位，不包含广告、第三方统计或用户追踪  
> • 查询历史最多保存 50 条，仅存于用户设备本地

## App 审核备注模板

> Version 1.1 adds an optional sign-in flow for existing users. IP lookup remains fully available without signing in. After authentication, an existing user can view and copy the subscription URL already associated with their account. The app does not offer account creation, purchases, recharge, pricing, or links that direct users to purchase outside the app. This build does not establish a VPN connection, install a VPN profile, or use NEVPNManager. Credentials are sent only to https://app.pikayun.com over HTTPS; the password is not stored, and the authentication token is stored in the iOS Keychain.
>
> Review steps: Open the “我的” tab, enter the review credentials below, tap “登录”, then use “显示” or “复制” in the subscription card.
>
> Review account: [填写专用审核邮箱]
>
> Password: [填写专用审核密码]

## Xcode / TestFlight 验证

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release
open ios/Runner.xcworkspace
```

在 macOS/Xcode 中 Archive 上传后，先通过 TestFlight 在至少一台真机完成完整登录流程，再提交 App Review。
