# Icon assets

Place 16x16 .. 256x256 .png icons here, especially:
  - app_icon.png          — used in start menu, taskbar, about dialogs
  - tray_icon.png         — system tray icon (if tray plugin enabled)
  - *.png                 — any app-specific icons referenced from Flutter code.

For the Windows executable, the build pipeline uses
`windows/runner/app_icon.ico` (multi-size .ico file).
