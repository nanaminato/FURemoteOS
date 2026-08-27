# Translation bundles

Each feature owns a small translation bundle for every supported locale:

- `shared`: reusable controls and language names
- `login`: connection and authentication
- `shell`: desktop shell, taskbar, and desktop-display settings
- `settings`: the Settings application and theme labels
- `apps`: application names from the registry

`ModularAssetLoader` merges these files at startup, so existing translation
keys such as `settings.title` and calls to `.tr()` remain unchanged.

To add a translated feature, create one `<feature>/<locale>.json` file per
supported locale, add the feature name to `ModularAssetLoader._bundles`, and
declare its directory under `flutter.assets` in `pubspec.yaml`.
