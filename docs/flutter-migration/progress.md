# Flutter 迁移进度

此文件是迁移恢复点。继续工作时先读取本文件和 `13-task-backlog.md`，从「下一项」开始；不得把已有代码当作已验收迁移成果。

## 当前恢复点（2026-08-28）

- 已完成：`FLUTTER-001`（Desktop skeleton）。
- 已完成：`FLUTTER-002`（Auth + REST foundation）。
- 已完成：`FLUTTER-003`（Localization compatibility）。
- 已完成：`FLUTTER-004`（Theme palette compatibility）。
- 已完成：`FLUTTER-005`（WindowService / ManagedWindowHost）。
- 已完成：`FLUTTER-006`（ModalManager）。
- 已完成：`FLUTTER-007`（ContextMenuHost）。
- 已完成：`FLUTTER-008`（Shell + desktop/taskbar）。
- 已完成：`FLUTTER-009`（Workspace preference/layout sync）。
- 进行中：`FLUTTER-010`（Explorer baseline；核心文件操作已验证，尚未验收）。
- 进行中的工作树改动：`FLUTTER-002` 至 `FLUTTER-009` 的认证、本地化、主题、窗口、modal、context menu、shell 和 workspace REST 基础层、测试与依赖更新尚未提交。

## FLUTTER-009 验收记录

- 文件：`RemoteOS.Client/lib/features/auth/domain/auth_models.dart`、`RemoteOS.Client/lib/core/auth/auth_service.dart`、`RemoteOS.Client/lib/features/workspace/domain/workspace_models.dart`、`RemoteOS.Client/lib/features/workspace/data/remote_workspace_api.dart`、`RemoteOS.Client/test/features/workspace/remote_workspace_api_test.dart`。
- 已完成：login response 和 `AuthSessionState` 保留 Protocol `workspace.id`；Workspace REST client 覆盖 GET/PUT preferences 和 GET/PUT window-layouts，路径为 `/api/v1/workspaces/{id}/preferences` 与 `/window-layouts`。`WorkspaceSyncCoordinator` 分别读取 preferences/layouts，因此 preferences 临时不可用不会阻止布局恢复；窗口尺寸按 app ID 恢复，非 modal 窗口变化按 2 秒空闲时间合并保存，登出或标题栏关闭前会尽力刷新待写入的数据。Desktop 等待恢复完成才首次打开 Welcome，避免默认尺寸覆盖已保存尺寸；过期的异步写入不能回写较新的本地状态。
- Avalonia 对照结论：原版的 `WindowLayoutStore` 与 `DesktopRestoreOrchestrator` 不实现 `DesktopStatePatch`、`WorkspaceHub`、桌面图标或任务栏的实时状态同步。因此这些 Protocol 预留契约不属于 `FLUTTER-009`，本次未新增该功能。
- 自动验证：`flutter test test/features/workspace/remote_workspace_api_test.dart test/core/window_manager/window_manager_notifier_test.dart test/core/shell/desktop_window_shell_test.dart` 通过；`flutter build linux --debug` 成功。

## FLUTTER-010 当前实施记录

