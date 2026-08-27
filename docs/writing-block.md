# RemoteOS Avalonia Client → Flutter/Dart 迁移计划与 Codex 执行指南

## 1. 文档目的

本文档用于指导 Codex 对现有 RemoteOS 项目进行客户端迁移分析，并制定后续可执行的 Flutter/Dart 重构计划。

现有项目路径：

```text
/home/nanami/文档/RemoteOS
```

RemoteOS 当前包含：

```text
RemoteOS
├── Avalonia Client
├── .NET Server
├── CLI
├── Examples
└── External Apps
```

本次迁移范围**仅限 Avalonia Client**。

目标是新建一个基于：

```text
Dart
Flutter Desktop
```

实现的 RemoteOS Client。

优先支持：

```text
Windows
Linux
```

macOS 可以作为后续支持目标，但当前迁移阶段不作为主要验收平台。

---

# 2. 核心迁移目标

本次迁移不是重新设计 RemoteOS，也不是开发一个“功能类似”的 Flutter 客户端。

目标是：

> 使用 Flutter/Dart 对现有 Avalonia Client 进行尽可能 1:1 的兼容性重实现。

主要要求：

1. 功能完整一致
2. UI 基本一致
3. 页面结构一致
4. 操作流程一致
5. 自定义 Modal 行为一致
6. Context Menu 行为一致
7. 桌面窗口行为一致
8. 多主题行为一致
9. 多语言行为一致
10. Server API 保持兼容
11. External App 相关客户端能力保持兼容
12. Windows / Linux 桌面操作体验保持一致

对于 Terminal 等高度依赖第三方控件的功能：

> 不要求底层渲染实现完全一致，但功能必须一致，并尽可能保持外围 UI 和交互一致。

---

# 3. 非迁移范围

以下项目本次原则上不迁移：

```text
.NET Server
CLI
Examples
External App Backend
Server API
Server Permission System
Server Business Logic
```

Flutter Client 应主动适配现有 Server。

除非发现现有协议存在 Flutter 无法合理实现的技术限制，否则：

> 不应该为了 Flutter Client 对 Server 进行大规模修改。

---

# 4. 总体迁移原则

迁移优先级：

```text
功能一致
    ↓
交互一致
    ↓
UI 布局一致
    ↓
主题一致
    ↓
多语言一致
    ↓
桌面窗口行为一致
    ↓
代码结构优化
```

禁止为了快速实现 Flutter Client 而：

- 使用 Material 默认风格替换现有 UI
- 删除 Context Menu
- 删除自定义 Modal
- 简化已有功能
- 修改已有操作流程
- 大量重命名 Localization Key
- 大量重命名 Theme Key
- 因为第三方 Flutter Package 不方便而删除功能
- 为迁移方便而大规模修改 Server

---

# 5. 新旧 Client 并存

迁移过程中禁止直接删除 Avalonia Client。

推荐保持类似结构：

```text
RemoteOS/
├── Client/                 # 当前 Avalonia Client
├── Client.Flutter/         # 新 Flutter Client
├── Server/
├── CLI/
├── Examples/
└── ExternalApps/
```

实际目录名称应根据现有 RemoteOS 项目结构决定。

迁移期间 Avalonia Client 是：

> Flutter Client 的功能、UI 和交互参考实现。

每一个 Flutter Feature 都应该能够找到对应的 Avalonia 实现作为迁移依据。

例如：

```text
Avalonia FirewallView
        ↓
Flutter FirewallPage

Avalonia FirewallViewModel
        ↓
Flutter FirewallController

Avalonia AddFirewallRuleModal
        ↓
Flutter FirewallRuleEditorModal
```

---

# 6. Codex 第一阶段任务

第一阶段 Codex **禁止直接开始 Flutter 页面开发**。

首先完整扫描：

```text
/home/nanami/文档/RemoteOS
```

识别其中真正属于 Avalonia Client 的项目和代码。

然后完成：

```text
现状分析
    ↓
Client Inventory
    ↓
Theme 分析
    ↓
Localization 分析
    ↓
Modal 分析
    ↓
Context Menu 分析
    ↓
API 分析
    ↓
控件映射
    ↓
Feature Parity
    ↓
UI Parity
    ↓
迁移风险
    ↓
Migration Plan
```

---

# 7. Client Inventory

Codex 必须扫描实际代码，而不是仅根据目录名称推测功能。

重点检查：

```text
*.axaml
*.cs
View
ViewModel
Window
UserControl
Control
Style
ResourceDictionary
Converter
Behavior
Service
Model
DTO
Request
Response
Command
Localization
Theme
Assets
```

需要识别：

