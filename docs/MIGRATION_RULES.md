# RemoteOS Flutter Migration Rules

> Version: 1.0  
> Applies to migration from the existing Avalonia `RemoteOS.Client` to the Flutter client.

---

## 1. Purpose

This document defines how the existing Avalonia RemoteOS client must be migrated to Flutter.

The migration goal is not a visual redesign.

The migration goal is:

```text
Preserve:
    UI structure
    user workflows
    feature behavior
    modal behavior
    context-menu behavior
    keyboard/mouse behavior
    theme semantics
    localization keys
    server API behavior
    permission behavior

Replace:
    Avalonia rendering
    XAML binding
    Avalonia-specific controls
    Avalonia-specific window infrastructure
```

Unless explicitly approved, behavioral compatibility is more important than code similarity.

---

## 2. Scope

Primary migration target:

```text
Avalonia RemoteOS.Client
    ↓
Flutter RemoteOS.Client
```

Not automatically included:

```text
RemoteOS.Server
CLI
examples
external applications
```

Server-side changes may be made only when:

- the Flutter client cannot reasonably consume the existing API;
- the change is backward compatible, or compatibility is intentionally broken and documented;
- the migration task explicitly allows server modification.

---

## 3. Migration Priority

For every feature, migrate in this order:

```text
1. Understand current behavior
2. Identify state and commands
3. Identify server/API dependencies
4. Identify modal/context-menu flows
5. Identify theme/localization dependencies
6. Create Flutter domain/repository boundaries
7. Implement ViewModel
8. Implement View
9. Match visual behavior
10. Verify feature parity
11. Add/refine tests
12. Remove temporary migration code
```

Do not begin by translating XAML line-by-line.

---

## 4. Mandatory Pre-Migration Analysis

Before modifying a feature, inspect all relevant Avalonia files.

At minimum:

```text
View XAML
code-behind
ViewModel
models
services
dialogs
context menus
theme resources
localization keys
related commands
related navigation
related server API endpoints
```

If behavior is spread across several files, document the observed flow before rewriting.

Do not infer missing behavior from filenames alone.

---

## 5. Preserve User-Visible Behavior

Unless the task explicitly changes UX, preserve:

- control hierarchy;
- feature placement;
- command availability;
- button semantics;
- double-click behavior;
- right-click behavior;
- drag behavior;
- resize behavior;
- keyboard shortcuts;
- modal stacking rules;
- confirmation behavior;
- validation behavior;
- error behavior;
- success behavior;
- navigation behavior.

Minor Flutter rendering differences are acceptable.

Functional divergence is not.

---

## 6. Preserve Localization Keys

Existing localization keys should be reused wherever practical.

Example:

```text
Common.OK
Common.Cancel
FileManager.Delete
FileManager.Rename
```

Do not rename keys merely to fit Dart naming conventions.

Only rename a localization key when:

- the old key is objectively wrong;
- duplicate/ambiguous keys are being consolidated;
- the migration task explicitly authorizes it.

If a key is renamed, document the mapping.

---

## 7. Localization Resource Layout

Preferred structure:

```text
assets/locales/
├── zh-CN/
│   ├── common.json
│   ├── file_manager.json
│   └── ...
├── en-US/
│   ├── common.json
│   └── ...
└── ...
```

Language metadata may contain:

```json
{
  "Culture": "zh-CN",
  "DisplayName": "简体中文",
  "SortOrder": 10,
  "Strings": {}
}
```

The migration should prefer compatibility with the old resource model over replacing it with generated Dart localization classes unless the replacement provides a clear benefit.

---

## 8. Theme Migration

Existing theme semantics should be preserved.

Map old theme resources into a Flutter-owned theme model.

Do not scatter old resource-key lookups throughout widgets.

Preferred flow:

```text
legacy theme resource
        ↓
ThemeLoader
        ↓
RemoteTheme
        ↓
ThemeData / custom extensions
        ↓
widgets
```

Do not hardcode colors that previously came from the theme system.

---

## 9. View Migration Rules

When migrating XAML:

Do not mechanically translate:

```text
Grid → Row/Column
StackPanel → Column
Border → Container
```

without understanding intent.

Instead determine:

- layout behavior;
- min/max sizing;
- scroll behavior;
- resize behavior;
- alignment;
- adaptive desktop behavior;
- overflow behavior;
- splitter behavior.

Use Flutter layout primitives that preserve the behavior.

---

## 10. Code-Behind Migration Rules

Avalonia code-behind must be classified before migration.

### Keep in Flutter View

Code that handles:

```text
focus
mouse position
drag geometry
window placement
scroll synchronization
animation
local visual state
platform window interaction
```

