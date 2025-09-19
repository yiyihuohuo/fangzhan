# 荧惑社工仿站 (shegongfangzhan)

一个基于Flutter开发的综合性渗透测试工具，集成了网站克隆、数据捕获、内网穿透等功能，专为安全研究和渗透测试而设计。

## 📱 项目简介

荧惑社工仿站是一个功能全面的移动端渗透测试平台，提供网站仿制、用户数据捕获、内网穿透等核心功能，帮助安全研究人员进行合法的渗透测试和安全评估工作。

### 🌟 核心特性

#### 🎯 网站仿制功能
- **智能克隆**: 自动下载并重构目标网站的完整结构
- **资源处理**: 智能处理CSS、JS、图片等静态资源
- **链接重写**: 自动修正相对路径和绝对路径
- **代理注入**: 无缝集成数据捕获代码

#### 📊 数据捕获系统
- **全方位监控**: 捕获表单提交、网络请求、用户输入等所有交互数据
- **实时捕获**: 支持实时输入监控和表单快照
- **智能过滤**: 自动过滤无用数据，只保留有价值的信息
- **多格式支持**: 支持POST、GET、PROBE等多种数据类型分类
- **数据导出**: 支持JSON格式数据导出和分析

#### 🔗 内网穿透服务
- **FRP集成**: 内置Fast Reverse Proxy客户端
- **多协议支持**: 支持HTTP、HTTPS、TCP等多种协议
- **配置管理**: 灵活的服务器配置和隧道参数设置
- **状态监控**: 实时显示隧道连接状态和流量信息

#### 🕵️ 探针功能
- **GPS定位**: 获取目标设备地理位置信息
- **设备信息**: 收集设备硬件和系统信息
- **剪贴板监控**: 监控剪贴板内容变化
- **摄像头检测**: 检测设备摄像头权限状态

## 🏗️ 项目架构

```
lib/
├── main.dart                           # 应用入口
├── providers/                          # 状态管理
│   └── app_provider.dart              # 全局应用状态
├── screens/                            # 用户界面
│   ├── dashboard_screen.dart          # 主控制台
│   ├── site_management_screen.dart    # 仿站管理界面
│   ├── data_capture_screen.dart       # 数据捕获界面
│   ├── data_detail_screen.dart        # 数据详情查看
│   ├── config_manager_screen.dart     # 配置管理界面
│   ├── config_editor_screen.dart      # 配置编辑器
│   ├── tunneling_config_screen.dart   # 隧道配置界面
│   ├── web_test_screen.dart           # 网页测试界面
│   └── settings_screen.dart           # 系统设置
├── services/                           # 核心服务层
│   ├── site_service.dart              # 网站克隆服务
│   ├── capture_service.dart           # 数据捕获服务
│   ├── server_service.dart            # HTTP服务器
│   ├── tunnel_service.dart            # 内网穿透服务
│   ├── frp_config_service.dart        # FRP配置管理
│   ├── universal_capture_injector.dart # 通用数据捕获注入器
│   ├── database_helper.dart           # 数据库操作
│   ├── config_file_service.dart       # 配置文件管理
│   └── notification_service.dart      # 通知服务
└── theme/                              # 主题配置
    └── app_theme.dart                 # 应用主题

assets/
├── sample_site/                        # 示例网站
│   ├── index.html                     # 测试登录页面
│   └── test_capture.html              # 数据捕获测试页面
├── ngrok/                             # Ngrok原生库
│   └── android/                       # Android平台库文件
└── frp.ini                            # FRP配置模板

android/                                # Android平台配置
└── frpc_native/                       # 原生FRP客户端
```

## 🚀 功能模块详解

### 1. 网站仿制系统
- **目标分析**: 自动分析目标网站结构和资源依赖
- **内容下载**: 批量下载HTML、CSS、JS、图片等资源
- **路径重写**: 智能处理相对路径和绝对路径转换
- **代码注入**: 无缝注入数据捕获和探针代码
- **本地服务**: 提供HTTP/HTTPS本地服务器

### 2. 数据捕获引擎
- **表单监控**: 实时监控所有表单提交行为
- **输入捕获**: 捕获用户在输入框中的实时输入
- **网络拦截**: 拦截并记录所有AJAX/Fetch请求
- **点击追踪**: 记录用户的点击行为和交互路径
- **智能过滤**: 过滤系统字段和无价值数据

### 3. 内网穿透管理
- **服务器配置**: 管理多个FRP服务器配置
- **隧道创建**: 支持多种协议的隧道创建
- **状态监控**: 实时监控隧道连接状态
- **日志记录**: 详细的连接日志和错误信息

### 4. 探针系统
- **地理定位**: 获取设备GPS坐标信息
- **设备指纹**: 收集设备硬件和浏览器信息
- **权限检测**: 检测各种敏感权限状态
- **环境分析**: 分析目标网络环境信息

