# 控件映射

| Avalonia 实际用法 | Flutter 目标 |
|---|---|
| `Window`（Main/Login） | desktop window runner + `WindowService` |
| `RemoteWindow` / Canvas managed windows | `ManagedWindowHost`，拖动、resize、min/max/fullscreen、taskbar、z-order |
| `ModalDialog` / `ModalBlocker` | `ModalManager` / Modal overlay stack |
| Grid、StackPanel、Border、TextBlock | Layout primitives + RemoteOS token widgets |
| Button/TextBox/ComboBox/CheckBox/Tab | 统一 Desktop UI Kit，保留 hover/focus/keyboard |
| TreeView / DataGrid | 可虚拟化 Tree/Grid，支持多选、排序、右键 |
| AvaloniaEdit | 编辑器 adapter（文本、编码、保存/重开） |
| RoyalTerminal | 终端 emulator adapter（ANSI、resize、selection、tabs） |
| NativeWebView | Desktop WebView adapter |
| `PerformanceLineChart` | 自定义 canvas/chart（限流实时更新） |

不可机械使用 Material 默认控件；样式须读 `RemoteTheme`，交互须由 10 的契约验收。
