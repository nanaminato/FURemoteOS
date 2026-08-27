# Context Menu 映射

源码共 9 个 `<ContextMenu>`：

| 页面 | 控件/操作 |
|---|---|
| Explorer `Views/ExplorerMainView.axaml` | 文件树与文件列表：打开、打开方式、复制/剪切/粘贴、重命名、删除、属性等 |
| DesktopShellView | 桌面空白、桌面文件图标、任务栏：打开、设置、任务管理器、文件操作 |
| Git `Views/GitLogView.axaml` | Branch、commit 与变更文件树：checkout、copy SHA、tag、diff、删除等 |
| Terminal `TerminalView.axaml.cs` | 终端控件的右键/复制粘贴协同 |

菜单项包含 Command、禁用/可见条件、分隔线、图标及本地化 Header。Flutter 必须实现 anchored overlay、边缘避让、键盘/ESC、submenu、状态刷新，且 action 仍受权限和选择状态控制。