### Move to ViewModel

Code that handles:

```text
feature state
command orchestration
selection logic with business meaning
validation
command enable/disable logic
feature workflow
```

### Move to Repository / Service

Code that handles:

```text
HTTP
WebSocket
filesystem access
storage
server state synchronization
```

Do not preserve code-behind merely because it existed in Avalonia.

---

## 11. ViewModel Migration Rules

Avalonia ViewModels should be conceptually migrated, not syntax-translated.

Typical mapping:

```text
ObservableProperty
    ↓
ValueNotifier / Listenable state

RelayCommand
    ↓
command_it command

AsyncRelayCommand
    ↓
async command

service dependency
    ↓
repository / use-case dependency
```

Remove Avalonia-specific dependencies.

Flutter ViewModels must not contain:

```text
BuildContext
Widget
Navigator
showDialog
Theme.of
MediaQuery
```

---

## 12. API Migration Rules

Before writing a new API client method:

1. find the existing Avalonia request;
2. find the matching server endpoint;
3. inspect request/response models;
4. preserve compatibility;
5. create DTOs;
6. map DTOs to domain models.

Never introduce a second API shape because it is easier for the Flutter client unless explicitly justified.

---

## 13. DTO Rules

Server payloads must be represented as DTOs.

Example:

```text
remote_file_dto.dart
process_dto.dart
service_status_dto.dart
certificate_dto.dart
```

DTOs must not be passed directly into complex Views.

Map them through repositories or explicit mappers.

---

## 14. Dialog Migration Rules

Existing custom Avalonia modals should be preserved as custom Flutter modals.

Use:

```text
ModalHost
ModalCoordinator
feature dialog state
```

Do not replace ordinary custom dialogs with platform dialogs solely because Flutter provides `showDialog`.

Preserve:

- modal blocking behavior;
- focus behavior;
- keyboard dismissal rules;
- confirmation flow;
- nested modal rules;
- visual placement where practical.

---

## 15. Context Menu Migration Rules

For every existing context menu:

1. preserve item ordering;
2. preserve enabled/disabled conditions;
3. preserve separators;
4. preserve command behavior;
5. preserve submenu behavior;
6. preserve keyboard shortcuts where present.

UI owns context-menu geometry.

ViewModel owns action availability and commands.

---

## 16. Navigation Migration Rules

Do not recreate desktop workspace navigation as a deep mobile navigation stack.

Preserve:

```text
main shell
left navigation
feature workspace
tabs
nested panels
tool windows
```

Use a workspace controller for feature switching.

---

## 17. Window Migration Rules

Window behavior is part of product behavior.

Preserve where applicable:

```text
minimize
maximize
restore
fullscreen
resize
drag
minimum size
initial size
saved size
saved position
custom title bar
window buttons
```

Window-specific state belongs to a window scope.

Never register a window ViewModel as a global application singleton.

---

## 18. Multi-Window Readiness

Even if the first Flutter release uses one main window, avoid architecture that makes future multi-window support impossible.

Do not create hidden globals for:

```text
active workspace
active modal
active server
selected tab
window size
```

Prefer explicit window/session ownership.

---

## 19. Server Session Migration Rules

Any state tied to one RemoteOS server belongs to a server session.

Examples:

```text
authentication token
connection state
capabilities
permissions
file repository
process repository
terminal sessions
server event stream
```

Avoid a single static `currentServer`.

---

## 20. Permission Migration Rules

Preserve the existing permission model.

Do not bypass authorization in the Flutter client for convenience.

Privileged flows should become explicit workflows.

Example:

```text
Open file
  ↓
permission denied
  ↓
elevation requested
  ↓
user approval
  ↓
elevation performed
  ↓
operation retried
```

Do not duplicate permission rules in individual widgets.

---

## 21. File Manager Migration Rules

The file manager must preserve, as applicable:

```text
path navigation
back/forward
refresh
selection
multi-selection
double-click open
context menu
rename
delete
create folder
upload
download
properties
permissions
sorting
view mode
drag/drop
progress
elevation
```

File transfer progress should be stream/event based.

Do not rebuild the complete file list for every small transfer progress update if avoidable.

---

## 22. Terminal Migration Rules

Terminal is an exception to ordinary immutable UI state patterns.

Preserve behavior, but allow the rendering implementation to differ.

Do not:

```text
append every terminal character into a ValueNotifier<String>
```

Use a terminal engine/buffer and streamed terminal data.

Terminal rendering may depend on a third-party package.

Exact rendering parity is not mandatory if feature behavior is preserved.

---

## 23. Performance Page Migration Rules

Preserve:

```text
CPU
memory
disk
network
process metrics
refresh cadence
historical graph behavior
```

