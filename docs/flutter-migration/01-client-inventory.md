# Avalonia Client 清单

## 组成

- 启动：`Client/RemoteOS.Client.Desktop/Program.cs` + `RemoteOS.Client/App.axaml(.cs)`。
- OS 壳：`Views/MainWindow.axaml`（无系统装饰、最小 800×520）与 `Views/Login/LoginWindow.axaml`。
- 内部 Shell：`Views/Shell/DesktopShellView.axaml`、`DesktopShellViewModel.cs`、`Framework/RemoteOS.WindowManager/*`。
- 基础服务：Bootstrapper、Auth、Localization、Theming、WindowLayout、AppPermissions、DesktopRestore、Developer 与 Diagnostics。

## 注册应用（均为 Shell 内部窗口）

| 应用 | 主要能力 |
|---|---|
| Welcome | 起始页 |
| Explorer | 远程文件、上传下载、剪贴板、属性、打开方式 |
| Terminal | SignalR 终端、标签、设置 |
| Task Manager | 进程与性能流图表 |
| Settings | 个性化、网络、语言、应用、镜像、开发者 |
| Browser | WebView、书签、历史与设置 |
| Code Editor / Notepad | 远程文件编辑、编码与设置 |
| Image Viewer | 图像预览 |
| Docker | 容器、镜像、网络、卷、Stack |
| Git | 仓库、分支、提交、冲突、日志与远程 |
| Firewall | 状态、规则、默认策略 |
| Certificates | 申请、部署、续期、撤销 |
| Web Servers | Nginx/站点、安装与生命周期 |
| Tunnels | FRP 定义、Profile、Runtime、FRPS、日志 |
| Port Forwarding | 本地回环转发 |
| Process Guardian | 工作负载、服务、审计与日志 |
| App Installer | 服务端应用包安装 |

`ApplicationManifest` 的权限与实例策略是 Feature 迁移输入；不得仅按 AXAML 文件名推断行为。
