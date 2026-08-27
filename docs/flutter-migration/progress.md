# Flutter 迁移进度

此文件是迁移恢复点。继续工作时先读取本文件和 `13-task-backlog.md`，从「下一项」开始；不得把已有代码当作已验收迁移成果。

## 当前恢复点（2026-08-27）

- 已完成：`FLUTTER-001`（Desktop skeleton）。
- 下一项：`FLUTTER-002`（Auth + REST foundation）。
- 进行中的工作树改动：无；本轮所有改动均属于 `FLUTTER-001`。

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
