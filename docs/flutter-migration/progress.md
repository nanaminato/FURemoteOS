# Flutter 迁移进度

此文件是迁移恢复点。继续工作时先读取本文件和 `13-task-backlog.md`，从「下一项」开始；不得把已有代码当作已验收迁移成果。

## 当前恢复点（2026-08-28）

* 已完成：`FLUTTER-001`（Desktop skeleton）。

* 已完成：`FLUTTER-002`（Auth + REST foundation）。

* 已完成：`FLUTTER-003`（Localization compatibility）。

* 已完成：`FLUTTER-004`（Theme palette compatibility）。

* 已完成：`FLUTTER-005`（WindowService / ManagedWindowHost）。

* 已完成：`FLUTTER-006`（ModalManager）。

* 已完成：`FLUTTER-007`（ContextMenuHost）。

* 已完成：`FLUTTER-008`（Shell + desktop/taskbar）。

* 已完成：`FLUTTER-009`（Workspace preference/layout sync）。

* 已完成：`FLUTTER-010`（Explorer baseline）。

* 已完成：`FLUTTER-011`（SignalR 终端传输 + UI）。

* 已完成：`FLUTTER-012`（Task Manager）。

* 已完成：`FLUTTER-013`（Docker Manager，本轮收口；Windows 本机构建被宿主 VS 缺少 ATL 组件阻塞，见下）。

* 已完成：`FLUTTER-014`（Notepad & Settings 对齐，含 Explorer 选择模式/模态框补齐；Windows `flutter build windows --debug` 已通过，未做功能测试）。

* 进行中的工作树改动：`FLUTTER-002` 至 `FLUTTER-009` 的认证、本地化、主题、窗口、modal、context menu、shell 和 workspace REST 基础层、测试与依赖更新尚未提交。

## FLUTTER-009 验收记录

* 文件：`RemoteOS.Client/lib/features/auth/domain/auth_models.dart`、`RemoteOS.Client/lib/core/auth/auth_service.dart`、`RemoteOS.Client/lib/features/workspace/domain/workspace_models.dart`、`RemoteOS.Client/lib/features/workspace/data/remote_workspace_api.dart`、`RemoteOS.Client/test/features/workspace/remote_workspace_api_test.dart`。

* 已完成：login response 和 `AuthSessionState` 保留 Protocol `workspace.id`；Workspace REST client 覆盖 GET/PUT preferences 和 GET/PUT window-layouts，路径为 `/api/v1/workspaces/{id}/preferences` 与 `/window-layouts`。`WorkspaceSyncCoordinator` 分别读取 preferences/layouts，因此 preferences 临时不可用不会阻止布局恢复；窗口尺寸按 app ID 恢复，非 modal 窗口变化按 2 秒空闲时间合并保存，登出或标题栏关闭前会尽力刷新待写入的数据。Desktop 等待恢复完成才首次打开 Welcome，避免默认尺寸覆盖已保存尺寸；过期的异步写入不能回写较新的本地状态。

* Avalonia 对照结论：原版的 `WindowLayoutStore` 与 `DesktopRestoreOrchestrator` 不实现 `DesktopStatePatch`、`WorkspaceHub`、桌面图标或任务栏的实时状态同步。因此这些 Protocol 预留契约不属于 `FLUTTER-009`，本次未新增该功能。

* 自动验证：`flutter test test/features/workspace/remote_workspace_api_test.dart test/core/window_manager/window_manager_notifier_test.dart test/core/shell/desktop_window_shell_test.dart` 通过；`flutter build linux --debug` 成功。

## FLUTTER-010 当前实施记录

* Avalonia 输入：`Apps/Explorer/ExplorerClient.cs`、`IExplorerClient.cs`、`ViewModels/ExplorerViewModel.cs`、`Views/ExplorerMainView.axaml`。基线包含驱动器/特殊目录和目录列表、进入目录、列表/图标视图、地址导航、刷新、选择与多选、复制/剪切/粘贴、新建目录、重命名、删除、属性、打开方式、上传/下载；具体操作由 `FileAuthorizationPolicies` 限制。

* Flutter 已有：`lib/apps/explorer/explorer_app.dart` 可加载驱动器、特殊目录和 `DirectoryDto.directories/files`，支持地址输入、刷新、目录双击进入、列表/图标视图及本地名称筛选；`features/files/data/remote_file_api.dart` 已有创建、删除、重命名、复制、移动的 REST 包装。

* 已完成（本轮）：`explorer_app.dart` 已接入单选、Ctrl/Shift 多选与长按切换多选、选中状态、命令栏 copy/cut/paste/new folder、条目右键菜单、重命名、删除确认、属性 modal 与操作后的刷新。所有对文件服务的写操作仍由服务端 `FileAuthorizationPolicies` 授权；服务端错误通过 snackbar 返回给用户。复制/移动请求已更正为 Protocol 的 `sourcePath`、`destinationPath`（目标为当前目录下的同名完整路径），重命名已更正为 `sourcePath`。

