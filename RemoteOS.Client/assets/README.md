# RemoteOS.Client assets

Place app icons, images, and other assets here. The folders referenced by
`pubspec.yaml`:

```
assets/
  ├── icons/        ← app tray / window icons
  ├── images/       ← wallpapers, welcome images, logos
  └── translations/ ← en-US.json, zh-CN.json, ja-JP (already populated)
```

At startup, the desktop shell looks for `assets/images/wallpaper.png` to use as
the default wallpaper. If missing, a gradient fallback is drawn.
