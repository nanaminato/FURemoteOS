# Modal 映射

`Framework/RemoteOS.WindowManager/WindowManager.cs` 提供 `ShowDialogAsync`（应用窗口所有）和 `ShowShellDialogAsync`（Shell 所有）。Dialog 是 `RemoteWindow`，并非 Avalonia `Window` 或普通 Popup：它加入同一 Canvas、其下放 `ModalBlocker` 遮罩，阻止 owner，按 owner 边界居中；嵌套通过 `ModalDialog.ShowDialogAsync` 支持。点击遮罩会重新聚焦最顶 Modal 链。

默认尺寸会限制为 owner 可用区域（最小 320×220），默认约 460×300；具名尺寸例：Docker 新建容器 720×690、详情 720×620、Stack 760×550、拉取镜像 470×230。

| 范围 | 实例 |
|---|---|
| 通用 | Confirm、TextInput、OpenWith、文件属性、权限请求、错误/通知 |
| Docker | 容器 create/edit/detail、Stack、image pull、network/volume、不可用提示 |
| Git | commit、branch、pull/push、remote、credentials、merge、confirm |
| 其他 | Firewall、Certificate request、WebServer site/安装、Tunnel profile/runtime、Terminal/Browser/Editor settings |

Flutter 采用 `ModalManager.open(ownerId, spec) → Future<T?>`，维护 owner 链、遮罩、Z-order、聚焦恢复和嵌套；不能直接使用 `showDialog()`。
