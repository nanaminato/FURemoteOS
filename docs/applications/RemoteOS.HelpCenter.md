# RemoteOS Help Center

## 定位

Help Center 是 Flutter 客户端内置的离线指南应用，包 ID 为 `remoteos.help-center`。
它不安装、加载或代理外部 `.roapp`。

## 资源与本地化

指南资源位于 `RemoteOS.Client/assets/help_center/<locale>/`，使用 JSON 索引和 Markdown 文档。
当前提供 `en`、`zh-CN`、`ja-JP`，语言选择按 exact → neutral → English 回退。内容与 Widget/Controller
代码分离，新增指南只需在每个 locale 的 `index.json` 中注册 Markdown 文件。

## Activation 与窗口

```text
remoteos://help/guide/docker/install?lang=en
remoteos://help/guide/docker/uninstall?lang=zh-CN
```

Manifest 使用 `SingleWindow`：重复 activation 路由到已有窗口、恢复并聚焦窗口；不会创建第二个主窗口。

## 边界

应用只读取本地打包资源，不获取主机路径、服务端凭据或全局服务容器。Docker 操作仍由 Docker Manager
及服务端权限/能力检查负责；文档不执行命令，也不改变服务器状态。
