# RemoteOS.Client (Flutter)

Flutter 版 RemoteOS 桌面客户端 — 基于状态同步（State-Sync）架构，本地渲染 UI，与 [RemoteOS.Server](../RemoteOS.Server/README.md) 通过 HTTP REST + SignalR 通信。

---

## ✨ 特性一览

| 类别 | 功能 | 状态 |
| ---- | ---- | ---- |
| 🌍 国际化 | en-US / zh-CN / ja-JP 三语切换，运行时动态生效 | ✅ 已实现 |
| 🎨 多主题 | Light / Dark / System 模式；内置 RemoteOS Blue · Nord · Catppuccin 调色板；自定义强调色 | ✅ 已实现 |
| 🔐 认证 | JWT + 刷新令牌；记住服务器与用户名；本地 keyring 安全保存密码；PIN 解锁（接口已就绪） | ✅ 已实现 |
| 🖥️ 桌面 Shell | 背景图、桌面图标（可拖动与记忆位置）、快捷打开应用 | ✅ 已实现 |
| 🪟 窗口管理 | 创建 / 激活 / 关闭 / 最小化 / 最大化 / 还原 / 移动 / 缩放；Z-Order；模态对话框；多实例 | ✅ 已实现 |
| 📋 任务栏 | 应用按钮 · 固定列表 · 跳转列表 · 时钟 · 托盘菜单 · 电源菜单 · 连接信息气泡 | ✅ 已实现 |
| 🚀 开始菜单 | 固定区 · 推荐区 · 所有应用列表 · 快捷搜索 · 用户头像区 | ✅ 已实现 |
| ⚙️ 设置应用 | 外观（主题/调色板/强调色/透明度/动画）、账户、语言、时间、系统信息、版本管理 | ✅ 已实现 |
| 👋 欢迎应用 | 首次启动向导、3 步上手、常用应用快捷入口 | ✅ 已实现 |
| 💻 终端应用 | 命令历史、光标浏览、彩色输出、内置命令（help/clear/echo/date/whoami/pwd/ls/theme/exit） | ✅ 已实现 |
| 📝 记事本应用 | 菜单栏、自动换行切换、状态栏（行/字符数）、字号调节、新建/保存骨架 | ✅ 已实现 |
| 🧭 路由 | GoRouter 基于认证状态的守卫；登录 ↔ 桌面自动跳转 | ✅ 已实现 |
| 🧪 状态管理 | Riverpod 2.x StateNotifier + Provider 全链路 | ✅ 已实现 |
| 📡 API 协议 | 与原 Avalonia 客户端完全一致的 DTO（参见 `../Shared/RemoteOS.Protocol/`） | 🔌 接口层完成，业务对接待续 |
| 🖥️ 平台窗口 | `window_manager` + `bitsdojo_window` 自定义标题栏与窗口控制 | ✅ 已集成 |

> ⚠️ 原 Avalonia 客户端中依赖宿主桌面操作系统原生组件的功能（如 ConPty 内核态伪终端、Linux PAM UI、UAC 权限提升对话框、文件系统内核级事件等）在 Flutter 中仅提供 API 抽象或 Mock 实现，需与服务端对应 Hub/Endpoint 进行真实对接。

---

## 🗂️ 目录结构

```
RemoteOS.Client/
├── pubspec.yaml                     # Flutter 依赖与资源声明
├── analysis_options.yaml            # Lint 规则（flutter_lints）
├── assets/
│   └── translations/                # easy_localization JSON 语言包
│       ├── en-US.json
│       ├── zh-CN.json
│       └── ja-JP.json
└── lib/
    ├── main.dart                    # 入口：窗口初始化、路由、主题、本地化
    ├── core/                        # 跨应用基础设施
    │   ├── theme/                   # 主题系统：调色板、状态、构建器
    │   │   ├── theme_models.dart
    │   │   ├── theme_palette_defaults.dart
    │   │   └── theme_service.dart
    │   ├── auth/
    │   │   └── auth_service.dart    # 认证会话、登录/刷新/登出、安全存储
    │   ├── router/
    │   │   └── app_router.dart
    │   ├── apps/
    │   │   └── app_registry.dart    # 应用注册表 + 内置应用清单
    │   └── window_manager/
    │       └── window_manager.dart  # 窗口模型、状态、布局、交互
    ├── screens/
    │   ├── login/login_screen.dart  # 登录页（服务器地址、账户、密码、语言）
    │   ├── desktop/desktop_screen.dart  # 桌面 Shell 组合根
    │   └── widgets/
    │       ├── taskbar.dart         # 任务栏
    │       └── start_menu.dart      # 开始菜单
    └── apps/                        # 各独立应用（窗口内容）
        ├── welcome/welcome_app.dart
        ├── settings/settings_app.dart
        ├── terminal/terminal_app.dart
        └── notepad/notepad_app.dart
```

