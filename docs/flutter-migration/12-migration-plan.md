# 迁移计划

1. **Phase 0（完成）**：源码扫描、本文档基线；不迁移业务。
2. **Phase 1**：Flutter desktop skeleton，Windows/Linux 构建、日志、配置、错误处理。
3. **Phase 2**：Auth/API/SignalR、Localization JSON loader、Theme palette、WindowLayout、权限。
4. **Phase 3**：ManagedWindowHost、WindowService、ModalManager、ContextMenuHost；这是 Shell 的前置条件。
5. **Phase 4**：RemoteOS desktop UI Kit 与 MainWindow/DesktopShell，先完成视觉与交互验证。
6. **Phase 5**：Settings、Welcome、Explorer 及简单 viewer/editor，验证框架。
7. **Phase 6**：Docker、Firewall、Certificates、Web Servers、Tunnels、Git、Guardian、Port forwarding。
8. **Phase 7**：Terminal、Task Manager、CodeEditor、Browser 等高复杂能力。
9. **Phase 8**：External App / developer / installer integration。
10. **Phase 9**：Feature/UI/interaction parity 与 Windows/Linux 性能验证。

任何 Phase 前必须先完成其依赖任务和对应对照测试；不得以 Material 重设计代替兼容实现。
