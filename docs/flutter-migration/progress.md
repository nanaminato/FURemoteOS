# Flutter 迁移进度

此文件是迁移恢复点。继续工作时先读取本文件和 `13-task-backlog.md`，从「下一项」开始；不得把已有代码当作已验收迁移成果。

## 当前恢复点（2026-08-27）

- 已完成：`FLUTTER-001`（Desktop skeleton）。
- 已完成：`FLUTTER-002`（Auth + REST foundation）。
- 已完成：`FLUTTER-003`（Localization compatibility）。
- 下一项：`FLUTTER-004`（Theme palette compatibility）。
- 进行中的工作树改动：`FLUTTER-002` 至 `FLUTTER-003` 的认证、本地化基础层、测试与依赖更新尚未提交。

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
