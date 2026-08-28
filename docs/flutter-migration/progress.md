# Flutter 迁移进度

此文件是迁移恢复点。继续工作时先读取本文件和 `13-task-backlog.md`，从「下一项」开始；不得把已有代码当作已验收迁移成果。

## 当前恢复点（2026-08-27）

- 已完成：`FLUTTER-001`（Desktop skeleton）。
- 已完成：`FLUTTER-002`（Auth + REST foundation）。
- 已完成：`FLUTTER-003`（Localization compatibility）。
- 已完成：`FLUTTER-004`（Theme palette compatibility）。
- 已完成：`FLUTTER-005`（WindowService / ManagedWindowHost）。
- 已完成：`FLUTTER-006`（ModalManager）。
- 已完成：`FLUTTER-007`（ContextMenuHost）。
- 已完成：`FLUTTER-008`（Shell + desktop/taskbar）。
- 进行中：`FLUTTER-009`（Workspace preference/layout sync）。
- 当前阻塞：`DesktopStatePatch`/Workspace Hub 的服务端实现缺失。`RemoteOS.Server` 未映射 `WorkspaceApiRoutes.Desktop`，没有 `WorkspaceHub` 类，也没有 `app.MapHub(... WorkspaceHubPath)` 注册；Flutter 无法连接或验证 Protocol 已声明的状态同步契约。需决定是否把 server 端实现纳入本次迁移范围。
- 进行中的工作树改动：`FLUTTER-002` 至 `FLUTTER-009` 的认证、本地化、主题、窗口、modal、context menu、shell 和 workspace REST 基础层、测试与依赖更新尚未提交。

## FLUTTER-009 当前实施记录

- 文件：`RemoteOS.Client/lib/features/auth/domain/auth_models.dart`、`RemoteOS.Client/lib/core/auth/auth_service.dart`、`RemoteOS.Client/lib/features/workspace/domain/workspace_models.dart`、`RemoteOS.Client/lib/features/workspace/data/remote_workspace_api.dart`、`RemoteOS.Client/test/features/workspace/remote_workspace_api_test.dart`。
- 已完成：login response 和 `AuthSessionState` 保留 Protocol `workspace.id`；Workspace REST client 覆盖 GET/PUT preferences 和 GET/PUT window-layouts，路径为 `/api/v1/workspaces/{id}/preferences` 与 `/window-layouts`；DTO 保留 workspace 主题、语言、区域、壁纸 key 和 window size 契约。`WorkspaceSyncCoordinator` 在 desktop 打开后拉取 preferences/layouts，将 theme/language 应用于 UI，并将 Settings 的语言、主题、palette、accent 变更以 350ms debounce 写回 workspace。Desktop 以 app ID 读取并应用已保存的 window size，任何非 modal 窗口变化会合并保存对应尺寸。
- 自动验证：`flutter test test/core/window_manager/window_manager_notifier_test.dart test/features/workspace/remote_workspace_api_test.dart` 通过，覆盖 restored app size、窗口状态机与 workspace JSON/路径；`flutter build linux --debug` 成功。
- 未完成/阻塞：尚未实现 `DesktopStatePatch`/Workspace Hub 接收、desktop icon/taskbar 恢复或发送。经检查，server 端同样缺少 `/api/v1/workspaces/{id}/desktop` endpoint、`WorkspaceHub` 和 hub registration，无法作为 Flutter 客户端的可验证依赖；不得把 FLUTTER-009 标为完成，也不得开始 FLUTTER-010，除非用户授权补齐 server 端契约实现或明确允许跳过实时同步验收。

## FLUTTER-008 验收记录

- 文件：`RemoteOS.Client/lib/screens/desktop/desktop_screen.dart`、`RemoteOS.Client/lib/screens/widgets/taskbar.dart`、`RemoteOS.Client/lib/screens/widgets/start_menu.dart`、`RemoteOS.Client/lib/core/window_manager/context_menu_host.dart`。
- 行为：shell 在同一 managed host 中提供 desktop 图标、Start menu、48px taskbar、按 app 分组的窗口按钮和 internal window layer；桌面空白右键菜单可刷新或打开任务管理器/设置；taskbar 不显示 modal，点击非活动单实例会聚焦而非错误最小化。
- 自动验证：`flutter test test/core/window_manager` 通过；使用临时 `libsecret-1-dev` headers 的 `flutter build linux --debug` 成功生成 `build/linux/x64/debug/bundle/remoteos_client`。

