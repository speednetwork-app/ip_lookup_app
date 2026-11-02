# 邮箱注册接入与上架前检查

核对时间：2026-11-02。仅只读核对服务器源码与公开配置，未修改服务器或数据库。

## 已有后端契约

- GET `/api/v1/guest/comm/config`：注册验证配置、邮箱后缀白名单。
- GET `/api/v1/guest/comm/simpleCaptcha`：题目、一次性 token、有效期。
- POST `/api/v1/passport/auth/register`：`email`、`password`（至少 8 位）；按配置提交 `simple_captcha_token`、`simple_captcha_answer`、`email_code`、`invite_code`。成功返回 `data.auth_data`。
- POST `/api/v1/passport/comm/sendEmailVerify`：邮箱及当前安全验证；后端邮件验证码有效期 300 秒，发送间隔 60 秒。
- 注册成功复用原安全会话存储与账号概览刷新，不自动购买或开通套餐。

实际配置：算术验证开启，强制邮箱验证码关闭，强制邀请码关闭，启用了邮箱后缀白名单。界面以实时配置为准。未实现的外部人机验证类型会阻止提交，不降级绕过。

## 必须处理的服务端风险（本轮未改动）

1. `app/Http/Controllers/V1/Passport/CommController.php` 的 `sendEmailVerify` 存在旧调试日志：把验证码、邮件配置（包括 SMTP 密码）写入 `xcxlog.txt`。正式使用邮件发送前，先备份、删除敏感日志写入代码，核查该文件是否在公开目录，按实际暴露情况轮换 SMTP 凭据。检查邮件任务失败日志是否也携带敏感内容。不要把日志原文复制到工单或代码库。
2. 注册目前不验证邮箱所有权。修复上项并确认邮件投递可用后，建议由管理员启用邮箱验证码；App 已支持该配置，不需要绕过或另造验证码。
3. 当前 V1 用户路由未找到注销/账户删除 API。提供注册的 App 上架前必须支持从 App 发起真实账户删除，不能用退出登录或仅停用替代。需要另行确定余额/套餐、法定保留数据、会话撤销与防误删规则，再实施服务端和客户端。不要直接在生产数据库试删。
4. 邮件接口可读到按邮箱的 60 秒发送限制；还需确认网关/IP 级限流、防批量发信和注册滥用策略，无需为接入 App 关闭现有限制。
5. 仓库内隐私说明已更新；上线前还需同步实际托管的隐私政策与 App Store Connect 的数据收集披露。本轮没有部署这些外部内容。

Apple 说明：<https://developer.apple.com/support/offering-account-deletion-in-your-app/>

## 验证边界

自动化使用隔离响应，不向真实邮箱发信、不创建生产用户。公开配置与验证码接口可做联通检查。真实注册、发信及 iOS 真机字体仍需使用用户控制的邮箱在设备上验收。

## 字体

统一语义字号、字重与行高；iOS/macOS 使用 Flutter 的 `CupertinoSystemText` / `CupertinoSystemDisplay` 系统字体代理，中文回退苹方。非苹果平台保留平台无衬线回退，不打包或分发苹果字体。所有字号仍跟随系统文字缩放；Windows 浏览器预览不等于 iPhone 的真实字体渲染。
