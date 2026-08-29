# AGENTS.md

> Instructions for Codex, ChatGPT, Claude Code, Gemini CLI, Cursor agents and other coding agents working on RemoteOS Flutter.
>
> [中文版](AGENTS.zh-CN.md)

---

## 1. Mission

Your job is to modify the RemoteOS Flutter client safely and incrementally.

RemoteOS is a desktop server-management application.

When working in this repository, optimize for:

```text
Correctness
Behavioral compatibility
Small reviewable changes
Architecture compliance
Security
Maintainability
Agent-readable code
```

Do not optimize for producing the largest amount of code in the shortest time.

---

## 2. Required Reading

Before making a non-trivial change, read:

```text
[ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)
[MIGRATION_RULES.md](docs/MIGRATION_RULES.md)
[AGENTS.md](AGENTS.md) / [中文版](AGENTS.zh-CN.md)
```

For migration tasks, also inspect the corresponding implementation in the existing Avalonia client.

Architecture rules in [`ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md) are mandatory unless the task explicitly overrides them.

Migration rules in [`MIGRATION_RULES.md`](docs/MIGRATION_RULES.md) are mandatory for Avalonia-to-Flutter work.

---

## 3. Repository Mental Model

The intended dependency flow is:

```text
View
  ↓
ViewModel
  ↓
UseCase (optional)
  ↓
Repository
  ↓
Service
  ↓
RemoteOS.Server / platform APIs
```

The intended lifetime flow is:

```text
Application
  ↓
Window
  ↓
ServerSession
  ↓
Feature
```

Do not introduce dependencies that reverse these arrows.

---

## 4. Before Editing

Before changing code:

1. locate the feature owner;
2. read the complete relevant View;
3. read the relevant ViewModel;
4. inspect repository/service dependencies;
5. inspect related dialogs and context menus;
6. inspect localization keys;
7. inspect theme usage;
8. inspect tests;
9. for migration tasks, inspect the Avalonia source;
10. identify the smallest coherent change.

Do not patch a file based only on a search snippet when surrounding logic matters.

---

## 5. Do Not Guess Existing Behavior

If a task concerns an existing feature:

```text
SEARCH FIRST
READ FIRST
UNDERSTAND FIRST
EDIT SECOND
```

Do not invent:

- API endpoints;
- localization keys;
- permission names;
- DTO fields;
- route IDs;
- feature behavior;
- theme tokens.

Prefer existing names and conventions.

---

## 6. Change Scope

Keep changes narrowly scoped.

If asked to migrate or fix one feature, do not opportunistically:

- redesign unrelated screens;
- rename unrelated files;
- change unrelated APIs;
- replace the state-management stack;
- reformat the entire repository;
- perform broad dependency upgrades.

If a larger refactor is required, make it explicit in the change description.

---

## 7. File Size Rules

Preferred:

```text
< 300 lines/file
```

Review carefully:

```text
300–500 lines/file
```

Refactor signal:

```text
> 500 lines/file
```

Strong architecture smell:

```text
> 800 lines/file
```

Do not create a multi-thousand-line Flutter page.

Split by semantic responsibility.

Good examples:

```text
file_manager_view.dart
file_manager_view_model.dart
file_toolbar.dart
file_path_bar.dart
file_list.dart
file_context_menu.dart
rename_dialog.dart
file_repository.dart
remote_file_service.dart
```

Avoid meaningless fragmentation.

Do not create files such as:

```text
file_title_text.dart
file_padding.dart
one_icon_button.dart
```

unless they represent a real reusable component.

---

## 8. View Rules

Views may handle:

```text
layout
focus
animation
scrolling
mouse position
drag geometry
window geometry
visual composition
theme/localization lookup
```

Views must not directly:

```text
call HTTP
call WebSocket APIs
call repositories
implement permission rules
perform business validation
map DTOs
persist settings
```

A UI event should normally call a ViewModel command.

---

## 9. ViewModel Rules

ViewModels own presentation logic.

Allowed:

```text
observable state
commands
selection state
filters
loading state
error state
repository calls
use-case calls
dialog state
presentation decisions
```

Prohibited:

```text
BuildContext
Widget
Navigator
showDialog()
Theme.of()
MediaQuery
RenderObject
OverlayEntry
```

If you need `BuildContext` in a ViewModel, the design is probably wrong.

---

## 10. Command Rules

Use commands for meaningful user intent.

Examples:

```text
refreshCommand
connectCommand
saveCommand
deleteCommand
renameCommand
restartServiceCommand
renewCertificateCommand
```

Prefer commands when async execution state matters.

Do not create commands for pure UI toggles such as hover or local expansion unless the state has actual feature meaning.

---

## 11. Repository Rules

ViewModels depend on repository interfaces or use cases.

Repositories may:

```text
cache
merge REST and WebSocket state
map DTOs
normalize errors
coordinate refresh
provide streams
```

Repositories must not import feature widgets.

Do not call raw API clients directly from Views or ordinary ViewModels.

---

## 12. Service Rules

Services are I/O adapters.

Examples:

```text
HTTP
WebSocket
filesystem
secure storage
platform channel
window system
```

Services should not own presentation state.

---

## 13. Use Case Rules

Use a Use Case only when it adds value.

Good reasons:

```text
multiple repositories
permission workflow
elevation workflow
multi-step business process
rollback
reusable domain operation
```

Do not create one Use Case class for every single repository method.

---

## 14. DTO and Domain Rules

Never pass raw JSON deep into the UI.

Preferred:

```text
JSON
  ↓
DTO
  ↓
Repository / Mapper
  ↓
Domain Model
  ↓
ViewModel
  ↓
View
```

Avoid DTO leakage into presentation code.

---

## 15. Error Handling

Do not display raw stack traces or exception strings to users.

Normalize errors into RemoteOS failure types.

Always preserve enough technical detail in logs for diagnosis.

Do not swallow exceptions silently.

Bad:

```dart
try {
  ...
} catch (_) {}
```

Good behavior:

```text
catch
  ↓
log technical context
  ↓
map to domain/presentation failure
  ↓
show appropriate user-facing state
```

---

## 16. Security Rules

RemoteOS manages servers and privileged operations.

Never:

- bypass authorization to make a feature work;
- hardcode credentials;
- log passwords;
- log tokens;
- log private keys;
- log certificate private material;
- silently elevate privileges;
- weaken TLS validation as a convenience;
- disable server identity checks without explicit configuration;
- assume client-side permission checks are sufficient.

Client permission state improves UX.

The server remains authoritative.

---

## 17. Permission and Elevation Rules

Privileged operations must use central permission/elevation infrastructure.

Do not invent per-feature elevation implementations.

Expected pattern:

```text
command
  ↓
use case / repository
  ↓
permission check
  ↓
elevation request if required
  ↓
user decision
  ↓
server-side elevation
  ↓
operation retry
```

Do not automatically accept an elevation prompt.

---

## 18. Dialog Rules

RemoteOS uses custom desktop modals.

Do not replace feature dialogs with arbitrary `showDialog()` implementations without reason.

Prefer:

```text
ModalHost
ModalCoordinator
feature dialog state
```

ViewModel may request a dialog state.

View renders it.

ViewModel does not call Flutter dialog APIs.

---

## 19. Context Menu Rules

Preserve desktop context-menu behavior.

UI owns:

```text
position
overlay
pointer interaction
animation
```

ViewModel owns:

```text
selected item
enabled state
commands
permission-aware action availability
```

---

## 20. Navigation Rules

RemoteOS is workspace-oriented.

Do not model every feature transition as mobile `Navigator.push()`.

Use the existing shell/workspace infrastructure.

Do not create a second navigation architecture inside one feature.

---

## 21. Window Rules

Desktop window behavior is part of application behavior.

Do not casually break:

```text
dragging
resizing
minimize
maximize
restore
fullscreen
minimum size
saved bounds
custom title bar
```

Window-specific state must not become an app-wide singleton.

---

## 22. Server Session Rules

Never introduce a hidden global `currentServer` if session ownership already exists or can be explicit.

Server-specific dependencies belong to a server-session scope.

Examples:

```text
API client
authentication
permissions
file repository
process repository
server events
```

---

## 23. Localization Rules

Reuse existing keys.

Do not hardcode user-facing strings when a localization key exists.

Do not rename localization keys during unrelated tasks.

When adding a new string:

1. add a stable semantic key;
2. add it to the appropriate resource file;
3. update all required baseline locales;
4. do not put presentation text in business logic unless it is genuinely domain data.

### 23.1 Parameterized translations

This project uses `easy_localization`. Two rules are mandatory for any
translation that carries runtime values:

#### Rule A — always use `namedArgs`, never positional `args`

Good — named placeholders survive reordering during translation and make
each argument's role self-documenting:

```json
// zh-CN/feature.json
"feature.status.updated": "已更新 — {time}  CPU {cpu}%  进程 {count}"

// View
'feature.status.updated'.tr(namedArgs: {
  'time': DateFormat('HH:mm:ss').format(someTime.toLocal()),
  'cpu': cpuPercent.toStringAsFixed(1),
  'count': '${processTotalCount}',
})
```

Bad — positional `{0}`, `{1}`... break when a translator rearranges the
sentence and hide what each value means:

```dart
// DO NOT DO THIS — hard to read, fragile across locales
'feature.status.updated'.tr(args: [time, cpu, '$count'])
```

Existing `args:` calls in legacy files should be migrated to `namedArgs:`
when that area is being touched for other work. Do not introduce new ones.

#### Rule B — View owns translation; ViewModel/State carry data only

State and ViewModel must never call `.tr()`, `DateFormat`, or compose
translated strings. They carry:

```text
enum values    (e.g. ConnectionState.live)
raw numbers    (e.g. currentCpuPercent: double)
raw timestamps (e.g. lastUpdatedTime: DateTime?)
typed payloads (e.g. KillFeedback { kind, name, pid, errorMessage? })
```

The View is the single place that maps enum → key, formats numbers/dates,
and calls `.tr(namedArgs: ...)`.

**Why?**

- AGENTS.md §9 forbids `BuildContext` in ViewModel; `.tr()` needs it.
- AGENTS.md §7 (View rules) says the View owns presentation concerns;
  localization and formatting are presentation.
- Live language switching works automatically because every rebuild
  re-reads `.tr()` in the View — cached translated strings in State
  would go stale.

**Concrete example — before (wrong):**

```dart
// ViewModel — BAD: translation + formatting + key naming all mixed in
class TaskManagerUiState {
  final String connectionStatus; // already .tr()'ed
  final String statusText;       // already .tr()'ed with args
}

// ViewModel code
connectionStatus: 'task_manager.connection.live'.tr(),
statusText: 'task_manager.status.updated'
    .tr(args: [time, cpu, '$count']),
```

**Concrete example — after (correct):**

```dart
// Domain — pure data
enum TaskConnectionState { initializing, live, snapshot, ... }
enum TaskManagerStatusKind { collecting, updated, failed, none }

class TaskManagerUiState {
  final TaskConnectionState connectionState;
  final TaskManagerStatusKind statusKind;
  final DateTime? lastUpdatedTime;
  final double currentCpuPercent;
  final int processTotalCount;
}

// View — owns translation + formatting
Text(_connectionKey(state.connectionState).tr())
Text(_buildStatusText(state))

static String _connectionKey(TaskConnectionState s) {
  switch (s) {
    case TaskConnectionState.live: return 'task_manager.connection.live';
    case TaskConnectionState.updated: return 'task_manager.connection.updated';
    // ...
  }
}

static String? _buildStatusText(TaskManagerUiState s) {
  switch (s.statusKind) {
    case TaskManagerStatusKind.updated:
      final time = DateFormat('HH:mm:ss')
          .format(s.lastUpdatedTime?.toLocal() ?? DateTime.now());
      return 'task_manager.status.updated'.tr(namedArgs: {
        'time': time,
        'cpu': s.currentCpuPercent.toStringAsFixed(1),
        'count': '${s.processTotalCount}',
      });
    case TaskManagerStatusKind.failed:
      return 'task_manager.status.collect_failed'.tr(namedArgs: {
        'error': s.errorMessage ?? '',
      });
    // ...
  }
}
```

#### Adding a new parameterized key — checklist

1. All three locale files (`zh-CN`, `en-US`, `ja-JP`) get the same key with
   named placeholders `{name}`, `{count}`, `{error}` etc.
2. State/ViewModel expose enums + raw data that can drive the key selection
   and namedArgs map.
3. View provides a small private helper (`_buildXxxText`, `_keyForYyy`)
   that owns the switch-on-enum → translation-key mapping.
4. Run `flutter analyze` — there must be no `easy_localization` usage in
   files under `domain/` or `application/`.

---

## 24. Theme Rules

Do not hardcode colors that belong to the RemoteOS theme system.

Use theme tokens/extensions/components.

Hardcoded colors are acceptable only when the color is semantically fixed by protocol/content, not appearance.

Examples:

```text
terminal ANSI colors
certificate status color model
explicit user-selected color
```

Even then, prefer a named semantic abstraction.

---

## 25. Avalonia Migration Rules

When migrating from Avalonia:

Do not translate XAML mechanically.

First understand:

```text
layout intent
ViewModel state
commands
code-behind
dialogs
context menus
keyboard behavior
window behavior
API calls
theme resources
localization resources
```

Preserve behavior unless the task explicitly changes it.

---

## 26. External Packages

Before adding a package:

1. determine whether the capability already exists;
2. confirm the package solves a real problem;
3. prefer a focused package over a monolithic framework;
4. isolate package-specific code when practical;
5. avoid package-driven architecture changes;
6. avoid adding duplicate packages for the same concern.

Do not upgrade unrelated dependencies in a feature task.

---

## 27. Generated Code

Do not manually edit generated files unless the generator explicitly requires it.

Keep generated code isolated from handwritten feature logic.

If a code generator is introduced, document:

```text
why it exists
how to run it
what files it owns
whether generated files are committed
```

---

## 28. Formatting and Static Analysis

Before considering a code change complete:

```text
dart format
flutter analyze
relevant tests
```

Fix new warnings introduced by your change.

Do not silence analyzer warnings with broad ignores unless there is a documented reason.

---

## 29. Test Expectations

For non-trivial logic, add or update tests.

Prioritize:

```text
ViewModel state transitions
command behavior
repository mapping
permission decisions
error mapping
dialog state
session behavior
```

Use widget tests when layout or interaction behavior is important.

Use integration tests for critical end-to-end flows.

---

## 30. Performance Rules

Avoid unnecessary whole-page rebuilds.

Prefer fine-grained listening.

For high-frequency data:

```text
terminal
performance metrics
transfer progress
logs
```

prefer streams or specialized buffers.

Do not repeatedly clone huge state objects for every high-frequency event unless measured and justified.

---

## 31. Lifecycle Rules

Any object that owns:

```text
ValueNotifier
StreamSubscription
AnimationController
FocusNode
ScrollController
Timer
WebSocket subscription
Command
```

must have a clear disposal/lifetime owner.

Do not leak subscriptions across feature/session/window lifetimes.

---

## 32. Logging Rules

Logs should help diagnose:

```text
connection
authentication
API failures
session state
permissions
feature operations
unexpected exceptions
```

Do not log secrets.

Prefer structured context:

```text
serverId
feature
operation
requestId
sessionId
```

when available and safe.

---

## 33. Comments

Write comments for:

```text
why
invariants
protocol constraints
platform quirks
security constraints
migration compatibility
non-obvious workarounds
```

Do not comment obvious code.

Bad:

```dart
// Set loading to true.
loading.value = true;
```

Good:

```dart
// Keep the previous file list visible during refresh to avoid a full
// desktop list flash while the server round-trip is in progress.
```

---

## 34. TODO Rules

TODOs must contain intent.

Good:

```dart
// TODO(remoteos-migration):
// Remove this adapter after the certificate repository is fully migrated.
```

Bad:

```dart
// TODO fix
```

Do not use TODOs as a substitute for implementing required task behavior.

---

## 35. Large Refactors

For a large refactor:

1. preserve buildability at intermediate steps when practical;
2. create compatibility adapters if needed;
3. move one responsibility at a time;
4. keep commits/review units coherent;
5. remove temporary adapters once migration is complete.

Avoid simultaneous architecture, UI, API and naming rewrites unless specifically requested.

---

## 36. Git Safety

Do not:

- rewrite history;
- force-push;
- delete branches;
- remove user work;
- reset unrelated changes.

Do not discard modifications you did not create.

If the working tree contains unrelated changes, work around them.

---

## 37. Do Not Delete "Unused" Code Blindly

RemoteOS contains desktop/platform-specific code that may not be referenced from obvious paths.

Before deleting code:

1. search references;
2. inspect dynamic registration;
3. inspect DI registration;
4. inspect localization/theme loading;
5. inspect platform branches;
6. inspect reflection/serialization usage.

Do not trust a single static-reference search for architecture-level deletion.

---

## 38. API Compatibility

When changing API models:

- inspect the server;
- inspect Avalonia usage;
- inspect existing Flutter usage;
- preserve backward compatibility unless explicitly authorized;
- update DTOs and tests together.

Do not invent undocumented server fields.

---

## 39. UI Fidelity

During migration, preserve the existing RemoteOS visual hierarchy unless redesign is requested.

Prioritize:

```text
spacing hierarchy
control grouping
modal behavior
context menus
desktop density
navigation structure
resizing behavior
```

Pixel-perfect rendering is desirable but secondary to correct desktop behavior.

---

## 40. Overflow and Desktop Resize

Every migrated desktop view must be considered at:

```text
minimum supported width
typical width
maximized width
high DPI
text scaling where applicable
```

Do not fix overflow by blindly wrapping everything in `SingleChildScrollView`.

Use proper constraints and responsive desktop layout.

---

## 41. What to Report After a Change

When finishing a non-trivial task, report:

```text
What changed
Files changed
Important architectural decisions
Tests/analyze run
Known limitations
Migration differences, if any
```

Do not claim tests passed unless they were actually run.

---

## 42. Stop Conditions

Do not continue blindly if you discover:

```text
a required API does not exist
the old feature behavior is ambiguous
security semantics differ
the task conflicts with architecture rules
the working tree contains conflicting user changes
```

When possible, choose the safest compatible implementation and document the limitation.

Do not fabricate missing APIs or behavior.

---

## 43. Preferred Agent Workflow

Use this sequence:

```text
SEARCH
  ↓
READ
  ↓
MAP DEPENDENCIES
  ↓
IMPLEMENT SMALLEST COHERENT CHANGE
  ↓
FORMAT
  ↓
ANALYZE
  ↓
TEST
  ↓
REVIEW DIFF
  ↓
REPORT
```

---

## 44. Final Agent Rules

Mandatory summary:

```text
DO:
    read architecture first
    preserve existing behavior
    keep files small
    keep dependencies directional
    use repositories/services
    centralize permission/elevation
    preserve themes/localization
    test important logic
    inspect Avalonia before migration

DO NOT:
    put HTTP in Views
    put BuildContext in ViewModels
    create giant Dart files
    use hidden global server state
    bypass security
    redesign unrelated UI
    silently remove features
    invent API contracts
    rename localization keys casually
    replace architecture during feature work
```

Primary principle:

> Understand the existing system before changing it, then make the smallest architecture-compliant change that preserves RemoteOS behavior.
