# Feature Parity Matrix

| Feature 群 | Avalonia | Flutter 状态 | 优先级 |
|---|---|---|---|
| 登录、会话刷新、断线 | Login/Auth services | 未开始 | P0 |
| Shell、内部窗口、任务栏、桌面恢复 | MainWindow/DesktopShell/WindowManager | 未开始 | P0 |
| Theme、语言、壁纸、布局同步 | Theming/Localization/WindowLayout | 未开始 | P0 |
| Modal、Context Menu、权限 | WindowManager/AppPermissions | 未开始 | P0 |
| Explorer、Editor、Notepad、Image | Apps/Explorer、CodeEditor、Notepad、ImageViewer | 未开始 | P1 |
| Terminal、Task Manager | Apps/Terminal、TaskManager | 未开始 | P1（高风险） |
| Docker、Git、Firewall、Certificates | 对应 Apps | 未开始 | P1 |
| Web Servers、Tunnels、Guardian、Port Forwarding | 对应 Apps | 未开始 | P1 |
| Browser、App Installer、Developer / External App | 对应 Apps/Services | 未开始 | P2 |

验收时每个 Feature 必须列出具体 View、ViewModel、API、权限和自动/手动测试；不可仅标“UI 已完成”。
