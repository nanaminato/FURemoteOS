# Theme 分析

主题基础位于 `Framework/RemoteOS.UI/Themes/RemoteOSTheme.axaml`、`Styles.axaml`、`Tokens/TokenContract.axaml`；客户端运行时逻辑为 `Services/Theming/ThemeService.cs`。Palette 来自共享协议 `ThemePaletteDefaults`，按 Light/Dark/System 与用户 `ThemePreferencesDto` 解析后写入 Avalonia ResourceDictionary。

资源是稳定语义 Key：`AppBackground`、`Surface`、`TextPrimary`、`Accent`、`Danger`、`Taskbar`、`WindowTitleBar`、`OverlayScrim`、Desktop icon 与 Chart 系列（Color/Brush 成对），另有 `ControlHeight=32`、`ControlPadding=14,6`、`ContentFont`、各类 CornerRadius。

Flutter 不能直接复用 Avalonia Selector、Setter 或 ControlTemplate；但可直接复用 Protocol Palette DTO、Key 名与 AXAML token 契约。建议：Dart parser/DTO → `RemoteTheme`（按 Key 查 color/brush/metric）→ UI Kit。Styles 在 Flutter 控件层重建，保留运行时 Light/Dark/System 与自定义 palette。