- App 初始化
- MainWindow
- 自定义 Window
- 页面
- 二级页面
- View
- ViewModel
- UserControl
- 自定义 Control
- Dialog
- Modal
- Flyout
- ContextMenu
- Navigation
- Theme
- Styles
- Localization
- Assets
- Icons
- API Service
- DTO
- Terminal
- File Manager
- Process Manager
- Service Manager
- Docker
- Firewall
- Certificate Manager
- Nginx Manager
- Settings
- Login
- Server Connection
- Permission UI
- External App UI
- 其他 Client Feature

生成：

```text
docs/flutter-migration/01-client-inventory.md
```

---

# 8. Window Inventory

列出所有 Avalonia Window。

格式：

| Avalonia Window | 文件 | 用途 | Flutter 方案 | 风险 |
|---|---|---|---|---|

必须区分：

```text
真实 OS Window
内部 Modal
Overlay
Popup
Flyout
Context Menu
```

不能把所有窗口型 UI 都当作 Flutter `showDialog()`。

---

# 9. Page Inventory

列出全部页面。

格式：

| 页面 | View | ViewModel | 功能 | Server API | Flutter Feature |
|---|---|---|---|---|---|

特别注意：

- 隐藏入口
- 设置子页面
- Add 页面
- Edit 页面
- Detail 页面
- 二级页面
- Tab 页面
- Permission 页面
- External App 页面

---

# 10. 自定义桌面 Modal

这是迁移的核心部分之一。

RemoteOS 当前很多：

```text
Add
Edit
Detail
Confirm
Input
Settings
Permission
```

并不是传统系统 Dialog，而是：

> 在 RemoteOS 主窗口内部显示的自定义桌面 Modal。

Codex 必须逐个分析。

生成：

```text
docs/flutter-migration/02-modal-map.md
```

记录：

| Modal | 调用位置 | 打开方式 | 关闭方式 | 尺寸 | 是否可嵌套 | Flutter 方案 |
|---|---|---|---|---|---|---|

需要检查：

- Modal 是否依附 MainWindow
- 是否存在背景遮罩
- 是否阻止背景操作
- 是否可以 ESC 关闭
- 是否可以点击遮罩关闭
- 是否支持多层 Modal
- 是否支持 Modal → Modal
- Focus 行为
- Tab 顺序
- Enter 行为
- Keyboard handling
- Modal 尺寸
- Modal 位置
- 动画
- Loading 状态
- 保存期间是否禁止关闭
- Validation 行为

---

# 11. Flutter Modal 架构

不要简单把所有 Modal 改成：

```dart
showDialog(...)
```

如果现有 Avalonia 使用统一自定义桌面 Modal，应在 Flutter 中设计类似：

```text
ModalHost
ModalManager
ModalController
```

推荐结构：

```text
RemoteOS Main Window
│
├── Shell
│   ├── Navigation
│   └── PageHost
│
├── ContextMenuHost
│
├── ModalHost
│   ├── Modal Layer 1
│   ├── Modal Layer 2
│   └── Modal Layer N
│
└── NotificationHost
```

调用形式可以类似：

```dart
modalManager.open(
  FirewallRuleEditorModal(
    mode: EditorMode.add,
  ),
);
```

这样可以统一控制：

```text
Overlay
Z-Index
Focus
Keyboard
ESC
Animation
Modal Stack
Size
Position
Close Policy
```

---

# 12. Context Menu

RemoteOS 是 Desktop 应用，右键菜单属于正式交互方式，而不是可选功能。

必须完整扫描：

```text
ContextMenu
MenuFlyout
PointerPressed
PointerReleased
RightButton
RightClick
Selection
```

生成：

```text
docs/flutter-migration/03-context-menu-map.md
```

格式：

| 页面 | 控件 | Context Menu | Action | Permission | Flutter 实现 |
|---|---|---|---|---|---|

Flutter 中应该设计统一：

```text
RemoteOSContextMenu
ContextMenuHost
ContextMenuController
```

需要支持：

- 鼠标右键位置
- 自动调整菜单位置
- 屏幕边缘检测
- Disabled Item
- Separator
- Icon
- Shortcut Text
- Sub Menu
- Nested Menu
- Keyboard Navigation
- ESC
- Hover
- Selection
- Theme
- Localization

不能把右键操作全部移动到普通 Button。

---

# 13. Theme 系统迁移

现有 RemoteOS Avalonia Client 已经有特殊 Theme 结构。

迁移时优先级：

```text
直接复用旧 Theme
        ↓
复用旧资源 Key
        ↓
转换资源格式
        ↓
最后才重新设计
```

Codex 首先调查：

- Theme 文件位置
- AXAML 结构
- ResourceDictionary
- DynamicResource
- StaticResource
- Color
- SolidColorBrush
- Font
- Radius
- Thickness
- Border
- ControlTheme
- Setter
- Selector
- ControlTemplate
- Dark / Light
- 用户自定义 Theme
- Theme Runtime Switching
- 外部 Theme 文件

生成：

```text
docs/flutter-migration/04-theme-analysis.md
```

