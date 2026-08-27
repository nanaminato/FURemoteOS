# Flutter 迁移任务 Backlog

| ID | Goal | Avalonia Reference | Depends on |
|---|---|---|---|
| FLUTTER-001 | Desktop skeleton | `Client/RemoteOS.Client.Desktop/Program.cs` | — |
| FLUTTER-002 | Auth + REST foundation | `Services/Auth/*`、Protocol Auth | 001 |
| FLUTTER-003 | Localization compatibility | `Localization/*`、`LocalizationService.cs` | 001 |
| FLUTTER-004 | Theme palette compatibility | `ThemeService.cs`、TokenContract | 001 |
| FLUTTER-005 | WindowService / ManagedWindowHost | `Framework/RemoteOS.WindowManager/*` | 001,004 |
| FLUTTER-006 | ModalManager | `ModalDialog.cs`、`WindowManager.cs` | 005 |
| FLUTTER-007 | ContextMenuHost | Explorer/Git/Shell menus | 004,005 |
| FLUTTER-008 | Shell + desktop/taskbar | MainWindow/DesktopShell | 003–007 |
| FLUTTER-009 | Workspace preference/layout sync | WindowLayout、DesktopRestore | 002,008 |
| FLUTTER-010 | Explorer baseline | Explorer App/Client/ViewModel | 002,007,008 |
| FLUTTER-011 | Terminal transport + UI spike | Terminal App/SignalR transport | 002,008 |

后续每项须补充：具体 Files、权限、行为/UI 要求、验收、自动/手动测试和风险。业务 Feature 任务按 01 的实际清单继续编号。
