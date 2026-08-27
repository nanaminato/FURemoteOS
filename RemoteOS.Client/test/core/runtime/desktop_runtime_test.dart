import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/core/runtime/desktop_runtime.dart';

void main() {
  test('runtime logger writes ordered startup diagnostics', () async {
    final directory =
        await Directory.systemTemp.createTemp('remoteos-runtime-');
    addTearDown(() => directory.delete(recursive: true));

    final runtime = await DesktopRuntime.initialize(logDirectory: directory);
    await runtime.log.info('first event');
    await runtime.log.error('second event', StackTrace.empty);

    final contents =
        await File('${directory.path}${Platform.pathSeparator}remoteos.log')
            .readAsString();
    expect(contents, contains('[INFO] RemoteOS client startup.'));
    expect(contents, contains('[INFO] first event'));
    expect(contents, contains('[ERROR] second event'));
    expect(contents.indexOf('first event'),
        lessThan(contents.indexOf('second event')));
  });

  test('Linux-style environments use XDG state logs', () {
    // Platform-specific roots are selected by the host OS; this verifies the
    // portable XDG branch used by Linux CI and normal Linux launches.
    if (!Platform.isLinux) return;
    final directory = DesktopRuntime.defaultLogDirectory({
      'XDG_STATE_HOME': '/tmp/remoteos-state',
    });
    expect(directory.path, endsWith('/tmp/remoteos-state/RemoteOS/logs'));
  });

  test('REMOTEOS_LOG_DIR overrides the platform log location', () {
    final directory = DesktopRuntime.defaultLogDirectory({
      'REMOTEOS_LOG_DIR': '/tmp/remoteos-custom-log',
    });
    expect(directory.path, '/tmp/remoteos-custom-log');
  });
}
