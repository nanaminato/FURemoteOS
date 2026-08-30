# Flutter application runtime and external `.roapp` packages

The Flutter shell now treats an application as a manifest-driven runtime
component, not an entry that opens a widget directly.

## Scope

`ApplicationManifest` declares a stable package id, instance policy, client
platforms, server requirements and externally routable URI schemes.
`ApplicationRuntime` is Shell-owned and performs URI validation, candidate
selection, compatibility evaluation and primary-window reuse before a widget
is created.

`remoteos://` remains reserved to first-party routes. External schemes must be
declared by a non-reserved manifest scheme and can only be routed after a
declarative route matcher accepts the validated URI. The initial result set is
`activated`, `invalidUri`, `routeNotFound`, `noHandler`,
`handlerSelectionRequired` and `unavailable`.

## Flutter `.roapp` model

Flutter desktop release builds use Dart AOT and cannot safely load arbitrary
Dart source or libraries from a ZIP package. The first Flutter `.roapp` model
is therefore **declarative/content-only**:

```text
.roapp ZIP
  manifest.json
  assets/**
       ↓
validated package catalog
       ↓
precompiled, capability-limited Flutter adapter
```

The Help Center adapter is the reference example. Its manifest identity is
`com.remoteos.example.help-center`; it is single-window and accepts only
`help://guide/docker/install` and `help://guide/docker/uninstall`. It keeps
documentation local, does not receive host paths or a service locator, and
updates language from the Shell locale.

Arbitrary executable extensions, if ever required, must be independently
compiled processes behind a versioned IPC/capability protocol. They must not
be treated as Dart plugin code.

## Compatibility

Before opening a server-dependent package, the runtime checks client platform,
then the server descriptor returned by login (platform and capabilities), then
the capability list. The server descriptor is never inferred from the client
platform or user profile. The current initial implementation carries the
typed descriptor through the auth session; host-owned unavailable UI is the
next Shell presentation increment.