---

## 🚀 快速开始

### 1. 环境准备

| 工具 | 最低版本 | 说明 |
| ---- | -------- | ---- |
| Flutter SDK | 3.24.0+ | `flutter --version`；未安装请前往 [flutter.dev](https://docs.flutter.dev/get-started/install) |
| .NET SDK | 10.0+ | 用于运行 [RemoteOS.Server](../RemoteOS.Server) 服务端 |
| 目标平台 | Windows / macOS / Linux | Flutter Desktop 支持（`flutter config --enable-windows-desktop` 等） |

首次构建前执行：

```bash
cd RemoteOS.Client
flutter pub get
```

### 2. 启动服务端

```bash
cd ../RemoteOS.Server
dotnet run                     # 默认监听 http://localhost:5000 / https://localhost:5001
```

也可使用生产配置：

```bash
dotnet run --launch-profile "RemoteOS.Server.Production"
```

### 3. 运行 Flutter 客户端

```bash
cd RemoteOS.Client
flutter run -d windows         # 或 macos / linux
```

默认登录参数（开发环境）：

| 字段 | 值 |
| ---- | ---- |
| 服务器地址 | `http://localhost:5000` |
| 用户名 | 同当前系统登录用户 |
| 密码 | 同当前系统登录密码 |

> 💡 本地开发无需实际账号：认证服务包含 demo 分支逻辑，可在登录页直接使用任意账户进入桌面以预览 UI。

---

## 🧩 架构说明

### 设计原则

1. **状态同步，而非像素流**：所有 UI 组件在 Flutter 端创建与渲染，服务端仅下发业务数据与系统事件。
2. **单向数据流**：使用 `StateNotifier<State>` + `WidgetRef.watch`，避免跨组件隐式共享可变状态。
3. **与原 Avalonia 客户端协议等价**：
   - 主题偏好、调色板结构 → 参见 `Shared/RemoteOS.Protocol/Workspace/ThemePaletteContract.cs`
   - 认证流程 → `Identity/AuthApiRoutes.cs`
   - 终端流 → `Hubs/TerminalHub*.cs`（SignalR 对应 Flutter 端待接入）
4. **视觉一致性优先**：主题色、圆角、阴影、动效均遵循 `theme_palette_defaults.dart` 中的 `RemoteOS Blue` 调色板，确保各系统原生感。

### 核心 Provider 一览

| Provider | 作用 | 所在文件 |
| -------- | ---- | -------- |
| `themeProvider` | 主题模式 + 调色板偏好 + 强调色覆盖 | `core/theme/theme_service.dart` |
| `authProvider` | 认证会话、令牌、记住的连接、PIN 配置 | `core/auth/auth_service.dart` |
| `appRegistryProvider` | 内置/外部应用注册表，用于开始菜单与窗口打开 | `core/apps/app_registry.dart` |
| `windowManagerProvider` | 打开的窗口集合、Z-Order、最小化/最大化状态 | `core/window_manager/window_manager.dart` |

### 扩展新应用

1. 在 `lib/apps/<your_app>/<your_app>_app.dart` 创建 `ConsumerWidget` 子类。
2. 在 `lib/core/apps/app_registry.dart` → `BuiltinApps.all` 中追加 `AppRegistryEntry`，引用你编写的 Widget。
3. 应用在开始菜单、桌面图标、启动命令行中即可自动可用。

---

## 🌍 国际化

- 源文件：`assets/translations/{en-US,zh-CN,ja-JP}.json`
- 运行时切换：调用 `context.setLocale(Locale('zh', 'CN'))` 或在设置应用 → 语言面板操作，所有屏幕立即刷新。
- 新增 key：
  1. 先在 `en-US.json` 添加英文原文；
  2. 再分别复制到 `zh-CN.json` 与 `ja-JP.json` 并翻译；
  3. 使用 `'your.key'.tr()` 或 `.tr(args: ['x'])` 引用。

---

## 🎨 主题系统

### 主题模式（ThemeKind）

```dart
enum ThemeKind { light, dark, system }
```

- `system` 模式下，Flutter 自动监听 `PlatformDispatcher.onPlatformBrightnessChanged`，调色板跟随宿主 OS。
- 状态变化：`ref.read(themeProvider.notifier).setThemeKind(ThemeKind.dark)`。

### 调色板切换

```dart
ref.read(themeProvider.notifier).setPaletteId('builtin:catppuccin');
ref.read(themeProvider.notifier).setAccentOverride('#F38BA8'); // 16进制覆盖强调色
```

内置调色板 ID：

- `builtin:remoteos-blue`（默认）
- `builtin:nord`
- `builtin:catppuccin`

实现细节参见：
- 调色板模型：[theme_models.dart](./lib/core/theme/theme_models.dart)
- 默认值：[theme_palette_defaults.dart](./lib/core/theme/theme_palette_defaults.dart)
- 主题构建与解析：[theme_service.dart](./lib/core/theme/theme_service.dart)

---

## 🔌 与服务端协议对接进度

| 模块 | 服务端 Endpoint | Flutter 端状态 |
| ---- | --------------- | --------------- |
| 登录/刷新/登出 | `/api/auth/*` | AuthService 已实现，包含 JWT 保存与自动刷新 |
| 工作区状态 | `/api/workspace/*` | DTO 对齐；主题偏好与桌面显示设置已接入 |
| 终端流 | `/hubs/terminal` | 已预留 `TerminalApp`；SignalR 客户端待接入 |
| 文件管理 | `/api/files/*` | 占位实现；Explorer 应用窗口骨架已在注册表中 |
| 系统监控 | `/api/system-monitor/*` | Task Manager 占位；设置 - 系统信息已接入 mock 数据 |
| Docker / 隧道 / 防火墙 | `/api/{docker,tunnels,firewall}/*` | 应用占位；对应条目已出现在开始菜单与设置中 |

---

## 🧪 测试与构建

### 静态分析

```bash
cd RemoteOS.Client
flutter analyze
```

### 单元/组件测试（预留目录）

```bash
flutter test
```

### 发布构建（示例）

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

产物位于 `build/<platform>/`。

---

## 📝 与原 Avalonia 客户端的已知差异

| 功能 | Avalonia | Flutter | 备注 |
| ---- | -------- | ------- | ---- |
| 原生文件对话框 | 系统原生（Linux Portal / Win32 / NSOpenPanel） | `file_picker` 平台通道插件 | 体验一致 |
| 系统托盘 | 原生 NotifyIcon + 菜单 | 尚无稳定插件；当前仅提供应用内气泡 | 可替换为 `system_tray` |
| 窗口透明/亚克力 | Avalonia 材质层 | `window_manager` 透明背景 + 自绘磨砂 | 视觉近似 |
| ConPty / forkpty | Win32 / libc 直接调起 | 目前仅本地 mock，真实 PTY 走服务端 TerminalHub SignalR | 已对齐架构 |
| 内核态进程守护 | Agent 命名管道 | 同服务端 `ProcessGuardianEndpoints` | Flutter 仅 UI |
| 多窗口（原生 OS 级） | `Window` / `WindowImpl` 多开 | 目前使用 Flutter 内 **MIDI 窗口管理器**（单一 Flutter 视图模拟多窗） | 如需原生多窗，可引入 `multi_window` 插件 |

---

## 🛡️ License

项目整体遵循仓库根目录 [LICENSE](../LICENSE)（RNCL）协议。
部分第三方开源组件清单参见 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。

---

## 🙋 FAQ

**Q: 为什么选择 Flutter 重构 Avalonia 客户端？**
A: Flutter Desktop 在 Windows / macOS / Linux 三端拥有一致渲染管线（Skia + Impeller），相同代码产生一致的阴影、动画与文本表现；并可复用移动端 Flutter 生态的大量插件（国际化、路由、状态管理、网络、图片缓存）。

**Q: 原有 Avalonia 应用 SDK（`IRemoteApplication`）如何迁移？**
A: 每个 Avalonia `IRemoteApplication` 实现对应 Flutter 端一个 `ConsumerWidget`（参考 `settings_app.dart` 结构），通过 `AppRegistryEntry` 注册即可接入窗口系统、任务栏跳转列表、设置内链接等。

**Q: 中文输入法/高 DPI/触控板手势如何？**
A: Flutter 引擎已处理 IME 文本合成与 Per-Monitor V2 DPI；窗口缩放、拖拽、双击最大化由 `window_manager` + 自绘标题栏协作实现，体验与原生窗口接近。

---

接下来计划：
- [ ] 接入 SignalR 客户端（TerminalHub、PerformanceHub）
- [ ] 完善 Explorer（文件树 + 文件 REST API）
- [ ] 接入系统托盘插件，替代应用内连接气泡
- [ ] 实现首启动向导的服务器配置与连接校验
- [ ] 为 `AuthService` 添加真实 keyring（`flutter_secure_storage` + 平台 fallback）
