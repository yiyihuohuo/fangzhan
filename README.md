# 社工防站 (shegongfangzhan)

一个基于Flutter开发的内网穿透工具，集成了FRP（Fast Reverse Proxy）功能，支持HTTP、HTTPS、TCP等多种协议的内网穿透服务。

## 📱 项目简介

社工防站是一个功能强大的移动端内网穿透应用，旨在帮助用户轻松地将本地服务暴露到公网，支持多种隧道类型和灵活的配置管理。

### 🌟 主要特性

- **多协议支持**: 支持HTTP、HTTPS、TCP、UDP等多种协议
- **隧道管理**: 完整的隧道创建、编辑、删除和状态监控
- **实时通知**: 集成本地通知服务，实时反馈隧道状态
- **配置管理**: 灵活的服务器配置和隧道参数设置
- **状态监控**: 实时显示隧道连接状态和流量信息
- **本地测试**: 内置示例网站用于测试隧道功能
- **数据持久化**: 使用SQLite本地存储配置和历史记录

## 🏗️ 项目结构

```
lib/
├── main.dart                    # 应用入口
├── providers/                   # 状态管理
│   ├── tunnel_provider.dart    # 隧道状态管理
│   └── settings_provider.dart  # 设置状态管理
├── screens/                     # 界面页面
│   ├── home_screen.dart        # 主页面
│   ├── tunnel_management_screen.dart  # 隧道管理页面
│   ├── settings_screen.dart    # 设置页面
│   └── tunnel_detail_screen.dart      # 隧道详情页面
├── services/                    # 核心服务
│   ├── frp_service.dart        # FRP服务核心
│   ├── notification_service.dart      # 通知服务
│   ├── database_service.dart   # 数据库服务
│   └── file_service.dart       # 文件管理服务
└── theme/                       # 主题配置
    └── app_theme.dart          # 应用主题

assets/
├── ngrok/                      # Ngrok相关资源
├── sample_site/                # 示例网站文件
│   ├── index.html             # 测试页面
│   ├── style.css              # 样式文件
│   └── script.js              # 脚本文件
└── frpc_native/               # FRP客户端原生文件

android/                        # Android平台配置
├── app/
│   └── src/main/AndroidManifest.xml  # Android权限配置
└── frpc_native/               # 原生FRP客户端
```

## 🚀 功能模块

### 1. 隧道管理
- **创建隧道**: 支持多种协议类型的隧道创建
- **编辑配置**: 灵活修改隧道参数
- **状态监控**: 实时显示隧道连接状态
- **批量操作**: 支持批量启动/停止隧道

### 2. 服务器配置
- **多服务器支持**: 管理多个FRP服务器配置
- **连接测试**: 验证服务器连接状态
- **配置导入/导出**: 支持配置文件的导入导出

### 3. 通知系统
- **状态通知**: 隧道状态变化实时通知
- **错误提醒**: 连接异常及时提醒
- **后台运行**: 支持后台状态监控

### 4. 本地测试
- **示例网站**: 内置测试网站用于验证隧道功能
- **端口检测**: 自动检测可用端口
- **连接验证**: 一键测试隧道连通性

## 📦 依赖包

主要使用的Flutter包：

```yaml
dependencies:
  flutter: sdk: flutter
  provider: ^6.1.2              # 状态管理
  sqflite: ^2.3.3              # 本地数据库
  shared_preferences: ^2.2.3    # 本地存储
  flutter_local_notifications: ^17.2.2  # 本地通知
  path_provider: ^2.1.3         # 路径管理
  file_picker: ^8.1.2           # 文件选择
  url_launcher: ^6.3.0          # URL启动
  webview_flutter: ^4.8.0       # WebView组件
```

## 🛠️ 开发环境

- **Flutter**: 3.0+
- **Dart**: 3.0+
- **Android**: API 21+ (Android 5.0+)
- **iOS**: iOS 12.0+

## 📱 安装与运行

### 1. 环境准备
```bash
# 检查Flutter环境
flutter doctor

# 获取依赖
flutter pub get
```

### 2. 运行应用
```bash
# 调试模式运行
flutter run

# 发布模式构建
flutter build apk --release
```

### 3. 原生组件编译
```bash
# 编译Android原生FRP客户端
cd android/frpc_native
./build.sh
```

## ⚙️ 配置说明

### FRP服务器配置
```json
{
  "server_addr": "your-server.com",
  "server_port": 7000,
  "token": "your-token",
  "user": "your-username"
}
```

### 隧道配置示例
```json
{
  "name": "web-tunnel",
  "type": "http",
  "local_ip": "127.0.0.1",
  "local_port": 8080,
  "custom_domains": ["your-domain.com"],
  "subdomain": "test"
}
```

## 🔧 权限说明

应用需要以下权限：
- **网络访问**: 用于建立隧道连接
- **存储权限**: 用于保存配置文件
- **通知权限**: 用于状态通知
- **前台服务**: 用于后台运行隧道服务

## 📋 使用指南

1. **首次使用**: 配置FRP服务器信息
2. **创建隧道**: 选择协议类型，配置本地服务
3. **启动服务**: 一键启动隧道连接
4. **状态监控**: 查看连接状态和流量信息
5. **测试验证**: 使用内置测试工具验证连通性

## 🐛 常见问题

### Q: 隧道连接失败？
A: 检查服务器配置和网络连接，确认防火墙设置。

### Q: 通知不显示？
A: 检查应用通知权限，确保已开启通知功能。

### Q: 后台运行异常？
A: 检查电池优化设置，将应用加入白名单。

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进项目：

1. Fork项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建Pull Request

## 📄 许可证

本项目采用MIT许可证 - 查看[LICENSE](LICENSE)文件了解详情。

## 📞 联系方式

如有问题或建议，请通过以下方式联系：
- 提交Issue
- 发送邮件
- 加入讨论群

---

**注意**: 请确保遵守相关法律法规，合理使用内网穿透功能。