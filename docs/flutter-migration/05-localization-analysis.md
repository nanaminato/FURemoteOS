# Localization 分析

语言文件可直接复用：`Client/RemoteOS.Client/Localization/{en-US,ja-JP,zh-CN}/*.json`，每语言 26 个功能分片（common、shell、login、explorer、docker、git_client、terminal 等）。每份含 culture、displayName、sortOrder、`strings` 键值表。

`LocalizationService` 递归加载并按 culture 合并分片；key 重复视为错误。语言不存在时优先中性语言再回退 `en-US`；缺失翻译回退英语；运行时由 `ShellSettings.Language` 触发 `LanguageChanged`。`LocExtension` 供 AXAML，`LocalizedText.Get/Format` 供 ViewModel。

Flutter 应复制 JSON 原样到 assets，按相同合并、fallback 和缺失策略实现 `tr(key)` / `trFormat(key,args)`，不迁移为 ARB 或重命名 Key。
