# 迁移风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| Shell 内部窗口系统 | 高：Flutter 常规 navigation 不能等价 | 优先实现 ManagedWindowHost/WindowService，先验证 z-order、resize、taskbar、fullscreen |
| Modal owner/嵌套链 | 高 | 使用 ownerId + overlay stack；为嵌套和焦点恢复建测试 |
| Terminal (RoyalTerminal + SignalR) | 高 | 先做 transport abstraction，再评估 Flutter terminal emulator |
| 编辑器与 Native WebView | 高 | 建平台 adapter，先做 Windows/Linux 可用性验证 |
| 大量 Tree/Grid、实时图表 | 高 | 虚拟化、限流、性能基准 |
| AXAML 样式 | 中 | 复用 token 和 Palette，控件样式另写；不尝试解析 Selector/Template |
| External App SDK/权限 | 高 | 先盘点 SDK bridge 和 Manifest，再决定 Flutter host contract |
| API/Hub 协议 | 中 | DTO 与 route 原样映射，使用契约测试 |
