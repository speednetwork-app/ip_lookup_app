# IP 查询 App - iOS 上架指南

## 项目信息

- **应用名称**：IP 查询
- **Bundle ID**：`com.speednetwork.ip_lookup_app`
- **最低 iOS 版本**：12.0+
- **开发环境**：Flutter 3.24.0

---

## 🔧 iOS 本地开发配置

### 1. 打开 iOS 项目

```bash
cd ios
open Runner.xcworkspace
```

**重要**：始终使用 `.xcworkspace`，不要用 `.xcodeproj`

### 2. 配置 Bundle ID 和签名

在 Xcode 中：
1. 选择 Runner 项目 → Target "Runner"
2. **General** 标签：
   - Bundle Identifier: `com.speednetwork.ip_lookup_app`
   - Minimum Deployment: iOS 12.0
3. **Signing & Capabilities** 标签：
   - Team: 选择你的 Apple Developer 账号
   - Signing Certificate: 选择有效的证书

---

## 📱 App Store 上架流程

### 步骤 1: 获取开发证书和配置文件

1. 登录 [Apple Developer](https://developer.apple.com)
2. 进入 **Certificates, Identifiers & Profiles**
3. 创建 App ID：`com.speednetwork.ip_lookup_app`
4. 创建 iOS Distribution Certificate（发布证书）
5. 创建 Provisioning Profile（发布配置文件）
6. 下载并导入到钥匙链

### 步骤 2: 在 App Store Connect 中创建应用

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 点击 **我的 App** → **新建 App**
3. 填写信息：
   - 名称：**IP 查询**
   - Bundle ID：`com.speednetwork.ip_lookup_app`
   - SKU：任意（如 `ip_lookup_001`）
   - 平台：iOS

### 步骤 3: 填写应用信息

#### 应用描述
```
简单快速的 IP 地址查询工具。

功能：
• 显示你的公网 IP 地址
• 查询任意 IP 的地理位置
• 显示国家、城市、ISP 等信息

完全离线工作，不收集任何个人数据。
```

#### 分类
- **主要分类**：工具
- **副分类**：（可选）

#### 隐私政策
创建隐私政策页面，内容参考下方模板

#### 应用截图（至少 5 张）

需要 5 张不同设备的截图：
1. iPhone 14 Pro (6.1")：首页显示本机 IP
2. iPhone 14 Pro (6.1")：输入 IP 查询
3. iPhone 14 Pro (6.1")：查询结果页面
4. iPhone 14 Pro (6.1")：显示地理位置信息
5. iPhone 14 Pro (6.1")：多个查询历史

**推荐**：用模拟器运行应用，使用 Xcode 的截图功能

#### 预览视频（可选）
10-30 秒的应用演示视频

### 步骤 4: 编译和上传

#### 本地编译并上传

```bash
# 清理之前的构建
flutter clean

# 获取依赖
flutter pub get

# 构建 iOS 应用
flutter build ios --release

# 打开 Xcode 进行最终签名和上传
cd ios
open Runner.xcworkspace
```

在 Xcode 中：
1. 选择 **Product** → **Archive**
2. 等待编译完成
3. 点击 **Distribute App** → **App Store Connect**
4. 选择签名证书并上传

#### 使用 GitHub Actions 自动编译（推荐）

1. 推送代码到 GitHub
2. GitHub Actions 自动编译
3. 下载构建产物
4. 在本地用 Xcode 完成代码签名和上传

### 步骤 5: 等待审核

- App Store 审核通常需要 1-3 天
- 可能需要提供额外信息或修改应用
- 审核通过后应用自动上架

---

## 🔐 隐私政策模板

创建一个 `privacy-policy.md` 文件（后续上传到网络）：

```markdown
# IP 查询应用 - 隐私政策

## 数据收集

本应用收集以下信息：
- 用户设备的公网 IP 地址（仅用于显示）
- 用户手动输入的 IP 地址（用于查询）

## 数据使用

所有数据仅用于：
- 查询 IP 的地理位置信息
- 显示查询结果

## 数据存储

- 本应用不在本地存储任何数据
- 所有数据在应用关闭后立即删除
- 数据不会上传到我们的服务器

## 第三方服务

本应用使用第三方 IP 数据库服务：
- ip-api.com

请查看其隐私政策：https://ip-api.com/

## 用户权利

用户可以随时：
- 停止使用应用
- 卸载应用删除所有数据

## 联系方式

如有隐私问题，请联系：
[你的邮箱]

更新日期：2026年9月
```

---

## 🐛 常见问题

### 问：如何修改应用图标？

在 `ios/Runner/Assets.xcassets/AppIcon.appiconset/` 中替换图片

### 问：构建失败怎么办？

```bash
# 清理缓存
flutter clean

# 重新构建
flutter pub get
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter build ios --release
```

### 问：如何本地测试 iOS 应用？

```bash
# 用模拟器运行
flutter run

# 或用真实 iOS 设备
flutter run -d <device_id>
```

### 问：GitHub Actions 编译失败？

检查：
1. Flutter 版本是否正确（3.24.0）
2. CocoaPods 是否能正确解析依赖
3. 网络连接是否正常

---

## 📋 检查清单

上架前确认：

- [ ] 应用名称：IP 查询
- [ ] Bundle ID：com.speednetwork.ip_lookup_app
- [ ] 最小 iOS 版本：12.0
- [ ] 隐私政策已创建并发布
- [ ] 应用截图已准备（至少 5 张）
- [ ] 应用描述准确无误
- [ ] 无硬编码的敏感信息
- [ ] 代码签名证书有效
- [ ] 在模拟器中测试通过
- [ ] Xcode 最新版本

---

## 🚀 提交流程总结

```
1. 本地开发完成
   ↓
2. 在 App Store Connect 创建应用
   ↓
3. 上传应用信息和截图
   ↓
4. 编译 iOS 应用
   ↓
5. 用 Xcode 代码签名和上传
   ↓
6. 等待 Apple 审核
   ↓
7. 审核通过，应用上架！
```

更多帮助：[Apple 官方上架指南](https://developer.apple.com/app-store/submitting-apps/)