## FLUTTER-007 验收记录

- 文件：`RemoteOS.Client/lib/core/window_manager/context_menu_host.dart`、`RemoteOS.Client/test/core/window_manager/context_menu_host_test.dart`。
- 行为：`RemoteContextMenuController` 在 managed desktop overlay 中打开 anchored menu；位置按屏幕边界 clamp，支持分隔线、禁用 action、hover/click submenu、外部点击关闭和 ESC 关闭。具体 Explorer/Git/Shell action 将在对应 feature 任务中使用 `ContextMenuRegion` 绑定。
- 自动验证：`flutter test test/core/window_manager/context_menu_host_test.dart` 通过，覆盖 secondary-click 打开、action 完成后关闭、submenu 与 ESC。

## FLUTTER-006 验收记录

- 文件：`RemoteOS.Client/lib/core/window_manager/modal_manager.dart`、`RemoteOS.Client/lib/core/window_manager/window_manager.dart`、`RemoteOS.Client/lib/screens/desktop/desktop_screen.dart`、`RemoteOS.Client/lib/apps/notepad/notepad_app.dart`、`RemoteOS.Client/test/core/window_manager/modal_manager_test.dart`。
- 行为：`ModalManager.open(ownerId, spec)` 只创建 owner-bound managed window；未知 owner 直接失败。owner 关闭时清理嵌套链，遮罩点击重新聚焦对应的顶层 modal，应用内确认框不再使用 Flutter route-level `showDialog()`。
- 自动验证：`flutter test test/core/window_manager/modal_manager_test.dart test/core/window_manager/window_manager_notifier_test.dart` 通过；`rg` 确认 `lib` 内没有残留 `showDialog`/`AlertDialog`/`Navigator.pop` 实现。

## FLUTTER-005 验收记录

- 文件：`RemoteOS.Client/lib/core/window_manager/window_manager.dart`、`RemoteOS.Client/lib/screens/desktop/desktop_screen.dart`、`RemoteOS.Client/test/core/window_manager/window_manager_notifier_test.dart`。
- 行为：同应用实例复用/聚焦、z-order、拖动和 8 边 resize、最小尺寸与可见抓取区约束、minimize/restore、maximize/restore、内部 fullscreen/restore，以及 owner 关闭时的完整 nested modal 链清理。最小化会保留最大化/全屏前的状态；完成模态框不会重复完成 Future。
- 自动验证：`flutter test test/core/window_manager/window_manager_notifier_test.dart test/core/shell/desktop_window_shell_test.dart` 通过，覆盖状态机和既有窗口 chrome 组件。

## FLUTTER-004 验收记录

- 文件：`RemoteOS.Client/lib/core/theme/theme_models.dart`、`RemoteOS.Client/lib/core/theme/theme_palette_defaults.dart`、`RemoteOS.Client/lib/core/theme/theme_service.dart`、`RemoteOS.Client/test/core/theme/theme_palette_defaults_test.dart`。
- 协议：Theme preferences 与 palette DTO 覆盖 Protocol v2 的 `lightColors`/`darkColors`，并读取 Protocol v1 的 `mode`/`colors` 以支持服务器归一化前的导入数据。自定义色仅允许 `ThemePaletteContract` 中服务器同样接受的 token；内置 `DangerMuted` 保留为 base role，不能由自定义 payload 覆盖。
- 自动验证：`flutter test test/core/theme/theme_palette_defaults_test.dart` 通过，覆盖三个内置 palette 在明暗模式下的 required tokens、自定义 v2/强调色派生、v1 模式兼容、JSON 往返与 token 边界。

## FLUTTER-003 验收记录

- 文件：`RemoteOS.Client/lib/core/localization/language_catalog.dart`、`RemoteOS.Client/lib/core/localization/modular_asset_loader.dart`、`RemoteOS.Client/assets/translations/**`、`RemoteOS.Client/test/core/localization/modular_asset_loader_test.dart`。
- 行为：按 catalog 合并每种语言的 feature JSON；缺少翻译时使用 `en-US`；外部 language pack 可覆盖内置语言或添加新语言；同一 locale 的 feature 分片出现重复叶子 key 时抛出 `FormatException`，避免静默覆盖。
- 自动验证：`flutter test test/core/localization/modular_asset_loader_test.dart` 通过，覆盖所有内置 catalog 合并、外部部分语言包的英文回退、重复 key 拒绝；三份 settings 翻译 JSON 已通过 `jq empty`。

