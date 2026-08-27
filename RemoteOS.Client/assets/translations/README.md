# Translation bundles

Each feature owns a small translation bundle for every bundled locale:

- `shared`: reusable controls and language names
- `login`: connection and authentication
- `shell`: desktop shell, taskbar, and desktop-display settings
- `settings`: the Settings application and theme labels
- `apps`: application names from the registry

`catalog.json` is the source of truth for bundled language metadata, the
fallback locale, and feature bundles. `ModularAssetLoader` reads that catalog
and merges the files at startup, so existing translation keys such as
`settings.title` and calls to `.tr()` remain unchanged. Do not add supported
locales as constants in Dart.

To add a translated feature, create one `<feature>/<locale>.json` file for each
bundled language, add the feature name to `catalog.json`'s `bundles` array, and
declare its directory under `flutter.assets` in `pubspec.yaml`.

## User-installed language packs

Users can add a new UI language without rebuilding the client. Put one JSON
file in the following directory, then restart RemoteOS:

- Linux: `$XDG_CONFIG_HOME/RemoteOS/languages` (or `~/.config/RemoteOS/languages`)
- macOS: `~/Library/Application Support/RemoteOS/languages`
- Windows: `%APPDATA%\RemoteOS\languages`

Set `REMOTEOS_LANGUAGE_PACKS` to use a different directory. Every pack is
self-describing and uses this format:

```json
{
  "locale": "fr-FR",
  "displayName": "Français",
  "sortOrder": 30,
  "translations": {
    "common": { "connect": "Se connecter" },
    "login": { "title": "Connexion Bureau à distance" }
  }
}
```

The configured fallback locale supplies any key the optional pack does not
contain. An external pack with the same locale as a bundled language overrides
only the keys it includes, which also permits translation corrections without a
new client release.