A single metrics stream should feed dependent UI components.

Do not let each chart issue independent duplicate API requests.

---

## 24. External Package Exceptions

Some Avalonia functionality may depend on platform-specific packages.

Examples:

```text
terminal renderer
rich text editor
code editor
charting
desktop window package
native file picker
```

When an exact Flutter equivalent is unavailable:

1. preserve functionality first;
2. preserve UX as closely as practical;
3. isolate package-specific code behind an adapter;
4. document known behavioral differences.

---

## 25. Feature-by-Feature Migration

Do not perform a whole-client "big bang" rewrite in one unreviewable change.

Preferred migration units:

```text
shell
login
settings
dashboard
file manager
processes
services
performance
terminal
firewall
certificates
docker
...
```

Each migration unit should compile and be reviewable independently.

---

## 26. Temporary Compatibility Code

Temporary migration adapters are allowed when necessary.

They must:

- be clearly named;
- include a TODO with removal condition;
- not become a permanent hidden dependency;
- not violate security boundaries.

Example:

```dart
// TODO(remoteos-migration):
// Remove after certificate-manager is migrated to CertificateRepository.
```

Avoid generic TODOs such as:

```text
TODO fix later
```

---

## 27. File Size Rules During Migration

Target:

```text
< 300 lines
```

Review threshold:

```text
> 500 lines
```

A migration that replaces one 3000-line Avalonia file with one 3000-line Dart file is considered unsuccessful even if it works.

When a file grows, split by responsibility:

```text
view
view model
components
dialogs
menus
repository
service
models
```

Do not split merely to reduce line count.

---

## 28. Naming During Migration

Prefer conceptual continuity with the Avalonia project.

Example:

```text
ServerViewModel
    ↓
ServerViewModel

FileManagerView
    ↓
FileManagerView
```

Avoid arbitrary renaming that makes cross-referencing old and new code harder.

Rename only when the old name is misleading or conflicts with the new architecture.

---

## 29. No Unrequested Redesign

During migration, Agents must not casually:

- replace navigation;
- alter colors;
- replace custom dialogs;
- remove context menus;
- simplify workflows;
- change localization text;
- combine features;
- delete advanced behavior;
- change permission semantics.

Such changes require an explicit task.

---

## 30. No Silent Feature Removal

If exact migration is not possible:

1. implement the closest safe behavior;
2. leave a documented compatibility note;
3. state the missing capability;
4. do not silently omit the feature.

---

## 31. Migration Verification Checklist

Every migrated feature should be checked for:

```text
[ ] Builds
[ ] Opens correctly
[ ] Visual hierarchy matches
[ ] Primary commands work
[ ] Loading state works
[ ] Error state works
[ ] Empty state works
[ ] Context menu matches
[ ] Dialog flow matches
[ ] Localization works
[ ] Theme switching works
[ ] Permission handling works
[ ] Window resize works
[ ] No obvious overflow
[ ] No direct HTTP in View
[ ] No BuildContext in ViewModel
[ ] No DTO leakage into complex View
[ ] Lifecycle/dispose is correct
[ ] Tests updated/added where practical
```

---

## 32. Regression Protection

A migrated feature is not complete until its critical behavior is protected.

Prefer tests for:

```text
ViewModel commands
repository mapping
permission decisions
state transitions
error normalization
dialog state transitions
```

Use widget/integration tests for high-value interaction flows.

---

## 33. Migration Commit Discipline

Prefer commits that represent one coherent migration step.

Examples:

```text
feat(file-manager): add domain models and repository
feat(file-manager): migrate view model
feat(file-manager): migrate desktop file list UI
feat(file-manager): migrate context menu and dialogs
test(file-manager): cover delete and rename flows
```

Avoid giant commits named:

```text
rewrite flutter
migration
fix stuff
```

---

## 34. Compatibility Notes

When a feature intentionally differs from Avalonia, add a note under:

```text
docs/migration/compatibility/
```

Suggested format:

```text
Feature
Old behavior
New behavior
Reason
Impact
Possible future work
```

---

## 35. Definition of Done

A migrated feature is done when:

```text
1. Functional behavior is preserved.
2. The View contains no business/network logic.
3. The ViewModel contains no Flutter UI dependency.
4. Repositories/services own data access.
5. Dialog and context-menu behavior is preserved.
6. Localization and themes are preserved.
7. File sizes remain maintainable.
8. Critical flows are tested.
9. Known differences are documented.
10. Temporary migration code is identified.
```

---

## 36. Final Migration Principle

> Migrate behavior and architecture, not syntax.

The Flutter client should feel like RemoteOS, while its implementation should feel native to Flutter.