---

# 14. Theme Compatibility Layer

Avalonia 的完整 AXAML Style 不能直接等价于 Flutter Widget。

例如：

```text
Setter
Selector
ControlTemplate
DynamicResource Binding
```

这些属于 Avalonia UI 系统。

但是：

> Theme Resource Key 和 Resource Value 应尽可能复用。

例如旧主题：

```xml
<Color x:Key="AccentColor">
    #0078D4
</Color>
```

Flutter 可以考虑：

```dart
theme.color("AccentColor");
```

或者：

```dart
RemoteTheme.of(context)
    .color("AccentColor");
```

Brush 可以：

```dart
RemoteTheme.of(context)
    .brush("WindowBackgroundBrush");
```

目标是继续使用类似：

```text
AccentColor
WindowBackgroundBrush
NavigationBackgroundBrush
PrimaryTextBrush
SecondaryTextBrush
```

这样的旧 Key，而不是全部重新命名。

---

# 15. Theme 文件直接复用评估

Codex 需要明确研究：

> Flutter 是否能够直接读取现有 Theme 文件。

如果旧 Theme 主要由简单 ResourceDictionary 构成，可以考虑：

```text
AXAML/XML Parser
        ↓
Resource Dictionary
        ↓
RemoteThemeResource
        ↓
Flutter Widget
```

如果存在复杂 Avalonia Style：

```text
Selector
ControlTemplate
Nested Setter
Theme Variant
```

则可以：

```text
资源数据继续复用
控件样式在 Flutter 重建
```

最终可能形成：

```text
Legacy Theme File
       ↓
Theme Parser
       ↓
Theme Compatibility Layer
       ↓
RemoteOS UI Kit
       ↓
Feature UI
```

---

# 16. Localization 多语言

Localization 同样应优先兼容旧结构。

Codex 必须调查：

- 多语言文件位置
- 文件格式
- Key 格式
- Locale
- Fallback
- 参数替换
- Runtime Language Switching
- View 如何读取
- ViewModel 如何读取
- ResourceDictionary
- 是否存在代码生成
- Missing Key 行为

生成：

```text
docs/flutter-migration/05-localization-analysis.md
```

---

# 17. Localization Key 保持兼容

例如原有：

```text
Common.Save
Common.Cancel
Common.Delete

Firewall.AddRule
Firewall.EditRule
Firewall.DeleteRule

FileManager.Open
FileManager.Copy
```

Flutter 应优先继续：

```dart
tr("Common.Save");
```

或者：

```dart
context.l10n.get("Common.Save");
```

而不是直接重新定义：

```dart
saveButtonText
firewallEditButton
fileManagerOpenButton
```

目标：

> 原有 Localization Key 尽可能 100% 保持。

这样 Avalonia Client 与 Flutter Client 在迁移并存期间甚至有机会共用语言资源。

---

# 18. RemoteOS Desktop UI Kit

业务页面迁移前，应该先建立 Flutter RemoteOS Desktop UI Kit。

不要让各页面自己大量使用：

```dart
Container
TextButton
ElevatedButton
AlertDialog
DropdownButton
```

否则会导致 UI 风格快速失控。

建议建立：

```text
RemoteOSButton
RemoteOSIconButton
RemoteOSTextField
RemoteOSTextArea
RemoteOSPasswordField
RemoteOSComboBox
RemoteOSCheckBox
RemoteOSRadioButton
RemoteOSToggle
RemoteOSSlider
RemoteOSTabView
RemoteOSNavigation
RemoteOSDataGrid
RemoteOSTreeView
RemoteOSListView
RemoteOSContextMenu
RemoteOSModal
RemoteOSTooltip
RemoteOSProgress
RemoteOSLoading
RemoteOSEmptyState
RemoteOSErrorState
RemoteOSDivider
RemoteOSCard
RemoteOSPanel
RemoteOSHeader
```

具体控件清单以实际 Avalonia Client 为准。

---

# 19. Avalonia → Flutter 控件映射

生成：

```text
docs/flutter-migration/06-control-mapping.md
```

示例：

| Avalonia | Flutter |
|---|---|
| Grid | Row / Column / Stack / LayoutBuilder |
| StackPanel | Row / Column |
| Border | Container / DecoratedBox |
| TextBlock | Text |
| Button | RemoteOSButton |
| TextBox | RemoteOSTextField |
| ComboBox | RemoteOSComboBox |
| CheckBox | RemoteOSCheckBox |
| ListBox | ListView / RemoteOSListView |
| DataGrid | RemoteOSDataGrid |
| TreeView | RemoteOSTreeView |
| ScrollViewer | ScrollView |
| ContextMenu | RemoteOSContextMenu |
| Flyout | Overlay |
| Dialog | RemoteOSModal |
| Window | Desktop Window Layer |

这里不能机械转换。