* 已完成（本轮）：`RemoteFileApi.properties` / `RemoteFileProperties` 映射 Avalonia 属性弹窗所需的服务端 `FilePropertiesDto` 字段；不修改权限，因为该功能不属于当前 Avalonia Explorer 迁移基线。

* 已完成（本轮）：已审计原 Avalonia `ExplorerViewModel` 与 `ExplorerApp.WireDialogs`。Flutter 用官方 `file_selector 1.0.3` 的原生多文件选择与保存位置对话框替代 Avalonia `StorageProvider`：上传为 `/files/upload` multipart，下载为 `/files/download` 流式写入用户选择的本地文件。`RemoteOsApi` 新增受认证的二进制 GET 与 multipart POST，服务端错误仍转为 `RemoteOsApiException`。

* 已完成（本轮）：Image 文件可经“Open / Open with → Image Viewer”打开内置图片查看器，文本扩展名可经“Open / Open with → Code Editor”打开内置代码编辑器；两个应用都从 `/files/content` 读取远程字节。Workspace preferences 现完整映射 Protocol 的 `defaultApps`；Open With 的“Always use this application”会以原 Avalonia app ID（`remoteos.imageviewer` / `remoteos.codeeditor`）写回既有的 workspace preferences 同步层，普通 Open 先遵循映射。无 MIME 且无已知扩展名时读取远程字节，拒绝 NUL 或无效 UTF-8 后才回退 Code Editor。未知/不支持类型明确提示没有兼容应用。这遵循 Avalonia 的内置应用激活方向，而非调用客户端宿主默认程序。

