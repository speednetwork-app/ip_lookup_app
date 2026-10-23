# iOS 1.5.0（Build 10）开发说明

## 本阶段已完成

- 底部导航调整为：首页、线路、IP 检测、历史、我的。
- 登录后从现有 `/api/v1/user/server/fetch` 接口读取线路摘要。
- 展示线路名称、协议、在线状态、负载和倍率，并支持选择在线线路。
- 增加连接状态卡、首次连接前的数据用途说明和 iOS 原生桥接边界。
- 隐私页补充安全连接的数据处理说明。
- 未登录用户仍可独立使用 IP 检测。

## 当前连接限制

本阶段不会伪造 VPN 连接。服务器当前同时存在多种代理协议，而现有接口只返回线路摘要，尚未提供 App 专用的短期连接配置。Flutter 已通过 MethodChannel 预留原生连接入口；缺少已签名的 Packet Tunnel Extension 时，会明确提示“当前安装包尚未包含系统连接组件”。

## 下一阶段上线前必须完成

1. 后端新增 App 专用配置接口，只向已登录且套餐有效的用户返回选中线路的最小连接配置，配置需短期有效且可撤销。
2. 确定首发唯一协议及实现核心，并完成许可证复核。
3. 在 Xcode 中新增 Packet Tunnel Extension、Network Extension entitlement、App Group 和 Keychain Sharing。
4. 主 App 与 Extension 使用独立 Bundle ID 和描述文件，更新 CI 双 Target 签名。
5. 真机验证连接、断开、切网重连、锁屏恢复、流量统计、退出登录清理配置。
6. 先通过 TestFlight 内部测试，不将本阶段的未完成连接入口提交公开审核。