必须考虑：

```text
UI
行为
Keyboard
Focus
Selection
Theme
Localization
Context Menu
Desktop Mouse Interaction
```

---

# 20. Window System

分析 Avalonia Client 当前是否使用：

- 自定义标题栏
- Window Drag
- Resize
- Minimize
- Maximize
- Restore
- Close
- FullScreen
- SetSize
- SetPosition
- MinimumSize
- MaximumSize
- Multiple Window
- Secondary Window
- Window State
- AlwaysOnTop

设计统一：

```text
WindowService
```

例如：

```dart
abstract class WindowService {
  Future<void> minimize();

  Future<void> maximize();

  Future<void> restore();

  Future<void> close();

  Future<void> enterFullScreen();

  Future<void> exitFullScreen();

  Future<void> setMinimumSize(...);

  Future<void> setSize(...);

  Future<void> setPosition(...);
}
```

需要注意：

> RemoteOS 内部 Modal 与真实 OS Window 是两个完全不同的概念。

---

# 21. Flutter Multi-Window

如果 Avalonia Client 存在真正的 Secondary Window，需要单独调查当前 Flutter Desktop 多窗口支持情况。

需要分析：

```text
Windows
Linux
```

上的：

- 创建窗口
- 销毁窗口
- 窗口通信
- State
- Position
- Resize
- Focus
- Window Ownership
- Modal Window

如果 Flutter 官方能力仍存在限制，可以使用可靠桌面插件。

但是需要形成抽象层：

```text
WindowService
```

避免业务代码直接依赖某一个插件。

---

# 22. API Layer

Flutter Client 需要继续访问现有 .NET Server。

Codex 应分析当前 Avalonia Client 所有 Server 通信方式：

```text
REST
WebSocket
SignalR
SSE
gRPC
SSH
其他自定义协议
```

生成：

```text
docs/flutter-migration/07-api-map.md
```

格式：

| Avalonia Service | API | Method | Request | Response | Flutter Service |
|---|---|---|---|---|---|

建议 Flutter 形成：

```text
lib/
└── core/
    ├── api/
    ├── auth/
    ├── connection/
    └── networking/
```

---

# 23. DTO / Model

扫描现有：

```text
DTO
Request
Response
Model
Enum
```

生成：

| C# Model | Dart Model | JSON Contract | Migration |
|---|---|---|---|

Flutter 可以评估：

```text
json_serializable
freezed
```

但：

> 不允许为了使用某个 Dart Package 而改变现有 Server JSON Contract。

---

# 24. Authentication / Connection

必须完整迁移：

- Login
- Token
- JWT
- Refresh
- Server Address
- HTTP / HTTPS
- Certificate
- Reconnect
- Connection Failure
- Timeout
- Unauthorized
- Permission Failure
- Session Expiration

如果 Avalonia Client 有统一：

```text
ConnectionService
AuthenticationService
```

Flutter 应建立对应抽象。

---

# 25. Terminal

Terminal 属于特殊组件。

Terminal 内部不要求像素级一致。

优先使用成熟 Flutter/Dart Terminal Emulator，而不是自己实现：

```text
ANSI Parser
VT100
VT220
xterm
```

但以下能力必须保持：

- Server Terminal Session
- Input
- Output
- ANSI
- Color
- Resize
- Copy
- Paste
- Selection
- Keyboard
- Scrollback
- Reconnect
- Session Close
- Terminal Tabs
- Multiple Sessions

同时 Terminal 外围：

```text
Toolbar
Tabs
Context Menu
Theme
Session UI
Loading
Error
```

仍应尽可能保持与 Avalonia Client 一致。

---

# 26. File Manager

文件管理器通常属于迁移高风险模块。

必须分析：

- 文件列表
- 文件夹
- Breadcrumb
- Back
- Forward
- Refresh
- Open
- Upload
- Download
- Rename
- Delete
- Copy
- Move
- Context Menu
- Multi Select
- Sorting
- Hidden Files
- Permissions
- File Editor
- Large Directory
- Progress
- Drag & Drop

并记录所有 Server API 和权限行为。

---

# 27. External Apps

本次不迁移 External App 本身。

但是：

> Flutter Client 仍然必须保留当前 RemoteOS 对 External App 的客户端支持能力。

需要调查：

- App Registration
- App Metadata
- App Icon
- App Navigation
- Permissions
- Backend Bridge
- Client Host
- External App Entry
- App Lifecycle

如果当前 External App UI 与 Avalonia 强绑定，需要将问题明确记录为：

```text
Migration Risk
```

而不是直接删除 External App 功能。

---

# 28. Permission UI

如果 RemoteOS Client 存在：

```text
权限请求
权限不足
提权
External App 权限
危险操作确认
```

必须全部列入迁移范围。

Flutter Client 只负责：

```text
Permission UI
Permission Request
Permission State Display
```