* 已完成（本轮）：Explorer 现有独立历史栈；Back、Forward、Up 均已绑定，前进后再导航会丢弃前进分支，且向上导航同时处理 POSIX `/` 与 Windows `\` 路径。

* 已完成（本轮）：目录上传使用 `file_selector` 的原生目录选择器，在所选目录根创建同名远程目录及所有子目录后，逐文件上传到相对目标目录；符号链接不会被递归跟随。这对应 Avalonia 的 `BuildUploadPlan`/`UploadSourcesAsync` 的目录树语义，仍由服务端写权限约束。

* 已完成（本轮）：远程条目可通过长按拖放到另一文件夹来移动；目标高亮仅在目标为文件夹且不会将目录移入自身/后代时出现，提交时调用既有 `move` API。主机文件剪贴板使用 `pasteboard 0.5.0`（Linux/Windows 原生文件列表）读取路径后上传文件或目录；目录选择与剪贴板目录共用同一递归上传计划，均创建同名根目录、跳过符号链接并保留相对树。空剪贴板或文本剪贴板不会被错误地当作文件。

* 自动验证（本轮）：新增 `test/features/files/remote_file_api_test.dart`，覆盖 `DirectoryDto.directories/files`、properties、rename 的 `sourcePath`、copy/move 的 `destinationPath` 与 MIME 映射；同 `test/features/workspace/remote_workspace_api_test.dart` 一起通过。运行 `flutter build linux --debug` 成功生成 `build/linux/x64/debug/bundle/remoteos_client`。`flutter analyze lib/apps/explorer/explorer_app.dart lib/features/files/data/remote_file_api.dart` 仍因宿主传给 Flutter analysis server 的 LSP 输入截断而报 `FormatException: Unexpected end of input`；与此前记录一致，待 CI/普通终端复验。

* 已完成（后续轮）：Explorer 现在可从当前目录工具栏或任意文件夹的上下文菜单打开 Terminal，并将远程路径作为 `StartTerminalRequest.workingDirectory` 传给服务端；不会对根/特殊位置伪造目录终端。

## FLUTTER-011 验收记录

* Avalonia 输入：`Apps/Terminal/SignalRTerminalTransport.cs`、`TerminalHubConnection.cs` 与 `TerminalViewModel.cs`。对齐的协议为 `/hubs/terminals` 的 `Start`、`Input`、`Resize`、`Close`，以及服务端事件 `OnOutput`、`OnProcessExited`；关闭窗口只 detach，显式“Terminate remote session”才调用 `Close` 释放 PTY。

* Flutter 实现：`lib/apps/terminal/terminal_app.dart` 已移除所有本地 mock command。使用 `signalr_hub` 建立带 access-token 的 Hub 连接，向 `Start` 传递初始列/行和可选 working directory；将 `byte[]` 的 JSON Base64 表示与 UTF-8 I/O 转换，实时处理窗口 resize。`xterm2` 负责客户端 VT/xterm 渲染和键盘输入，避免把 ANSI/PTTY 原始流错误地当作普通文本。

* Explorer 对齐：`lib/apps/explorer/explorer_app.dart` 通过当前目录工具栏和文件夹菜单创建 `TerminalApp(workingDirectory: ...)`；不新增 Avalonia 中不存在的会话管理、自动重连或额外终端功能。

* 自动验证：`flutter build linux --debug` 于 2026-08-28 成功。仍需在可访问认证 Server 的环境中做手动端到端验证（连接、输入、ANSI 输出、resize、detach/terminate）；`flutter analyze` 仍受宿主 LSP 输入截断的既有 `FormatException` 影响。

## FLUTTER-012 当前实施记录

* Avalonia 输入：`Apps/TaskManager/TaskManagerApp.cs`、`TaskManagerClient.cs`、`PerformanceStream.cs`、`ViewModels/TaskManagerViewModel.cs` 与 `Views/TaskManagerMainView.axaml`。

* 迁移边界：仅实现已有的性能资源页（CPU、内存、文件系统、磁盘、网络）、`/hubs/performance` 实时订阅及 REST history/snapshot 回退、可过滤的进程列表和结束进程反馈。不得新增 GPU 图表、进程树、优先级修改、服务管理或本地宿主监控。

* 权限与验证：所有 REST/Hub 均依赖登录 access token；结束进程必须展示 Server 的 `requiresElevation` 结果，不能在客户端假定提权成功。验收需覆盖 Hub Subscribe/Unsubscribe、历史回补、进程 query/filter/kill wire fields，以及 Linux build；实际 Server 手动验证另列。

* 已完成（本轮基础层）：新增 `features/system_monitor/data/remote_system_monitor_api.dart`，覆盖 snapshot、最长 60 秒 history、第一页 memory-sort process query 与 kill；DTO 保留 `requiresElevation`，不将服务端拒绝误报为已结束。新增 `test/features/system_monitor/remote_system_monitor_api_test.dart` 覆盖对应 route/query/result 字段；测试和 `flutter build linux --debug` 通过。

* 已完成（本轮实时层）：新增 `features/system_monitor/data/performance_hub.dart`，以当前认证 token 连接 `/hubs/performance`，注册 `OnPerformanceSnapshot` 后调用 `Subscribe`；dispose 时 best-effort `Unsubscribe` 再停止连接。启用 SignalR automatic reconnect，并在 `onreconnected` 后重新 `Subscribe`、通知 UI 从 REST history 回补，符合 Avalonia `PerformanceStream` 的生命周期。

* 已完成（本轮 UI）：新增 `apps/task_manager/task_manager_app.dart` 并替换注册表中原先泛用的 `ServerAdminApp` 占位页。界面保留 Avalonia 的 Performance/Processes 双页：性能页显示 Hub/history 提供的 CPU、内存、文件系统容量、磁盘 I/O 与网络速率；进程页每 5 秒刷新、可过滤、可结束任务并准确提示 `requiresElevation`。Hub 重连事件会重新读取 history，并保留最后有效样本作为回退。未新增进程树、GPU、优先级或服务控制。`flutter build linux --debug` 和 Task Manager API 测试均通过；测试现覆盖文件系统、磁盘和网络实时 DTO 字段的聚合。剩余验收：在实际已登录 Server 验证 Hub 首样本、断线后的 history 回补与结束进程的权限失败反馈；在此之前 FLUTTER-012 不得完成。

* 对照审计（未完成）：Flutter 性能卡片现可选择 CPU、内存、文件系统、磁盘或网络，并用最多 60 个按 sequence 去重的 history/Hub 样本绘制所选资源折线图。该图在首次加载、实时更新及重连回补时更新。进程页已补线程列、自动刷新开关、手动刷新与清除筛选（并在关闭自动刷新时取消其 5 秒 timer）。剩余差距是 Avalonia 的逐设备/文件系统导航和详细字段；不能因 REST/Hub 层已就绪而提前结束 FLUTTER-012。

* 已完成（本轮详情契约）：`RemoteSystemMonitorApi.info()` 已接入 `/api/v1/system/performance/info`，解析 CPU 型号/逻辑处理器数、内存总量以及文件系统、磁盘、网络身份列表；对 Server 未提供的字段保持 nullable，绝不伪造 0。性能页选择资源时已显示相应的真实低频详情。wire-format 测试与 Linux debug build 均通过。剩余是将聚合资源改成 Avalonia 的逐设备/文件系统选择。

* 回归基线：2026-08-28 在 Flutter Client 目录执行完整 `flutter test`，29 个已有测试与 2 个新增系统监控/API 测试全部通过（共 31）；`git diff --check` 无空白错误。测试日志中的缺失 localization key 警告来自既有 test assets，不影响通过状态。

* Server E2E（2026-08-28）：使用用户提供的 localhost 登录会话，真实验证 `/api/v1/system/performance/info`、history 与 process query 的 JWT REST 契约；新增无凭据的 opt-in `test/integration/performance_hub_e2e_test.dart`，以 `REMOTEOS_E2E_URL`/`REMOTEOS_E2E_TOKEN` 运行后成功完成 `/hubs/performance` 的连接、`Subscribe`、首个 `OnPerformanceSnapshot` 接收与 `Unsubscribe`。新增 `test/integration/task_manager_kill_e2e_test.dart`：经 Terminal 创建受控 `sleep` 子进程、读取 PID、调用真实 Task Manager DELETE 路由并断言 `success: true`，finally 再次清理。`requiresElevation` 的实际权限失败仍不伪造，现有 API/UI 测试已覆盖该结果字段。

* Terminal Server E2E（2026-08-28）：新增同样无凭据的 opt-in `test/integration/terminal_hub_e2e_test.dart`。对本地 Server 成功验证 `/hubs/terminals` 连接、`Start` 返回 session ID、Base64 `Input` 字节写入、Base64 `OnOutput` 原始字节回传；测试将 `workingDirectory` 指定为 `/tmp` 并以 `pwd` 输出断言，验证 Explorer “Open terminal here”实际激活远程工作目录。finally 调用 `Close`/`stop`，不遗留 PTY。该验证覆盖 Flutter Terminal 本轮重写的核心传输路径。

* 已完成（收口，2026-08-28）：`PerformanceSnapshot` 保留每个 filesystem、disk 和 network 的稳定 ID 与实时值，`PerformanceInfo` 同样保留资源 ID/名称。性能页可在聚合值与单个实际文件系统、磁盘、网卡之间切换；资源图按所选 ID 绘制，缺失样本显示为 0 而不冒充另一项资源数据。未加入 GPU、进程树、优先级、服务管理或任何本地宿主监控。`flutter test test/features/system_monitor/remote_system_monitor_api_test.dart` 与 `flutter build linux --debug` 均于本轮通过，`git diff --check` 通过。因此 `FLUTTER-012` 完成。

## FLUTTER-013 当前实施记录

* Avalonia 范围：Docker Engine 可用性、容器、镜像、网络、卷、Compose Stack；容器创建/重命名/详情/日志/统计及安全 lifecycle 操作、镜像拉取/删除、网络/卷创建删除和 Stack 校验/部署/动作均须使用服务端的结构化 Docker 契约，不能拼接 Docker CLI。

* 已完成（基础层）：新增 `features/docker/data/remote_docker_api.dart`，映射 status、containers、images、volumes、networks 和 stacks 的具体 DTO 字段。`apps/docker/docker_manager_app.dart` 现注册为 Docker Manager，按 Avalonia 的六个资源页显示真实类型化 DTO 与 Engine 可用性，替代 `RemoteAdminPage` 的无类型 JSON 表格；失败时可重试。容器/镜像/网络/卷/Stack 的创建、详情和写操作尚未迁移；`FLUTTER-013` 仍进行中。`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（写入契约）：Docker REST 层现覆盖容器 lifecycle（含 `force` / `confirmed`）、镜像拉取与删除、网络和卷删除；所有破坏性请求固定发送 Server 所需的确认字段，操作结果保留 `success`、`problemCode` 与安全的 `logLines`，不将错误误报为成功。UI 确认 modal 与创建、详情、日志/统计、Compose 操作仍待接入。

