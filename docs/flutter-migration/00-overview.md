# RemoteOS Avalonia → FURemoteOS Flutter：扫描总览

## 仓库与范围

- 参考实现（只读）：`/home/nanami/文档/RemoteOS`，Git remote：`nanaminato/RemoteOS`。
- 目标实现：本仓库 `/home/nanami/文档/FURemoteOS`，Git remote：`nanaminato/FURemoteOS`；FU 即 Flutter 实现。
- 扫描范围是 `Client/RemoteOS.Client`、Desktop runner 与其引用的 `Framework/RemoteOS.UI`、`RemoteOS.WindowManager`、`Shared/RemoteOS.Protocol`。Server 只用于确认既有契约。

## 实际规模（2026-08-27）

| 项目 | 数量/结论 |
|---|---|
| 非生成 C# | 262 |
| AXAML | 96（含 `App.axaml`） |
| ViewModel | 44 |
| 应用 Manifest | 18 |
| 真实 OS Window | 2：`MainWindow`、`LoginWindow`；启动失败时另建原生 `Window` 错误框 |
| 内部应用窗口 | `WindowManager` 在 Shell Canvas 中管理，非 OS 多窗口 |
| ContextMenu 标签 | 9 |
| 调用 Modal API 的文件 | 20 |
| 语言 | `en-US`、`ja-JP`、`zh-CN`，每种 26 个 JSON 分片 |

最重要的发现是：RemoteOS 是「一个真实主窗口 + 内部桌面 Shell + 多个受管理应用窗口」的系统，不是普通页面路由应用。Flutter 应先复现这一层级。
