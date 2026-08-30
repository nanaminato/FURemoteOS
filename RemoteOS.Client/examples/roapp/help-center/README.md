# Help Center `.roapp` example

This manifest is a Flutter-native external application example. A production
`.roapp` archive contains this `manifest.json` and documentation assets. The
Shell validates the manifest and binds its `adapter` to a precompiled,
capability-limited Flutter adapter; it does not execute Dart supplied by the
archive.

Supported deep links:

```text
help://guide/docker/install?lang=en
help://guide/docker/uninstall?lang=zh-CN
```

The installed adapter has a single managed window. A second link navigates the
existing window, restores it if necessary, and focuses it.