* 已完成（容器交互）：Containers 页现支持 Start、Stop 与 Delete。Stop/Delete 使用 `ModalManager` 创建 owner-bound managed confirmation window，确认后才向服务端发送 `confirmed: true`；Start 没有被错误地标为破坏性操作。结果只以服务端 operation result 为准，成功后刷新列表。创建、重命名、详情、日志/统计及其他 Docker 资源操作仍待迁移。`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 自动验证：新增 `test/features/docker/remote_docker_api_test.dart`，覆盖认证 Docker status/containers DTO、容器 Stop 的 `force`/`confirmed` JSON、镜像删除的显式 JSON body 和网络删除的 `confirmed` query；`flutter test test/features/docker/remote_docker_api_test.dart`、`flutter build linux --debug` 与 `git diff --check` 均于本轮通过。

* 已完成（容器详情基础）：REST 层映射 container inspect、受限 tail 的 logs 与 stats DTO；Containers 列表点击可通过 `ModalManager` 打开 720×620 owner-bound 详情窗口，显示 Docker 返回的身份、状态、ports、mounts 和 networks。日志/统计的详情展示及创建/重命名仍待接入；`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（容器详情收口）：详情窗口并行读取并显示有界 logs 与一次性 stats（CPU、memory、network、block I/O）；Server 未返回日志时明确显示空状态。不会把容器统计转换为本地监控或添加持续采样。创建/重命名和其他 Docker 资源操作仍待迁移；`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（创建/重命名契约）：`DockerContainerCreate` 严格对应 Protocol 的 name、image、arguments、ports、environment、mounts、network、restartPolicy，并通过 `/containers` POST 发送；重命名只调用服务端允许的 `/containers/{id}` PUT，不将镜像、端口或挂载伪装成就地修改。wire-format 测试覆盖创建 JSON；尚未提供表单 UI。`flutter test test/features/docker/remote_docker_api_test.dart`、`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（创建 UI）：Docker workspace 标题栏新增 Create container，使用 `ModalManager` 打开 Avalonia 对照尺寸 720×690 的 owner-bound 表单。表单仅收集 Protocol 已允许的 name、image、逐行 arguments/ports/environment/mounts、network、restart policy；name/image 缺失时不可提交，提交后调用结构化 create 契约并报告服务端结果。`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（网络/卷/Stack 契约）：REST 层已映射网络、卷的 create（包含服务端的 name/driver/confirmed payload）以及 Compose Stack 的 validate/deploy（name/composeYaml）；未拼接 Compose 或 Docker CLI。上述写操作的 modal/UI 尚未接入。`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 自动验证（网络/Stack）：Docker wire-format 测试现覆盖 network create 的 name/driver/confirmed 及 Stack validate 的 name/composeYaml。`flutter test test/features/docker/remote_docker_api_test.dart` 与 `git diff --check` 于本轮通过。