- Avalonia 输入：`Apps/Explorer/ExplorerClient.cs`、`IExplorerClient.cs`、`ViewModels/ExplorerViewModel.cs`、`Views/ExplorerMainView.axaml`。基线包含驱动器/特殊目录和目录列表、进入目录、列表/图标视图、地址导航、刷新、选择与多选、复制/剪切/粘贴、新建目录、重命名、删除、属性、打开方式、上传/下载；具体操作由 `FileAuthorizationPolicies` 限制。
- Flutter 已有：`lib/apps/explorer/explorer_app.dart` 可加载驱动器、特殊目录和 `DirectoryDto.directories/files`，支持地址输入、刷新、目录双击进入、列表/图标视图及本地名称筛选；`features/files/data/remote_file_api.dart` 已有创建、删除、重命名、复制、移动的 REST 包装。
- 已完成（本轮）：`explorer_app.dart` 已接入单选、Ctrl/Shift 多选与长按切换多选、选中状态、命令栏 copy/cut/paste/new folder、条目右键菜单、重命名、删除确认、属性 modal 与操作后的刷新。所有对文件服务的写操作仍由服务端 `FileAuthorizationPolicies` 授权；服务端错误通过 snackbar 返回给用户。复制/移动请求已更正为 Protocol 的 `sourcePath`、`destinationPath`（目标为当前目录下的同名完整路径），重命名已更正为 `sourcePath`。
- 已完成（本轮）：`RemoteFileApi.properties` / `RemoteFileProperties` 映射 Avalonia 属性弹窗所需的服务端 `FilePropertiesDto` 字段；不修改权限，因为该功能不属于当前 Avalonia Explorer 迁移基线。
- 已完成（本轮）：已审计原 Avalonia `ExplorerViewModel` 与 `ExplorerApp.WireDialogs`。Flutter 用官方 `file_selector 1.0.3` 的原生多文件选择与保存位置对话框替代 Avalonia `StorageProvider`：上传为 `/files/upload` multipart，下载为 `/files/download` 流式写入用户选择的本地文件。`RemoteOsApi` 新增受认证的二进制 GET 与 multipart POST，服务端错误仍转为 `RemoteOsApiException`。
- 已完成（本轮）：Image 文件可经“Open / Open with → Image Viewer”打开内置图片查看器，文本扩展名可经“Open / Open with → Code Editor”打开内置代码编辑器；两个应用都从 `/files/content` 读取远程字节。Workspace preferences 现完整映射 Protocol 的 `defaultApps`；Open With 的“Always use this application”会以原 Avalonia app ID（`remoteos.imageviewer` / `remoteos.codeeditor`）写回既有的 workspace preferences 同步层，普通 Open 先遵循映射。无 MIME 且无已知扩展名时读取远程字节，拒绝 NUL 或无效 UTF-8 后才回退 Code Editor。未知/不支持类型明确提示没有兼容应用。这遵循 Avalonia 的内置应用激活方向，而非调用客户端宿主默认程序。
- 已完成（本轮）：Explorer 现有独立历史栈；Back、Forward、Up 均已绑定，前进后再导航会丢弃前进分支，且向上导航同时处理 POSIX `/` 与 Windows `\` 路径。
- 已完成（本轮）：目录上传使用 `file_selector` 的原生目录选择器，在所选目录根创建同名远程目录及所有子目录后，逐文件上传到相对目标目录；符号链接不会被递归跟随。这对应 Avalonia 的 `BuildUploadPlan`/`UploadSourcesAsync` 的目录树语义，仍由服务端写权限约束。
- 尚未完成：Avalonia 的主机剪贴板文件粘贴，以及远程条目拖放移动。Flutter 标准 `Clipboard` API 不公开系统文件列表，因此不能把文本剪贴板误作文件上传；恢复时需使用已经过平台审计的文件剪贴板桥接。随后实施受同一服务端权限约束的远程拖放移动。
- 自动验证（本轮）：在 `RemoteOS.Client` 运行 `flutter test` 通过（29 tests）；加入 `file_selector` 后运行 `flutter build linux --debug` 成功生成 `build/linux/x64/debug/bundle/remoteos_client`。`flutter analyze lib/apps/explorer/explorer_app.dart lib/features/files/data/remote_file_api.dart` 仍因宿主传给 Flutter analysis server 的 LSP 输入截断而报 `FormatException: Unexpected end of input`；与此前记录一致，待 CI/普通终端复验。
- 后续从这里继续：实现上述主机剪贴板文件上传和远程拖放移动，并补充 Explorer REST 契约/组件的直接测试后，才可将 `FLUTTER-010` 标为完成；在此之前不得开始 `FLUTTER-011`。不要基于 Protocol 中未被 Avalonia 使用的端点新增功能。

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