服务端权限逻辑继续由 .NET Server 负责。

---

# 29. Feature Parity Matrix

建立：

```text
docs/flutter-migration/08-feature-parity.md
```

格式：

| Feature | Avalonia | Flutter | Priority | Status | Test |
|---|---|---|---|---|---|

Feature 必须从实际项目代码扫描得出。

例如可能包含：

```text
Login
Server Connect
Reconnect

Dashboard

File Browser
File Upload
File Download
File Rename
File Delete
File Move
File Copy
File Context Menu

Terminal

Process List
Process Detail
Process Kill

Service List
Service Start
Service Stop
Service Restart

Docker

Firewall

Certificate

Nginx

Settings

Theme

Localization

External Apps

Permission Prompt
```

但不能只使用上述列表。

最终要求：

> Feature Parity 尽可能达到 100%。

无法迁移的功能必须明确写：

```text
Known Platform Limitation
```

或：

```text
Not Applicable
```

并说明原因。

---

# 30. UI Parity Matrix

生成：

```text
docs/flutter-migration/09-ui-parity.md
```

格式：

| 页面 | Layout | Theme | Modal | Context Menu | Keyboard | 状态 |
|---|---|---|---|---|---|---|

逐页检查：

```text
布局
间距
字体
颜色
Navigation
Header
Toolbar
Button
Input
Table
Tree
Modal
Context Menu
Loading
Error
Empty
Hover
Selected
Disabled
Focus
```

---

# 31. Desktop Interaction Contract

为了防止迁移后“看起来差不多，但操作已经不一样”，建议建立：

```text
docs/flutter-migration/10-interaction-contract.md
```

每个页面记录：

```text
Window Minimum Size

Navigation Width

Header Height

Default Padding

Button Height

Input Height

Modal Width

Modal Height

Double Click

Right Click

ESC

Enter

Tab

Ctrl+C

Ctrl+V

Ctrl+A

Delete

F2

Loading

Error

Empty State

Selection

Multi Selection
```

实际内容以原 Avalonia Client 行为为准。

---

# 32. Flutter 推荐目录

最终架构需要根据 RemoteOS 实际结构决定。

建议优先考虑：

```text
Client.Flutter/
├── lib/
│   ├── app/
│   │
│   ├── core/
│   │   ├── api/
│   │   ├── auth/
│   │   ├── connection/
│   │   ├── localization/
│   │   ├── theme/
│   │   ├── window/
│   │   ├── modal/
│   │   ├── context_menu/
│   │   ├── routing/
│   │   └── permissions/
│   │
│   ├── ui/
│   │   ├── controls/
│   │   ├── layouts/
│   │   ├── overlays/
│   │   └── desktop/
│   │
│   └── features/
│       ├── dashboard/
│       ├── files/
│       ├── terminal/
│       ├── processes/
│       ├── services/
│       ├── docker/
│       ├── firewall/
│       ├── certificate/
│       ├── nginx/
│       ├── settings/
│       └── external_apps/
│
├── assets/
├── test/
└── integration_test/
```

不要为了追求形式而立即采用非常复杂的 Clean Architecture。

优先目标：

```text
清晰
易维护
Feature Isolation
UI Consistency
API Isolation
Desktop Friendly
```

---

# 33. State Management

Codex 必须先分析现有 Avalonia Client：

```text
ViewModel
ObservableProperty
Command
Service
Event
Messenger
MessageBus
```

再决定 Flutter 状态管理方式。

可以评估：

```text
Riverpod
Provider
Bloc
ChangeNotifier
ValueNotifier
```

选择标准：

- Desktop Client 是否容易维护
- 生命周期是否清晰
- 是否容易处理异步 Server 请求
- 是否适合大型 Feature
- 是否会增加不必要 Boilerplate

不要因为迁移到 Flutter 就把简单 ViewModel 变成过度复杂架构。

---

# 34. 推荐迁移阶段

## Phase 0 — Avalonia Client Freeze

完成：

```text
Inventory
Feature Map
Window Map
Modal Map
Context Menu Map
Theme Map
Localization Map
API Map
```

此阶段禁止正式迁移业务功能。

---

# 35. Phase 1 — Flutter Desktop Skeleton

建立：

```text
Flutter Desktop Project

Windows Runner
Linux Runner

Main Entry

Basic Dependency Injection

Logging

Configuration

Error Handling
```

确保：

```text
Windows build
Linux build
```

都可以运行。

---

# 36. Phase 2 — Core Infrastructure

优先迁移：

```text
API
Authentication
Connection
Routing
Theme
Localization
Window
Modal
Context Menu
Permission Infrastructure
```

此阶段仍不急于迁移复杂页面。

---

# 37. Phase 3 — RemoteOS Desktop UI Kit

建立核心 UI：

