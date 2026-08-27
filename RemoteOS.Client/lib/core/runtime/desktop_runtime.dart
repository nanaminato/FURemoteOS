import 'dart:async';
import 'dart:io';

/// Process-level facilities needed before the Flutter widget tree exists.
///
/// This intentionally has no dependency on Flutter.  It keeps startup logging
/// and filesystem choices usable from both the desktop runners and tests.
class DesktopRuntime {
  DesktopRuntime._(this.log);

  final RuntimeLog log;

  /// Creates the per-user log directory without failing application startup
  /// when the directory is unavailable.  In that case messages still go to
  /// stderr, which is visible from `flutter run` and desktop launchers.
  static Future<DesktopRuntime> initialize({
    Map<String, String>? environment,
    Directory? logDirectory,
  }) async {
    final directory = logDirectory ?? defaultLogDirectory(environment);
    final log = RuntimeLog(
        File('${directory.path}${Platform.pathSeparator}remoteos.log'));
    await log.initialize();
    await log.info('RemoteOS client startup.');
    return DesktopRuntime._(log);
  }

  static Directory defaultLogDirectory([Map<String, String>? environment]) {
    final values = environment ?? Platform.environment;
    final override = values['REMOTEOS_LOG_DIR'];
    if (override != null && override.trim().isNotEmpty) {
      return Directory(override.trim());
    }
    final separator = Platform.pathSeparator;
    if (Platform.isWindows) {
      final root = values['LOCALAPPDATA'] ?? values['APPDATA'] ?? '.';
      return Directory('$root${separator}RemoteOS${separator}logs');
    }
    if (Platform.isMacOS) {
      final root = values['HOME'] ?? '.';
      return Directory(
          '$root${separator}Library${separator}Logs${separator}RemoteOS');
    }
    final configRoot = values['XDG_STATE_HOME'] ??
        '${values['HOME'] ?? '.'}${separator}.local${separator}state';
    return Directory('$configRoot${separator}RemoteOS${separator}logs');
  }
}

/// A small ordered file logger for failures before application services exist.
class RuntimeLog {
  RuntimeLog(this._file);

  final File _file;
  Future<void> _pending = Future.value();
  bool _available = false;

  Future<void> initialize() async {
    try {
      await _file.parent.create(recursive: true);
      _available = true;
    } on FileSystemException catch (error) {
      stderr.writeln('RemoteOS could not create its log directory: $error');
    }
  }

  Future<void> info(String message) => _write('INFO', message);

  Future<void> error(Object error, StackTrace stackTrace) =>
      _write('ERROR', '$error\n$stackTrace');

  Future<void> _write(String level, String message) {
    final line =
        '${DateTime.now().toUtc().toIso8601String()} [$level] $message\n';
    _pending = _pending.then((_) async {
      stderr.write(line);
      if (!_available) return;
      try {
        await _file.writeAsString(line, mode: FileMode.append, flush: true);
      } on FileSystemException catch (error) {
        stderr.writeln('RemoteOS could not write its log: $error');
        _available = false;
      }
    });
    return _pending;
  }
}
