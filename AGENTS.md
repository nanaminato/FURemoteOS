Flutter architecture rules

1. 单个 Dart 文件原则上不得超过 500 行。
2. Widget build() 原则上不得超过 100 行。
3. 页面文件只负责布局组合，不实现业务逻辑。
4. Dialog 必须放入独立 dialogs/ 文件夹。
5. ContextMenu 必须放入独立 menus/ 文件夹。
6. 复杂 Widget 必须拆分到 widgets/。
7. 网络请求不得直接出现在 Widget 中。
8. 页面状态必须由 Controller/ViewModel 管理。
9. 一个 Widget 文件只负责一个明确 UI 功能。
10. 禁止为了“少创建文件”而创建超大 Widget。