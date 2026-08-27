# Server API 映射

## 通信

客户端由 `RemoteOsClient`、`AuthenticatedHttpHandler` 与多项 `Remote*Client` 使用 REST；认证为 login/refresh/logout/me。Terminal 使用 `SignalRTerminalTransport` / `TerminalHubConnection`，Task Manager 使用 `PerformanceStream`，Guardian 日志也使用 Hub。协议常量和 DTO 在 `Shared/RemoteOS.Protocol`，必须作为 Flutter 的 JSON 契约来源。

| Feature | REST 路由组 | Flutter 服务 |
|---|---|---|
| Auth / Workspace / Settings | Auth、Workspace、AppSettings、Capabilities | auth、workspace、settings |
| Explorer | Files | file_service |
| Browser | Browser | browser_service |
| Docker | Docker | docker_service |
| Git | Git | git_service |
| Firewall | Firewall | firewall_service |
| Certificates | Certificates | certificate_service |
| Web Servers | WebServers | web_server_service |
| Tunnels | Tunnels | tunnel_service |
| Task Manager | SystemMonitor + Performance Hub | system_monitor_service |
| Terminal | Workspace settings + Terminal Hub | terminal_transport |
| Guardian | ProcessGuardian + GuardianLogs Hub | guardian_service |

全部路由统一为 `/api/v1/...`（由 `RemoteOsEndpoints.ApiVersionPrefix` 提供）。实现前从相同 Protocol DTO 转写 Dart model；不得改动字段、HTTP method、错误问题详情或授权语义。
