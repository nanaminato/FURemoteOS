# Desktop Interaction Contract

| 项目 | Avalonia 基准 | Flutter 验收 |
|---|---|---|
| 主窗口 | 无 decorations；最小 800×520；启动最大化 | 等效 |
| 顶部标题栏 | 34px；手动 drag/min/max/close | 等效 |
| Shell 窗口 | Canvas 管理、Z-order、active window、taskbar toggle | 等效 |
| Shell Modal | 遮罩整个 host；点击遮罩聚焦 Dialog | 等效 |
| 应用 Modal | 遮罩 owner；自动居中和尺寸 clamp；支持嵌套 | 等效 |
| Window 行为 | drag、8 边 resize、minimize、maximize、restore、fullscreen | 等效 |
| 右键 | Explorer/Desktop/Git/Terminal 都保留 Context Menu | 等效 |
| 状态持久化 | 窗口尺寸与 workspace 偏好同步/恢复 | 等效 |

尚需在实际运行 Avalonia 客户端时补录 Enter、ESC、Tab、快捷键、双击与多选的逐控件行为；当前源码并未保证所有控件一致。