```text
Button
Input
ComboBox
Checkbox
Toggle
Tab
Navigation
Panel
List
DataGrid
Tree
Modal
Context Menu
Tooltip
Loading
Error
Empty State
```

所有控件：

```text
Theme Compatible
Localization Compatible
Keyboard Friendly
Desktop Friendly
```

---

# 38. Phase 4 — Application Shell

重建：

```text
MainWindow
Custom TitleBar
Navigation
PageHost
Status Area
ModalHost
ContextMenuHost
NotificationHost
```

这一阶段需要尽量达到 Avalonia Shell 的视觉一致性。

---

# 39. Phase 5 — 简单 Feature

优先迁移逻辑相对简单的模块。

实际顺序由扫描结果决定。

可以优先选择：

```text
Settings
简单信息页面
简单列表页面
```

作为架构验证。

---

# 40. Phase 6 — 中等复杂 Feature

例如：

```text
Process
Service
Firewall
Certificate
Nginx
Docker
```

具体依项目实际情况调整。

---

# 41. Phase 7 — 高复杂 Feature

重点处理：

```text
File Manager
Terminal
复杂 DataGrid
Tree
大型实时数据
```

这些模块需要单独性能测试。

---

# 42. Phase 8 — External App Integration

恢复 External App：

```text
App Discovery
App Metadata
Navigation
Permissions
Bridge
Host
```

---

# 43. Phase 9 — Feature Parity

逐项检查：

```text
07/08 Feature Parity Matrix
```

所有项目必须最终成为：

```text
Completed
```

或者明确：

```text
Platform Limitation
Not Applicable
```

---

# 44. Phase 10 — UI Parity

通过 Avalonia 与 Flutter 并排验证：

```text
Page
Modal
Context Menu
Navigation
Theme
Localization
Keyboard
Window
```

修复视觉和行为差异。

---

# 45. Phase 11 — Performance

重点测试：

```text
大量文件
大型目录
大量 Process
大量 Service
Docker 大型列表
Terminal 高频输出
大量日志
DataGrid
Tree
快速页面切换
Modal Stack
Context Menu
Theme Switching
Language Switching
```

避免：

- 页面明显掉帧
- 高频数据更新导致整个页面 rebuild
- Terminal 输入延迟
- 大列表卡顿
- 内存持续增长

---

# 46. Codex Task 拆分

不要让 Codex 一次执行：

```text
迁移整个 RemoteOS Client
```

应该把任务拆成独立编号。

例如：

```text
FLUTTER-001
Flutter Desktop Skeleton

FLUTTER-002
Theme Compatibility Layer

FLUTTER-003
Localization Compatibility Layer

FLUTTER-004
Window Service

FLUTTER-005
Modal Host

FLUTTER-006
Context Menu Host

FLUTTER-007
RemoteOS Button

FLUTTER-008
RemoteOS TextField

FLUTTER-009
RemoteOS ComboBox

FLUTTER-010
RemoteOS DataGrid

FLUTTER-011
RemoteOS TreeView

FLUTTER-012
Application Shell

...
```

---

# 47. 每一个 Codex Task 格式

每个 Task 至少包含：

```text
Task ID

Goal

Avalonia Reference

Relevant Files

Dependencies

Implementation Requirements

Behavior Requirements

UI Requirements

Acceptance Criteria

Tests

Risks
```

例如：

```text
FLUTTER-005

Goal:
实现 RemoteOS Desktop ModalHost。

Avalonia Reference:
扫描当前 Avalonia Client 所有自定义 Modal 实现。

Dependencies:
Theme
Localization
Overlay

Requirements:
支持 Overlay。
支持 ESC。
支持多层 Modal。
支持 Focus。
支持 Modal Size。
支持 Modal Result。
支持 Loading。
支持 Validation。

Acceptance:
能够重现 Avalonia Client Add/Edit Modal 行为。
```

---

# 48. Migration Acceptance Criteria

整个 Flutter Client 迁移完成至少满足以下条件。

## Functionality

现有 Avalonia Client 的所有正式功能在 Flutter 中都有对应实现。

---

## UI

主要页面：

```text
Layout
Navigation
Spacing
Controls
Theme
Typography
```

与 Avalonia Client 基本一致。

---

## Modal

已有：

```text
Add
Edit
Detail
Confirm
Input
Permission
```

等 Modal 的：

```text
打开
关闭
Overlay
Focus
Keyboard
Size
Position
Layer
Validation
Loading
```

行为保持一致。

---

## Context Menu

现有右键操作全部保留。

---

## Theme

Theme 切换行为保持一致。

旧 Theme Key 尽可能继续复用。

---

## Localization

旧 Localization Key 尽可能 100% 复用。

---

## Server

Flutter Client 可以继续使用现有 .NET Server。

不要求 Server 为 Flutter 进行大规模重构。

---

## Windows

核心功能完整。

---

## Linux

核心功能完整。