* 回归基线（2026-08-28）：在 Flutter Client 目录运行完整 `flutter test`，32 项通过、3 项需要外部 `REMOTEOS_E2E_URL`/`REMOTEOS_E2E_TOKEN` 的集成测试按设计跳过；随后 `flutter build linux --debug` 与 `git diff --check` 通过。测试中 localization key 警告来自既有 test assets，不影响结果。

* 已完成（Stack 动作契约）：新增 Compose stack action 的结构化 `confirmed` payload；可用于服务端允许的 start/stop/restart/down 等动作，客户端不推断动作是否合法或跳过服务端确认。UI 尚待接入。`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（Stack 详情契约）：REST 层可读取指定 Stack 的受控 definition（name/composeYaml）与 service 列表（service/container/image/state/status），用于后续只读详情和编辑前回填；没有把 Compose YAML 作为 shell 输入。`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（网络/卷详情契约）：REST 层可读取 network details（identity/driver/scope/containers）和 volume details（identity/driver/mountpoint/labels）；标签仍是服务端返回的受限数据。详情 modal 尚待接入。`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（镜像构建契约）：REST 层支持 image build 的 `contextDirectory`、`imageReference` 和可选 `dockerfile` 结构化请求；Server 仍负责验证 host-approved context roots，Flutter 不读取或拼接任意主机路径。UI 尚待接入。`flutter build linux --debug` 与 `git diff --check` 于本轮通过。

* 已完成（工作区整体收口，2026-08-28）：`apps/docker/docker_manager_app.dart` 已按 Avalonia `DockerManagerWorkspace`/`DockerManagerViewModel` 完整重写：workspace 头部（标题、Engine 状态 chip、安装指引入口及其不可用回退）+ 六个资源页（Overview/Containers/Stacks/Images/Networks/Volumes，含各自 hint 与表格列）+ 全部 managed modal（创建容器 720×690、编辑容器重命名、容器详情 720×620 含 logs/stats 只读块、Stack 校验/部署/编辑 760×550、拉取镜像 470×230、创建网络/卷 470×280、Docker 不可用、删除确认）。VM 覆盖 Avalonia 全部命令：容器 start/stop/restart/pause/unpause/delete、详情/logs/stats、create/rename；Stack validate/deploy/action/delete、services 回填、编辑与“打开 Compose 位置”（经 Explorer path 激活）；镜像 pull/delete；网络与卷 create/delete。`DockerStackOperationResult` 保留服务端 `messages`；`deleteImage` 发送 `imageReference: id`（对照 Avalonia `DockerImageOperationRequest(image.Id, true)`）；`DockerContainerDetails` 扩展 command/workingDirectory/restartPolicy/labels 等全部字段。

* 本地化：新增 `assets/translations/docker/{en-US,zh-CN,ja-JP}.json`（145 key，三语完全对齐，沿用 Avalonia key），`catalog.json` 注册 docker bundle；已核对 app 内全部 128 个 `.tr()` key 均存在于 bundle（补齐遗漏的 `docker.volumes_hint`）。

* 自动验证（2026-08-28）：完整 `flutter test` 32 项通过、3 项 E2E 按设计跳过；Docker wire 测试覆盖 deleteImage 的 `imageReference: 'img'` 与 stack `messages` 断言。`window_manager_notifier_test` 经 `app_registry` 传递编译 `docker_manager_app.dart`，即 Dart 代码经完整测试套件编译通过。

* 构建注意：本机（Windows）`flutter build windows --debug` 失败于 `flutter_secure_storage_windows` 插件缺少 `atlstr.h`（宿主 VS 未安装 ATL 组件的既有环境问题，与 Docker 改动无关）；WSL 不可用故无法复跑 Linux 构建。此前各轮 `flutter build linux --debug` 均通过。恢复建议：在 VS Installer 勾选 “C++ ATL for latest v143 build tools” 后复验 Windows 构建。据此 FLUTTER-013 标记完成，Dart 层编译与契约测试均已通过。

## FLUTTER-008 验收记录

* 文件：`RemoteOS.Client/lib/screens/desktop/desktop_screen.dart`、`RemoteOS.Client/lib/screens/widgets/taskbar.dart`、`RemoteOS.Client/lib/screens/widgets/start_menu.dart`、`RemoteOS.Client/lib/core/window_manager/context_menu_host.dart`。

* 行为：shell 在同一 managed host 中提供 desktop 图标、Start menu、48px taskbar、按 app 分组的窗口按钮和 internal window layer；桌面空白右键菜单可刷新或打开任务管理器/设置；taskbar 不显示 modal，点击非活动单实例会聚焦而非错误最小化。

* 自动验证：`flutter test test/core/window_manager` 通过；使用临时 `libsecret-1-dev` headers 的 `flutter build linux --debug` 成功生成 `build/linux/x64/debug/bundle/remoteos_client`。

## FLUTTER-007 验收记录

* 文件：`RemoteOS.Client/lib/core/window_manager/context_menu_host.dart`、`RemoteOS.Client/test/core/window_manager/context_menu_host_test.dart`。

* 行为：`RemoteContextMenuController` 在 managed desktop overlay 中打开 anchored menu；位置按屏幕边界 clamp，支持分隔线、禁用 action、hover/click submenu、外部点击关闭和 ESC 关闭。具体 Explorer/Git/Shell action 将在对应 feature 任务中使用 `ContextMenuRegion` 绑定。

* 自动验证：`flutter test test/core/window_manager/context_menu_host_test.dart` 通过，覆盖 secondary-click 打开、action 完成后关闭、submenu 与 ESC。

## FLUTTER-006 验收记录

* 文件：`RemoteOS.Client/lib/core/window_manager/modal_manager.dart`、`RemoteOS.Client/lib/core/window_manager/window_manager.dart`、`RemoteOS.Client/lib/screens/desktop/desktop_screen.dart`、`RemoteOS.Client/lib/apps/notepad/notepad_app.dart`、`RemoteOS.Client/test/core/window_manager/modal_manager_test.dart`。

* 行为：`ModalManager.open(ownerId, spec)` 只创建 owner-bound managed window；未知 owner 直接失败。owner 关闭时清理嵌套链，遮罩点击重新聚焦对应的顶层 modal，应用内确认框不再使用 Flutter route-level `showDialog()`。

* 自动验证：`flutter test test/core/window_manager/modal_manager_test.dart test/core/window_manager/window_manager_notifier_test.dart` 通过；`rg` 确认 `lib` 内没有残留 `showDialog`/`AlertDialog`/`Navigator.pop` 实现。

## FLUTTER-005 验收记录

* 文件：`RemoteOS.Client/lib/core/window_manager/window_manager.dart`、`RemoteOS.Client/lib/screens/desktop/desktop_screen.dart`、`RemoteOS.Client/test/core/window_manager/window_manager_notifier_test.dart`。

* 行为：同应用实例复用/聚焦、z-order、拖动和 8 边 resize、最小尺寸与可见抓取区约束、minimize/restore、maximize/restore、内部 fullscreen/restore，以及 owner 关闭时的完整 nested modal 链清理。最小化会保留最大化/全屏前的状态；完成模态框不会重复完成 Future。

* 自动验证：`flutter test test/core/window_manager/window_manager_notifier_test.dart test/core/shell/desktop_window_shell_test.dart` 通过，覆盖状态机和既有窗口 chrome 组件。

## FLUTTER-004 验收记录

* 文件：`RemoteOS.Client/lib/core/theme/theme_models.dart`、`RemoteOS.Client/lib/core/theme/theme_palette_defaults.dart`、`RemoteOS.Client/lib/core/theme/theme_service.dart`、`RemoteOS.Client/test/core/theme/theme_palette_defaults_test.dart`。

* 协议：Theme preferences 与 palette DTO 覆盖 Protocol v2 的 `lightColors`/`darkColors`，并读取 Protocol v1 的 `mode`/`colors` 以支持服务器归一化前的导入数据。自定义色仅允许 `ThemePaletteContract` 中服务器同样接受的 token；内置 `DangerMuted` 保留为 base role，不能由自定义 payload 覆盖。

* 自动验证：`flutter test test/core/theme/theme_palette_defaults_test.dart` 通过，覆盖三个内置 palette 在明暗模式下的 required tokens、自定义 v2/强调色派生、v1 模式兼容、JSON 往返与 token 边界。

## FLUTTER-003 验收记录

* 文件：`RemoteOS.Client/lib/core/localization/language_catalog.dart`、`RemoteOS.Client/lib/core/localization/modular_asset_loader.dart`、`RemoteOS.Client/assets/translations/**`、`RemoteOS.Client/test/core/localization/modular_asset_loader_test.dart`。

* 行为：按 catalog 合并每种语言的 feature JSON；缺少翻译时使用 `en-US`；外部 language pack 可覆盖内置语言或添加新语言；同一 locale 的 feature 分片出现重复叶子 key 时抛出 `FormatException`，避免静默覆盖。

* 自动验证：`flutter test test/core/localization/modular_asset_loader_test.dart` 通过，覆盖所有内置 catalog 合并、外部部分语言包的英文回退、重复 key 拒绝；三份 settings 翻译 JSON 已通过 `jq empty`。

## FLUTTER-002 实施记录（待平台构建验收）

* 文件：`RemoteOS.Client/lib/features/auth/data/remoteos_auth_api.dart`、`RemoteOS.Client/lib/features/auth/domain/auth_models.dart`、`RemoteOS.Client/lib/core/auth/auth_service.dart`、`RemoteOS.Client/lib/core/network/remoteos_api.dart`、`RemoteOS.Client/lib/screens/login/login_screen.dart`、`RemoteOS.Client/test/features/auth/remoteos_auth_api_test.dart`、`RemoteOS.Client/pubspec.yaml`、`RemoteOS.Client/pubspec.lock`。

* 协议与行为：登录、刷新、登出都使用 `/api/v1/auth/*` 和 Protocol 的嵌套 `tokens` 契约；共享 REST transport 会附加 bearer token，遇到 401 时仅刷新并重试一次。`ProblemDetails` 的 `detail`/`title`/`type` 被保留为 `RemoteOsApiException`。

* 凭据：服务器地址和用户名仍在 `SharedPreferences` 中；“记住密码”改为 `flutter_secure_storage` 的 OS 凭据存储，偏好文件仅保存 `hasSavedPassword` 标记。旧 profile 的 Base64 `encryptedPassword` 值不再读取或迁移。

* 自动验证：`flutter test test/features/auth/remoteos_auth_api_test.dart` 通过（登录协议、401 刷新重试、密码不落入偏好设置）；使用临时提取的 `libsecret-1-dev` headers 运行 `flutter build linux --debug` 成功生成 `build/linux/x64/debug/bundle/remoteos_client`。依赖升级至 `flutter_secure_storage ^10.0.0`，以避免 9.x 在当前 Clang 的 `-Werror` 编译失败，同时维持与 `bitsdojo_window` 的 Windows `win32` 约束兼容。

* 静态分析：`flutter analyze` 仍因宿主对 Flutter analysis server 的 LSP 输入截断而报 `FormatException: Unexpected end of input`；需在普通终端或 CI 复验。

## FLUTTER-001 验收记录

* 文件：`RemoteOS.Client/lib/main.dart`、`RemoteOS.Client/lib/core/shell/desktop_window_shell.dart`、`RemoteOS.Client/lib/core/runtime/desktop_runtime.dart`、`RemoteOS.Client/lib/core/runtime/startup_failure_app.dart`。

* 平台：Windows 与 Linux runner 已在仓库；Flutter 的自定义无边框窗口设为 1280×800，最小 760×700，包含移动、最小化、最大化、全屏和关闭控制。

* 日志：启动和未捕获 Flutter/Dart 异常会按平台写入用户目录，Linux 使用 `$XDG_STATE_HOME/RemoteOS/logs`（默认 `~/.local/state/RemoteOS/logs`），Windows 使用 `%LOCALAPPDATA%/RemoteOS/logs`；可由 `REMOTEOS_LOG_DIR` 覆盖。目录不可用时回退到 stderr。

* 失败处理：本地化或窗口插件初始化失败时显示可复制错误的启动失败页面，并尝试将异常写入日志。

* 自动验证：`flutter test` 通过；`flutter build linux --debug` 成功生成 `build/linux/x64/debug/bundle/remoteos_client`。

* 静态分析：本环境下 `flutter analyze` 会因 Flutter analysis server 的 LSP 输入被宿主截断而以 `FormatException: Unexpected end of input` 退出；需在普通终端或 CI 复验。

## FLUTTER-014 当前实施记录（Notepad & Settings 对齐 + Explorer 选择模式）

* Avalonia 输入：`Apps/Notepad/NotepadApp.cs`（菜单、撤销重做、查找替换、行号、自动换行、状态栏 Ln/Col、打印、默认编码、reopen/save-with encoding），`Apps/Settings/*.cs` 及对应 Views（侧栏顺序：系统 / 个性化 / 时间和语言 / 网络 / 应用 / 镜像源 / 默认应用 / 开发者；系统页两张卡片：关于 + 账户和工作区；镜像源新增/选择/删除；默认应用 scheme 映射读写到 Workspace preferences），`Apps/Explorer/ExplorerPickerOptions.cs`（openFile/openFiles/saveFile 模式与 suggestedFileName）。

* 对照依据：用户提供的 Settings 主界面截图（系统页）与 Avalonia 源码目录 `E:\riderprojects\RemoteOS\Client\RemoteOS.Client\Apps\Settings`。

* 已完成（Explorer 选择模式/模态框）：`lib/apps/explorer/explorer_picker.dart` 补 `ExplorerPickerMode.openFiles` / `saveFile`，`ExplorerPickerOptions` 加 `suggestedFileName`，新增 `showRemoteMultiFilePicker` / `showRemoteSaveFilePicker`。`lib/apps/explorer/explorer_app.dart` 对应新增 saveFile、multiFile 模式的标题栏、确认按钮与结果返回，保存模式下新建文件同名已有条目可覆盖，仍保留 owner-bound modal 语义。

* 已完成（Notepad 能力对齐）：`lib/apps/notepad/notepad_app.dart` 新增撤销栈 / 重做栈（`_undoStack`、`_redoStack`，Ctrl+Z/Y 绑定）、查找/替换模型（支持大小写敏感、正则；替换单个/全部），文件菜单 + 编辑菜单 + 视图菜单下拉 UI，显示行号 gutter、自动换行切换、状态栏 Ln/Col/Offset + 行/字符计数，查找/替换工具栏（上一、下一、替换、全部替换、关闭），`print` 菜单项（因环境限制显示状态提示不做真实打印）。新建/打开/另存为/切换编码会清空历史，光标位置实时更新。

* 已完成（Settings UI 对齐）：`lib/apps/settings/settings_app.dart` 侧栏 8 项顺序按 Avalonia 重新排序，系统页改为两张卡片（关于：版本 RemoteOS 0.1 / 连接状态 / 服务器；账户和工作区：用户名 / 主机平台 / 工作区 / 设备 / 设备角色 / 上次登录；页标题下方副标题为“RemoteOS 云原生桌面环境”，卡片下方说明“RemoteOS 使用宿主操作系统的用户和权限系统。”）。新增 镜像源（Image Mirrors）页面：可新增 name+endpoint 镜像源、可选择或切换默认、可删除非默认条目；新增 默认应用（Default Apps）页面：支持从 `WorkspacePreferences.defaultApps` 回显、可新增/删除映射、可编辑 scheme/扩展名并在下拉中选择兼容应用；编辑结果通过 `WorkspaceSyncCoordinator.queuePreferences` 写回与同步层一致。Settings 内部 UI 模型：`_AppOptionUi`（const 构造 + 10 个已知应用 + schemes/extensions 列表）、`_DefaultAppMappingUi`（scheme + appId）、`_ImageMirrorUi`（id/name/endpoint/isDefault/isSelected）。依赖 `Platform.operatingSystem`/`Platform.localHostname`（dart:io）填充主机信息。

* 已完成（本地化 key，三语完全对齐）：
  - common：新增 edit/view/undo/redo/cut/paste/select_all/find/replace/word_wrap/line_numbers/previous/next/print。
  - notepad：新增 status.ln_col、status.offset、hint.start_typing、find.find、find.replace_with、find.replace、find.replace_all、find.not_found、found_n_of_m、replace.replaced_one、replace.replaced_all、print.not_available。
  - settings：新增 value.connected / value.not_connected，system.tagline（改为“RemoteOS 云原生桌面环境”）、system.description，完整 image_mirrors.*（description/new_name/new_endpoint/registries/required/added/removed/default/in_use/select/default_selected/selected），完整 default_apps.*（description/add/empty/scheme/application），page.default_apps。
  - 仍保留原有键值兼容性。通过 `jq empty` 校验三语种的 JSON 语法。

* 未实现/刻意保留与 Avalonia 的差距：
  - Notepad：未接入真实打印驱动（菜单项存在但显示状态提示）。
  - Settings：开发者页仅保留原 Flutter 内容，未扩展 Avalonia 中可能存在的更多子项；个性化页中的壁纸选择等沿用现有实现；应用页未做 Avalonia 中“安装大小”“卸载”等本地宿主安装信息；网络页未接入真实网卡数据，仍为原测试连接按钮。
  - Explorer 选择模式：与 RemoteOS Server 的 REST 路径和权限仍复用现有 Explorer 客户端；未新增新的服务端契约。
  - 任务按用户要求“仅确保编译通过、不进行功能测试”执行；未启动真实 RemoteOS Server 进行连接/打开/保存/查找替换等 E2E。

* 命令验证：
  - `flutter analyze lib/apps/notepad/notepad_app.dart lib/apps/settings/settings_app.dart lib/apps/explorer/explorer_app.dart lib/apps/explorer/explorer_picker.dart`：23 条 info/warning，0 error（info 主要是 SDK deprecation 提示如 Radio `groupValue` / `value` / `withOpacity` / `no_leading_underscores_for_local_identifiers` 等；warning 是未使用局部变量和 dead null-aware，均不影响编译）。
  - `flutter build windows --debug`：2026-08-28 成功，产物 `build\windows\x64\runner\Debug\remoteos_client.exe`（exit code 0；此前记载的 ATL 缺失问题未复现，可能因为客户端已装 ATL 组件或插件更新）。

* 风险/遗留：
  - 未做功能测试与 Server E2E；打开/保存/查找替换/镜像源选择/默认应用映射的真实行为需要手动在已登录的 Server 上验证。
  - `Platform.operatingSystem` 返回小写（如 "windows"）；UI 仍直接展示，如需标题化可在后续一轮调整。
  - TextPainter 测量行宽的方向性改为通过 `Directionality.maybeOf(context)` 获得，避免直接枚举 `TextDirection.ltr`（该 SDK 版本下 analyzer 不认 getter）。若后续 Flutter 版本重新暴露该枚举可再简化。

## 后续执行规则

1. 完成每项后，在 Backlog 标注状态、在本文件记录文件/验收/命令/遗留风险。
2. 只有依赖已验收的任务才可标为完成；已有的未验证实现保留为参考，不作为迁移完成依据。
3. 每项至少运行相关单元或组件测试；涉及平台 runner 时至少构建当前可用的平台。