## FLUTTER-002 实施记录（待平台构建验收）

- 文件：`RemoteOS.Client/lib/features/auth/data/remoteos_auth_api.dart`、`RemoteOS.Client/lib/features/auth/domain/auth_models.dart`、`RemoteOS.Client/lib/core/auth/auth_service.dart`、`RemoteOS.Client/lib/core/network/remoteos_api.dart`、`RemoteOS.Client/lib/screens/login/login_screen.dart`、`RemoteOS.Client/test/features/auth/remoteos_auth_api_test.dart`、`RemoteOS.Client/pubspec.yaml`、`RemoteOS.Client/pubspec.lock`。
- 协议与行为：登录、刷新、登出都使用 `/api/v1/auth/*` 和 Protocol 的嵌套 `tokens` 契约；共享 REST transport 会附加 bearer token，遇到 401 时仅刷新并重试一次。`ProblemDetails` 的 `detail`/`title`/`type` 被保留为 `RemoteOsApiException`。
- 凭据：服务器地址和用户名仍在 `SharedPreferences` 中；“记住密码”改为 `flutter_secure_storage` 的 OS 凭据存储，偏好文件仅保存 `hasSavedPassword` 标记。旧 profile 的 Base64 `encryptedPassword` 值不再读取或迁移。
- 自动验证：`flutter test test/features/auth/remoteos_auth_api_test.dart` 通过（登录协议、401 刷新重试、密码不落入偏好设置）；使用临时提取的 `libsecret-1-dev` headers 运行 `flutter build linux --debug` 成功生成 `build/linux/x64/debug/bundle/remoteos_client`。依赖升级至 `flutter_secure_storage ^10.0.0`，以避免 9.x 在当前 Clang 的 `-Werror` 编译失败，同时维持与 `bitsdojo_window` 的 Windows `win32` 约束兼容。
- 静态分析：`flutter analyze` 仍因宿主对 Flutter analysis server 的 LSP 输入截断而报 `FormatException: Unexpected end of input`；需在普通终端或 CI 复验。

## FLUTTER-001 验收记录

- 文件：`RemoteOS.Client/lib/main.dart`、`RemoteOS.Client/lib/core/shell/desktop_window_shell.dart`、`RemoteOS.Client/lib/core/runtime/desktop_runtime.dart`、`RemoteOS.Client/lib/core/runtime/startup_failure_app.dart`。
- 平台：Windows 与 Linux runner 已在仓库；Flutter 的自定义无边框窗口设为 1280×800，最小 760×700，包含移动、最小化、最大化、全屏和关闭控制。
- 日志：启动和未捕获 Flutter/Dart 异常会按平台写入用户目录，Linux 使用 `$XDG_STATE_HOME/RemoteOS/logs`（默认 `~/.local/state/RemoteOS/logs`），Windows 使用 `%LOCALAPPDATA%/RemoteOS/logs`；可由 `REMOTEOS_LOG_DIR` 覆盖。目录不可用时回退到 stderr。
- 失败处理：本地化或窗口插件初始化失败时显示可复制错误的启动失败页面，并尝试将异常写入日志。
- 自动验证：`flutter test` 通过；`flutter build linux --debug` 成功生成 `build/linux/x64/debug/bundle/remoteos_client`。
- 静态分析：本环境下 `flutter analyze` 会因 Flutter analysis server 的 LSP 输入被宿主截断而以 `FormatException: Unexpected end of input` 退出；这是工具运行环境问题，尚需在普通本地终端或 CI 重新验证。

## 后续执行规则

1. 完成每项后，在 Backlog 标注状态、在本文件记录文件/验收/命令/遗留风险。
2. 只有依赖已验收的任务才可标为完成；已有的未验证实现保留为参考，不作为迁移完成依据。
3. 每项至少运行相关单元或组件测试；涉及平台 runner 时至少构建当前可用的平台。