---

## Terminal

功能完整。

终端 Emulator 内部实现可以不同。

---

## Performance

不能出现明显：

```text
页面卡顿
大型列表卡顿
Terminal 延迟
大量 rebuild
文件列表阻塞 UI
内存异常增长
```

---

# 49. 禁止事项

Codex 不允许：

- 一开始删除 Avalonia Client
- 一开始就迁移所有业务 Feature
- 未完成 Inventory 就开始大规模实现
- 修改 Server 来迎合 Flutter
- 把 UI 改成默认 Material Design
- 把所有 Modal 改成 AlertDialog
- 删除 Context Menu
- 删除 Keyboard Interaction
- 删除 External App 支持
- 简化已有功能
- 重新设计已有页面
- 大规模修改 Localization Key
- 大规模修改 Theme Key
- 因为 Flutter Package 不支持就静默删除功能
- 一次提交数十个未验证 Feature
- 在没有 Parity Matrix 的情况下宣称迁移完成

---

# 50. Codex 第一轮执行 Prompt

下面内容可以直接交给 Codex。

---

## RemoteOS Avalonia Client → Flutter/Dart Migration Analysis

项目路径：

```text
/home/nanami/文档/RemoteOS
```

你的任务是为 RemoteOS 创建一份完整的 Avalonia Client → Flutter/Dart 迁移计划。

### 项目范围

当前 RemoteOS 包含：

```text
Avalonia Client
.NET Server
CLI
Examples
External Apps
```

本次只迁移：

```text
Avalonia Client
```

以下内容原则上保持不变：

```text
.NET Server
CLI
Server API
Server Business Logic
External App Backend
Examples 中与 Client 无关的部分
```

目标是创建新的 Flutter Desktop Client。

优先平台：

```text
Windows
Linux
```

### 核心目标

这不是一次 UI redesign。

目标是：

> 使用 Flutter/Dart 尽可能 1:1 重建当前 Avalonia Client。

优先保证：

```text
Feature Parity
Interaction Parity
UI Parity
Theme Parity
Localization Parity
Desktop Behavior Parity
```

特别需要保持：

```text
自定义桌面 Modal
Context Menu
Keyboard Interaction
Window Behavior
Theme
Localization
External App Client Integration
```

Terminal 等高度依赖第三方控件的模块可以更换底层实现，但功能必须完整。

### 第一阶段禁止修改代码

本轮：

> 不要开始正式实现 Flutter Client。

首先完整扫描 RemoteOS 项目。

不要仅根据文件名推断。

需要阅读：

```text
AXAML
C#
ViewModel
Service
Control
Style
ResourceDictionary
Converter
Behavior
Localization
Theme
Model
DTO
API
```

找到真正属于 Avalonia Client 的全部代码。

### 必须生成以下文档

创建：

```text
docs/flutter-migration/
```

并生成：

```text
00-overview.md

01-client-inventory.md

02-modal-map.md

03-context-menu-map.md

04-theme-analysis.md

05-localization-analysis.md

06-control-mapping.md

07-api-map.md

08-feature-parity.md

09-ui-parity.md

10-interaction-contract.md

11-risks.md

12-migration-plan.md

13-task-backlog.md
```

### Client Inventory

扫描并统计：

```text
Window
Page
View
ViewModel
UserControl
Custom Control
Modal
Dialog
Flyout
Context Menu
Navigation
Theme
Localization
Assets
API Service
DTO
Model
Terminal
File Manager
Process
Service
Docker
Firewall
Certificate
Nginx
Settings
External App
Permission UI
```

以实际项目代码为准。

### Modal

重点调查所有 Add/Edit/Detail/Confirm/Input 等 UI。

判断它们是否属于：

```text
OS Window
Dialog
MainWindow 内部自定义 Modal
Overlay
Popup
```

不要假定 Flutter `showDialog()` 就是正确迁移方式。

如果当前 RemoteOS 使用内部 Desktop Modal Stack，则设计 Flutter：

```text
ModalHost
ModalManager
Modal Stack
```

保持原有行为。

### Context Menu

扫描所有右键菜单。

不要删除或改成普通按钮。

设计统一：

```text
RemoteOSContextMenu
ContextMenuHost
```

### Theme

分析现有：

```text
ResourceDictionary
DynamicResource
StaticResource
Brush
Color
Font
ControlTheme
Setter
Selector
ControlTemplate
ThemeVariant
```

重点回答：

> Flutter 是否能够直接使用或解析现有 RemoteOS Theme 文件？

如果不能完全复用：

> 设计 Theme Compatibility Layer。

尽可能继续使用旧 Theme Key。

### Localization

分析现有 Localization 文件格式和读取方式。

重点回答：

> Flutter 是否可以直接读取当前 RemoteOS Localization 文件？

如果不能：

> 保留所有旧 Key，只转换 Resource Format。

