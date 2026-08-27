# RemoteOS Client

RemoteOS 的 Flutter 桌面客户端，当前支持 Windows 与 Linux。

## 调试运行

先进入客户端目录并获取依赖：

```bash
cd RemoteOS.Client
flutter pub get
```

### 更新flutter软件包版本
```bash
flutter pub upgrade

升级包
# 1. 先查看哪些包被什么约束卡住
flutter pub outdated

# 2. 预览一次“大版本升级”会改什么，不落盘
flutter pub upgrade --major-versions --dry-run

# 3. 确认后执行；它会更新 pubspec.yaml 和 pubspec.lock
flutter pub upgrade --major-versions

# 4. 格式化、生成代码并验证
dart format .
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

### Windows

安装 [Flutter 的 Windows 桌面开发依赖](https://docs.flutter.dev/platform-integration/windows/building)，包括 Visual Studio 的 **Desktop development with C++** 工作负载。确认 `flutter doctor` 中的 Windows 工具链状态正常后，运行：

```powershell
flutter clean
flutter pub get
flutter run -d windows
```

构建调试包：

```powershell
flutter build windows --debug
```

生成的可执行文件位于 `build\windows\x64\runner\Debug\remoteos_client.exe`。

### Linux（Ubuntu / Debian）

安装 Linux 桌面构建依赖：

```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

确认 `flutter doctor` 中的 Linux 工具链状态正常后，运行：

```bash
flutter run -d linux
```

构建调试包：

```bash
flutter build linux --debug
```

生成的应用目录位于 `build/linux/x64/debug/bundle/`。

## 常用检查

```bash
flutter analyze
flutter test
```