## 📦 技术栈

### 核心框架
- **Flutter**: 3.8+ 跨平台移动应用框架
- **Dart**: 3.0+ 编程语言
- **Provider**: 状态管理解决方案

### 主要依赖
```yaml
dependencies:
  flutter: sdk: flutter
  provider: ^6.1.2                    # 状态管理
  dio: ^5.4.0                         # HTTP客户端
  sqflite: ^2.3.0                     # 本地数据库
  webview_flutter: ^4.4.1             # WebView组件
  shared_preferences: ^2.2.2          # 本地存储
  path_provider: ^2.1.1               # 路径管理
  flutter_local_notifications: ^17.2.2 # 本地通知
  file_picker: ^10.2.0                # 文件选择器
  url_launcher: ^6.2.6                # URL启动器
  html: ^0.15.4                       # HTML解析
  crypto: ^3.0.3                      # 加密算法
  uuid: ^4.3.3                        # UUID生成
  mime: ^1.0.4                        # MIME类型处理
  basic_utils: ^5.8.2                 # 基础工具
  toml: ^0.16.0                       # TOML配置解析
```

## 🛠️ 开发环境要求

- **Flutter SDK**: 3.8.0 或更高版本
- **Dart SDK**: 3.0.0 或更高版本
- **Android Studio**: 2022.1 或更高版本
- **Android API**: 21+ (Android 5.0+)
- **iOS**: 12.0+ (如需iOS支持)

## 📱 安装与部署

### 1. 环境准备
```bash
# 检查Flutter环境
flutter doctor

# 克隆项目
git clone <repository-url>
cd shegongfangzhan

# 安装依赖
flutter pub get
```

### 2. 编译运行
```bash
# 调试模式运行
flutter run

# 发布版本构建
flutter build apk --release

# 生成签名APK
flutter build apk --release --split-per-abi
```

### 3. 原生组件配置
```bash
# 配置Android原生FRP客户端
cd android/frpc_native
# 根据需要配置原生库文件
```

## ⚙️ 配置说明

### FRP服务器配置
```toml
[common]
server_addr = "your-server.com"
server_port = 7000
token = "your-token"
user = "your-username"

[web]
type = "http"
local_ip = "127.0.0.1"
local_port = 8080
custom_domains = ["your-domain.com"]
```

### 数据捕获配置
- **捕获类型**: POST、GET、PROBE
- **过滤规则**: 自动过滤系统字段和无用数据
- **存储格式**: JSON格式本地存储
- **导出功能**: 支持数据导出和分析

## 🔒 安全特性

- **数据加密**: 敏感数据本地加密存储
- **权限控制**: 严格的权限申请和使用控制
- **日志记录**: 详细的操作日志和审计跟踪
- **安全通信**: 支持HTTPS和加密隧道

## 📋 使用指南

### 基础使用流程
1. **配置服务器**: 设置FRP服务器连接信息
2. **创建仿站**: 输入目标URL，自动克隆网站
3. **启动服务**: 启动本地HTTP服务器
4. **配置隧道**: 创建内网穿透隧道
5. **监控数据**: 实时查看捕获的用户数据
6. **分析结果**: 导出和分析收集的数据

### 高级功能
- **批量仿站**: 支持批量克隆多个网站
- **自定义探针**: 配置特定的数据收集规则
- **数据过滤**: 设置智能数据过滤规则
- **实时监控**: 实时监控目标用户行为

## ⚠️ 法律声明

**重要提醒**: 本工具仅供合法的安全研究和渗透测试使用。使用者必须：

1. **获得授权**: 仅在获得明确书面授权的系统上使用
2. **遵守法律**: 严格遵守当地法律法规
3. **负责任使用**: 不得用于非法活动或恶意攻击
4. **保护隐私**: 妥善处理和保护收集的数据
5. **教育目的**: 优先用于安全教育和防护改进

使用本工具即表示您同意承担相应的法律责任。开发者不对任何滥用行为承担责任。

## 🐛 常见问题

### Q: 网站克隆失败？
A: 检查目标网站的反爬虫机制，尝试调整请求头和访问频率。

### Q: 数据捕获不完整？
A: 确认JavaScript注入是否成功，检查目标网站的CSP策略。

### Q: 隧道连接失败？
A: 验证FRP服务器配置，检查网络连接和防火墙设置。

### Q: 应用崩溃或异常？
A: 查看日志文件，检查设备权限和存储空间。

## 🤝 贡献指南

欢迎安全研究人员和开发者贡献代码：

1. Fork项目仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

- **Issues**: 通过GitHub Issues报告问题
- **讨论**: 参与GitHub Discussions
- **安全问题**: 请通过私有渠道报告安全漏洞

---

**免责声明**: 本工具仅用于合法的安全测试目的。使用者需自行承担使用风险和法律责任。请在使用前仔细阅读相关法律法规，确保合规使用。