不要无必要地重命名 Localization Key。

### API

分析当前 Client 与 .NET Server 的全部通信。

列出：

```text
REST
WebSocket
SignalR
SSE
gRPC
Custom Protocol
```

以及：

```text
Service
Endpoint
Request
Response
Authentication
Error
```

Flutter 优先兼容当前 Server API。

### Flutter Architecture

基于实际代码提出目录架构。

不要机械套用复杂 Clean Architecture。

优先：

```text
清晰
Feature Isolation
UI Reuse
API Isolation
Desktop Friendly
```

### Feature Parity

生成完整 Feature Matrix。

最终所有正式 Avalonia Feature 都必须找到 Flutter 对应项。

### UI Parity

逐页建立 UI 对照。

记录：

```text
Layout
Theme
Modal
Context Menu
Keyboard
Loading
Error
Empty
```

### Migration Plan

把迁移拆成多个 Phase。

至少考虑：

```text
Phase 0
Inventory

Phase 1
Flutter Desktop Skeleton

Phase 2
Core Infrastructure

Phase 3
RemoteOS Desktop UI Kit

Phase 4
Application Shell

Phase 5
Simple Features

Phase 6
Complex Features

Phase 7
File Manager / Terminal

Phase 8
External App Integration

Phase 9
Feature Parity

Phase 10
UI Parity

Phase 11
Performance / Windows / Linux Validation
```

但最终 Phase 需要根据实际扫描结果调整。

### Task Backlog

拆分为：

```text
FLUTTER-001
FLUTTER-002
FLUTTER-003
...
```

每项包含：

```text
Goal
Avalonia Reference
Files
Dependencies
Implementation
Acceptance Criteria
Risk
Tests
```

### 本轮结束条件

分析结束后输出：

1. Avalonia Client 总体规模
2. Window 数量
3. 页面数量
4. Modal 数量
5. Context Menu 数量
6. 自定义 Control 数量
7. API Service 数量
8. Theme 兼容性结论
9. Localization 兼容性结论
10. Window / Multi-window 风险
11. Terminal 风险
12. External App 风险
13. 推荐迁移顺序
14. 第一批应该执行的 FLUTTER Task

然后停止。

> 本轮禁止开始正式 Flutter 业务 Feature 迁移。

---

# 51. Codex 第二轮建议 Prompt

第一轮分析完成后，不要直接说：

```text
按照计划全部迁移。
```

建议第二轮只实现基础设施：

```text
请读取：

docs/flutter-migration/

中的全部迁移分析结果。

开始执行 Flutter Migration Plan。

本轮严格限制为基础设施阶段。

只允许完成：

1. Flutter Desktop Project Skeleton
2. Core Application Architecture
3. Theme Compatibility Layer
4. Localization Compatibility Layer
5. WindowService
6. ModalHost / ModalManager
7. ContextMenuHost / ContextMenuManager
8. Routing Infrastructure
9. API Infrastructure 基础
10. 基础测试设施

不要迁移任何正式业务 Feature。

要求：

- 继续以 Avalonia Client 为行为参考。
- 不修改 .NET Server，除非存在阻塞问题且必须先记录原因。
- 不删除 Avalonia Client。
- 不重新设计 UI。
- 不使用默认 Material UI 替代 RemoteOS UI。

完成后：

更新 docs/flutter-migration 中对应：

Task Status
Risk
Feature Parity
Migration Plan

并总结本轮实际修改。
```

---

# 52. Codex 第三轮建议

第三轮实现：

```text
RemoteOS Desktop UI Kit
```

重点：

```text
RemoteOSButton
RemoteOSTextField
RemoteOSComboBox
RemoteOSCheckBox
RemoteOSToggle
RemoteOSTab
RemoteOSNavigation
RemoteOSDataGrid
RemoteOSTreeView
RemoteOSModal
RemoteOSContextMenu
RemoteOSTooltip
```

UI Kit 完成后再开始 MainWindow 和业务页面。

---

# 53. 最终建议

整个 RemoteOS Flutter 迁移应按照：

```text
分析现有 Avalonia
        ↓
建立兼容层
        ↓
建立 Desktop UI Kit
        ↓
重建 Shell
        ↓
逐 Feature 迁移
        ↓
Feature Parity
        ↓
UI / Interaction Parity
        ↓
Windows + Linux 验证
```

执行。

其中最应该优先稳定下来的四个系统是：

```text
Theme
Localization
Modal
Context Menu
```

因为它们属于横跨整个 RemoteOS Client 的基础能力。

如果在迁移大量业务页面后才重新设计这些系统，将会造成大量重复修改。

因此整个迁移应该被定义为：

> RemoteOS Avalonia Client → Flutter Desktop 的兼容性重实现。

在 Feature Parity 和 UI Parity 达到目标之前，不建议同步进行大规模 UI redesign。