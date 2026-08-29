# RemoteOS Flutter Architecture

> Version: 1.0  
> Status: Proposed baseline architecture  
> Applies to: `RemoteOS.Client` Flutter implementation  
> Primary goals: desktop-first, MVVM, Avalonia migration friendly, Agent/Codex friendly

---

## 1. Purpose

This document defines the target architecture of the Flutter implementation of RemoteOS.

RemoteOS is not treated as a simple mobile-style Flutter application. It is a desktop server-management client with:

- long-lived server sessions;
- multiple functional modules;
- custom desktop dialogs and context menus;
- potentially multiple windows;
- real-time data streams;
- file management;
- terminal sessions;
- process/service/firewall/container/certificate management;
- theme switching;
- localization;
- permission elevation;
- persistent settings;
- HTTP/WebSocket communication with `RemoteOS.Server`.

The architecture therefore prioritizes:

1. clear ownership of state;
2. strict separation of UI and business logic;
3. predictable lifetime/scoping;
4. feature isolation;
5. testability;
6. migration compatibility with the existing Avalonia client;
7. files that are small enough for humans and coding agents to understand safely.

---

## 2. Architectural Style

RemoteOS Flutter uses:

**Feature-first MVVM + Repository/Service layering + optional Use Cases**

The default dependency flow is:

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
RemoteOS.Server / Local Platform / Storage
```

A layer may only depend on layers below it.

Reverse dependencies are prohibited.

---

## 3. Recommended Core Stack

The default application architecture uses:

```text
Dependency Injection
    get_it

Reactive View binding
    watch_it

Commands
    command_it

Simple observable state
    ValueNotifier<T>
    Listenable

Continuous / high-frequency state
    Stream<T>

Network
    RemoteOS API abstraction
    HTTP + WebSocket

Navigation
    RemoteOS-owned workspace/navigation abstraction

Dialogs
    RemoteOS-owned ModalHost / ModalCoordinator

Context menus
    RemoteOS-owned context-menu host

Theme
    RemoteOS ThemeRepository + ThemeController

Localization
    RemoteOS LocalizationRepository + LocalizationController
```

RemoteOS must not make its domain architecture depend on a UI routing framework or a monolithic state-management framework.

---

## 4. Top-Level Project Structure

Recommended `lib/` layout:

```text
lib/
├── app/
│   ├── app.dart
│   ├── bootstrap.dart
│   ├── dependency_injection.dart
│   │
│   ├── shell/
│   │   ├── shell_view.dart
│   │   ├── shell_view_model.dart
│   │   └── components/
│   │
│   └── startup/
│       ├── startup_view.dart
│       └── startup_view_model.dart
│
├── core/
│   ├── api/
│   ├── auth/
│   ├── commands/
│   ├── errors/
│   ├── events/
│   ├── localization/
│   ├── logging/
│   ├── navigation/
│   ├── permissions/
│   ├── settings/
│   ├── storage/
│   ├── theme/
│   ├── window/
│   └── utils/
│
├── features/
│   ├── login/
│   ├── dashboard/
│   ├── file_manager/
│   ├── terminal/
│   ├── process_manager/
│   ├── performance/
│   ├── service_manager/
│   ├── firewall/
│   ├── certificate_manager/
│   ├── nginx_manager/
│   ├── docker/
│   ├── settings/
│   └── ...
│
└── ui/
    └── core/
        ├── buttons/
        ├── dialogs/
        ├── inputs/
        ├── layout/
        ├── menus/
        ├── tables/
        └── typography/
```

Rules:

- `app/` owns application bootstrapping and the desktop shell.
- `core/` owns cross-cutting non-feature infrastructure.
- `features/` contains business features.
- `ui/core/` contains truly reusable visual controls.
- Do not create a global `widgets/` dumping ground.
- Do not create a global `view_models/` folder containing every feature ViewModel.
- Feature-specific code stays inside the owning feature.

---

## 5. Feature Structure

A non-trivial feature should use:

```text
features/<feature_name>/
├── presentation/
│   ├── <feature>_view.dart
│   ├── <feature>_view_model.dart
│   │
│   ├── components/
│   ├── dialogs/
│   └── menus/
│
├── domain/
│   ├── models/
│   ├── repositories/
│   └── use_cases/
│
└── data/
    ├── dto/
    ├── mappers/
    ├── repositories/
    └── services/
```

Example:

```text
features/file_manager/
├── presentation/
│   ├── file_manager_view.dart
│   ├── file_manager_view_model.dart
│   ├── components/
│   │   ├── file_toolbar.dart
│   │   ├── file_path_bar.dart
│   │   ├── file_list.dart
│   │   └── file_status_bar.dart
│   ├── dialogs/
│   │   ├── create_folder_dialog.dart
│   │   ├── rename_dialog.dart
│   │   └── file_properties_dialog.dart
│   └── menus/
│       └── file_context_menu.dart
│
├── domain/
│   ├── models/
│   │   ├── remote_file.dart
│   │   └── file_permission.dart
│   ├── repositories/
│   │   └── file_repository.dart
│   └── use_cases/
│       ├── open_remote_file.dart
│       └── delete_remote_files.dart
│
└── data/
    ├── dto/
    │   └── remote_file_dto.dart
    ├── mappers/
    │   └── remote_file_mapper.dart
    ├── repositories/
    │   └── file_repository_impl.dart
    └── services/
        └── remote_file_service.dart
```

Small features may omit unnecessary directories.

Do not create empty abstraction layers merely to satisfy this structure.

---

## 6. View Responsibilities

A View is Flutter UI.

A View may:

- build widgets;
- arrange layout;
- own animation controllers;
- own focus nodes;
- own scroll controllers;
- process pointer position;
- calculate local UI geometry;
- render loading/error/data states;
- forward user intent to the ViewModel;
- display dialogs or menus based on presentation state;
- use theme and localization.

A View must not:

- call HTTP endpoints;
- create raw WebSocket requests;
- directly access repositories;
- implement business permission checks;
- make authorization decisions;
- map DTOs;
- contain server-management workflows;
- implement retry policies;
- directly mutate persistent settings;
- decide whether a privileged operation is allowed.

Example:

```dart
class FileManagerView extends WatchingWidget {
  const FileManagerView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = di<FileManagerViewModel>();

    final path =
        watchValue((FileManagerViewModel x) => x.currentPath);

    final files =
        watchValue((FileManagerViewModel x) => x.files);

    return Column(
      children: [
        FilePathBar(
          path: path,
          onNavigate: vm.navigateCommand.run,
        ),
        Expanded(
          child: FileList(
            files: files,
            onOpen: vm.openCommand.run,
          ),
        ),
      ],
    );
  }
}
```

---

## 7. ViewModel Responsibilities

A ViewModel owns presentation logic and presentation state.

A ViewModel may:

- expose observable state;
- expose commands;
- call repositories;
- call use cases;
- transform domain state into presentation state;
- coordinate loading/error/empty states;
- decide whether presentation actions are enabled;
- request a modal state transition;
- react to repository streams;
- maintain feature-level selection and filter state.

A ViewModel must not reference:

```text
BuildContext
Widget
Navigator
showDialog()
Theme.of(...)
MediaQuery
RenderObject
OverlayEntry
```

A ViewModel should remain unit-testable without Flutter rendering.

Typical shape:

```dart
class FileManagerViewModel {
  FileManagerViewModel(
    this._repository,
    this._permissionRepository,
  );

  final FileRepository _repository;
  final PermissionRepository _permissionRepository;

  final currentPath = ValueNotifier<String>('/');
  final files = ValueNotifier<List<RemoteFile>>([]);
  final selectedFiles = ValueNotifier<List<RemoteFile>>([]);

  late final refreshCommand =
      Command.createAsyncNoResult<void>(
    (_) => _refresh(),
  );

  Future<void> _refresh() async {
    files.value =
        await _repository.list(currentPath.value);
  }

  void dispose() {
    currentPath.dispose();
    files.dispose();
    selectedFiles.dispose();
    refreshCommand.dispose();
  }
}
```

---

## 8. Commands

User actions that represent application intent should normally be modeled as commands.

Examples:

```text
refreshCommand
connectCommand
disconnectCommand
openCommand
saveCommand
deleteCommand
renameCommand
startServiceCommand
stopServiceCommand
restartServiceCommand
installCommand
renewCertificateCommand
```

Commands are preferred when the UI needs any combination of:

- running state;
- error state;
- result state;
- enable/disable state;
- async execution;
- duplicate-execution protection.

Do not turn trivial local UI toggles into commands.

Example:

```text
Expanded / collapsed
Hover
Pointer position
Temporary menu animation
```

These remain UI state.

---

## 9. Repository Layer

Repositories are the application's source of truth for a domain area.

A ViewModel should depend on repository interfaces, not service implementations.

Example:

```dart
abstract interface class FileRepository {
  Future<List<RemoteFile>> list(String path);

  Future<void> rename(
    String path,
    String newName,
  );

  Future<void> delete(
    List<String> paths,
  );

  Stream<FileTransferProgress> upload(
    UploadRequest request,
  );
}
```

Repository responsibilities may include:

- caching;
- refresh policies;
- retry;
- merging REST and WebSocket data;
- DTO to domain mapping;
- error normalization;
- stream ownership;
- domain-level synchronization;
- session awareness.

Repositories must not know about Widgets.

---

## 10. Service Layer

Services perform external I/O.

Examples:

```text
RemoteFileService
ProcessService
ServiceManagerService
FirewallService
DockerService
CertificateService
AuthenticationService
SettingsStorageService
WindowPlatformService
```

A service may wrap:

- HTTP;
- WebSocket;
- local filesystem;
- secure storage;
- platform channels;
- desktop window APIs;
- operating-system APIs.

A service should not own UI state.

Example:

```dart
class RemoteFileService {
  RemoteFileService(this._api);

  final RemoteOsApiClient _api;

  Future<List<RemoteFileDto>> list(
    String path,
  ) async {
    return _api.getFileList(path);
  }
}
```

---

## 11. Use Cases

Use Cases are optional.

Create a Use Case when an operation:

- coordinates multiple repositories;
- contains non-trivial business policy;
- performs permission/elevation checks;
- needs rollback or multi-step orchestration;
- is independently reusable.

Good examples:

```text
ConnectServerUseCase
OpenPrivilegedFileUseCase
InstallNginxUseCase
RenewCertificateUseCase
CreateDockerContainerUseCase
EnableSshUseCase
```

Avoid trivial wrappers such as:

```text
GetFileUseCase
SetNameUseCase
ClosePanelUseCase
```

unless they represent actual domain behavior.

---

## 12. DTO, Domain Model and Presentation State

These are separate concepts.

### DTO

Represents remote protocol data.

```dart
class RemoteFileDto {
  final String fileName;
  final bool isDirectory;
}
```

### Domain Model

Represents application meaning.

```dart
class RemoteFile {
  final String name;
  final RemotePath path;
  final FileKind kind;
  final FilePermissions permissions;
}
```

### Presentation State

Represents UI-specific state.

```dart
class FileListItemState {
  final RemoteFile file;
  final bool selected;
  final bool highlighted;
}
```

Rules:

```text
JSON
  ↓
DTO
  ↓
Mapper / Repository
  ↓
Domain Model
  ↓
ViewModel
  ↓
Presentation State
  ↓
View
```

Do not pass raw JSON to Views.

Do not let DTOs become UI models.

---

## 13. Error Model

RemoteOS should normalize failures.

Recommended base model:

```dart
sealed class RemoteOsFailure {
  const RemoteOsFailure();
}

final class NetworkFailure extends RemoteOsFailure {}

final class UnauthorizedFailure extends RemoteOsFailure {}

final class PermissionDeniedFailure extends RemoteOsFailure {}

final class ValidationFailure extends RemoteOsFailure {}

final class ServerFailure extends RemoteOsFailure {}

final class UnsupportedOperationFailure
    extends RemoteOsFailure {}
```

Low-level errors should be converted before they reach presentation code.

Example:

```text
SocketException
    ↓
Remote API Service
    ↓
Repository
    ↓
NetworkFailure
    ↓
ViewModel
    ↓
User-facing presentation
```

UI must not normally render `exception.toString()`.

---

## 14. Dependency Injection and Scopes

RemoteOS must not treat every object as an application singleton.

Recommended lifetime hierarchy:

```text
Application Scope
    ↓
Window Scope
    ↓
Server Session Scope
    ↓
Feature Scope
```

### Application Scope

Examples:

```text
SettingsRepository
ThemeRepository
LocalizationRepository
ServerCatalogRepository
ApplicationLogger
WindowManager
```

### Window Scope

Examples:

```text
ShellViewModel
WorkspaceController
ModalCoordinator
ContextMenuCoordinator
WindowStateController
```

### Server Session Scope

Examples:

```text
RemoteOsApiClient
AuthenticationRepository
PermissionRepository
FileRepository
ProcessRepository
DockerRepository
ServerEventRepository
```

### Feature Scope

Examples:

```text
FileManagerViewModel
PerformanceViewModel
FirewallViewModel
CertificateManagerViewModel
```

A ViewModel that contains window-specific UI state must never be registered as an application singleton.

---

## 15. Server Session Architecture

A connected server should be represented as a first-class session object.

Recommended concept:

```text
ServerSession
├── server identity
├── connection state
├── authentication state
├── capabilities
├── permissions
├── API client
├── WebSocket/event channel
└── repositories
```

This allows RemoteOS to support, in the future:

- multiple connected servers;
- multiple windows;
- multiple workspaces;
- independent authentication;
- reconnection;
- session restoration.

Avoid hidden global `currentServer` state.

---

## 16. Workspace and Navigation

RemoteOS is a desktop workspace application, not a typical mobile page stack.

Do not model the whole application as a deep `Navigator.push()` chain.

Use:

```text
Application navigation
    Login
    Main shell

Desktop workspace navigation
    WorkspaceController
```

A workspace may contain:

```text
Dashboard
File Manager
Terminal
Processes
Performance
Services
Firewall
Certificates
Docker
Settings
```

Recommended concept:

```dart
class WorkspaceController {
  final currentModule =
      ValueNotifier<WorkspaceModule?>(null);

  final tabs =
      ValueNotifier<List<WorkspaceTab>>([]);
}
```

Design for future support of:

- multiple tabs;
- multiple terminals;
- multiple file-manager tabs;
- back/forward history;
- restored sessions.

---

## 17. Modal Architecture

RemoteOS should preserve the desktop-style custom modal behavior of the existing Avalonia client.

Recommended hierarchy:

```text
RemoteOsWindow
├── TitleBar
├── Navigation
├── Workspace
├── ContextMenuHost
├── NotificationHost
└── ModalHost
```

Use a `ModalCoordinator` or feature modal state.

Do not invoke platform dialogs for ordinary RemoteOS CRUD flows unless there is a platform-specific reason.

Example dialog state:

```dart
sealed class FileManagerDialogState {
  const FileManagerDialogState();
}

final class NoFileManagerDialog
    extends FileManagerDialogState {}

final class RenameFileDialog
    extends FileManagerDialogState {
  const RenameFileDialog(this.file);

  final RemoteFile file;
}
```

The ViewModel changes modal state.

The View renders the modal.

The ViewModel does not call `showDialog()`.

---

## 18. Context Menu Architecture

Context menu positioning belongs to the UI.

Context menu action availability belongs to presentation/business logic.

Example:

```text
UI owns:
    x/y position
    overlay placement
    animations
    pointer interaction

ViewModel owns:
    selected item
    canRename
    canDelete
    canDownload
    command execution
```

Do not store raw pointer geometry in domain state.

---

## 19. Permission Elevation

Permission elevation should be modeled as an application workflow.

Example:

```text
User opens /etc/ssh/sshd_config
        ↓
OpenRemoteFileCommand
        ↓
OpenPrivilegedFileUseCase
        ↓
PermissionRepository
        ↓
Elevation required
        ↓
ViewModel exposes elevation request
        ↓
ModalHost displays elevation UI
        ↓
User approves
        ↓
ElevationRepository
        ↓
Operation retried
```

Permission decisions must not be implemented independently in every feature.

Centralize them in:

```text
core/permissions/
```

and server-session permission repositories.

---

## 20. Terminal Architecture

Terminal rendering is a special high-frequency feature.

Do not represent terminal output as repeated immutable `String` state in a ViewModel.

Recommended flow:

```text
TerminalView
    ↓
TerminalViewModel
    ↓
TerminalSessionRepository
    ↓
TerminalWebSocketService
```

Use:

```text
Stream<TerminalChunk>
```

for data transport.

The ViewModel owns:

```text
session identity
connection state
terminal title
working-directory metadata
encoding
reconnect state
```

The terminal renderer owns:

```text
ANSI parsing
character buffer
cursor
selection
scrollback
rendering
```

---

## 21. Performance and Real-Time Features

Real-time data should normally be stream-oriented.

Example:

```text
PerformanceService
      ↓
PerformanceRepository
      ↓
Stream<PerformanceSnapshot>
      ↓
PerformanceViewModel
      ↓
Charts
```

Polling interval and stream lifecycle belong below the View.

Individual graphs must not independently request the same server metrics.

---

## 22. Theme Architecture

Recommended flow:

```text
ThemeLoader
    ↓
ThemeRepository
    ↓
ThemeController
    ↓
RemoteOsApp
```

RemoteOS should define its own theme model and map it into Flutter `ThemeData`.

Possible model:

```dart
class RemoteTheme {
  final String id;
  final String displayName;

  final Color accent;
  final Color background;
  final Color foreground;
  final Color border;
}
```

This allows:

- built-in light/dark themes;
- Avalonia-compatible theme naming;
- custom themes;
- user-defined palettes;
- future theme import/export.

Feature ViewModels must not know the active theme.

---

## 23. Localization Architecture

Recommended asset layout:

```text
assets/locales/
├── zh-CN/
│   ├── common.json
│   ├── file_manager.json
│   ├── terminal.json
│   └── settings.json
├── en-US/
│   ├── common.json
│   └── ...
└── ja-JP/
    ├── common.json
    └── ...
```

Example metadata:

```json
{
  "Culture": "zh-CN",
  "DisplayName": "简体中文",
  "SortOrder": 10,
  "Strings": {
    "Common.OK": "确定",
    "Common.Cancel": "取消"
  }
}
```

Recommended flow:

```text
LocalizationLoaderService
        ↓
LocalizationRepository
        ↓
LocalizationController
        ↓
View
```

ViewModels should expose semantic state, not translated UI text, unless the text itself is domain data.

---

## 24. Reusable UI Controls

Reusable desktop components belong under:

```text
ui/core/
```

Examples:

```text
RemoteButton
RemoteTextBox
RemotePasswordBox
RemoteDialog
RemoteContextMenu
RemoteDataGrid
RemoteTreeView
RemoteNavigationView
RemoteSplitView
RemoteTitleBar
RemoteTabView
RemoteNotification
```

A reusable control may encapsulate visual behavior, but must not contain feature business logic.

---

## 25. Naming Conventions

Use `snake_case` filenames and consistent suffixes.

Examples:

```text
file_manager_view.dart
file_manager_view_model.dart
file_repository.dart
file_repository_impl.dart
remote_file_service.dart
remote_file_dto.dart
remote_file.dart
rename_file.dart
```

Class suffix conventions:

```text
*View
*ViewModel
*Repository
*RepositoryImpl
*Service
*Dto
*Request
*Response
*Failure
*UseCase
*Controller
*Coordinator
```

Avoid generic names such as:

```text
Helper
Manager
Utils
Common
Data
Stuff
```

unless their responsibility is truly cross-cutting and obvious.

---

## 26. File Size and Responsibility Rules

Preferred targets:

```text
Target:
    < 300 lines per file

Acceptable:
    300–500 lines when cohesive

Review required:
    > 500 lines

Strong refactor signal:
    > 800 lines
```

Do not split code mechanically.

Split when a subcomponent has:

- independent semantic meaning;
- independent behavior;
- independent tests;
- meaningful reuse;
- a clear responsibility.

Avoid both extremes:

```text
4000-line feature files
```

and:

```text
one tiny widget per file with no semantic value
```

---

## 27. Testing Boundaries

Minimum expected testing strategy:

```text
Service
    unit tests / integration tests

Repository
    unit tests

UseCase
    unit tests

ViewModel
    unit tests

Reusable View
    widget tests

Critical feature flow
    integration tests
```

ViewModel tests should not require rendering a Flutter widget tree.

---

## 28. Dependency Rules

Allowed:

```text
presentation → domain
presentation → core
data → domain
data → core
domain → core abstractions with no Flutter UI dependency
app → features
app → core
```

Prohibited:

```text
domain → presentation
data → presentation
repository → widget
service → widget
feature A → feature B internals
core → feature
```

If features must communicate, prefer:

- shared domain abstractions;
- app/workspace coordinator;
- session event bus;
- explicitly defined public feature interface.

---

## 29. Cross-Feature Events

Use events for meaningful asynchronous cross-feature changes.

Examples:

```text
ServerDisconnected
AuthenticationExpired
PermissionChanged
DockerContainerChanged
CertificateRenewed
FileSystemChanged
ThemeChanged
LocaleChanged
```

Do not use an event bus to avoid proper dependencies for ordinary method calls.

---

## 30. Avalonia-to-Flutter Concept Mapping

```text
Avalonia                         Flutter RemoteOS

*.axaml                         *_view.dart
*.axaml.cs                      minimal view lifecycle
ViewModel.cs                    *_view_model.dart
ObservableObject                plain Dart ViewModel
ObservableProperty              ValueNotifier/Listenable
RelayCommand                    command_it Command
AsyncRelayCommand               async Command
DI container                    get_it
binding                         watch_it
Service                         Repository / Service
ResourceDictionary              ThemeRepository
localization resources          LocalizationRepository
custom modal                    ModalHost
ContextMenu                     RemoteContextMenu
MainWindow                      ShellView / RemoteOsWindow
UserControl                     component Widget
```

The goal is not to mechanically port XAML concepts.

The goal is to preserve the proven business structure while implementing the UI according to Flutter's reactive model.

---

## 31. Architectural Non-Goals

This architecture does not aim to:

- reproduce Avalonia APIs exactly;
- make every class an interface;
- create a Use Case for every method;
- introduce a global Redux-style state store;
- centralize all feature state into one AppState object;
- make every object a singleton;
- force every Widget to have its own ViewModel;
- hide all Flutter concepts behind custom wrappers.

---

## 32. Baseline Architectural Rules

These rules are mandatory unless an ADR explicitly overrides them:

```text
1. View does not implement business logic.
2. ViewModel does not depend on BuildContext or Widget.
3. ViewModel depends on Repository or UseCase, not raw HTTP clients.
4. Repository is the domain data boundary.
5. Service handles external I/O.
6. DTO is not a Domain Model.
7. Domain Model is not UI state.
8. Session-specific state is never a global singleton.
9. Dialog behavior uses RemoteOS modal infrastructure.
10. Context-menu geometry remains in UI.
11. High-frequency streams are not modeled as giant ValueNotifier values.
12. Feature internals are not imported directly by unrelated features.
13. Files above 500 lines require architectural review.
14. New functionality should preserve feature-first organization.
15. Every non-obvious exception must be documented.
```

---

## 33. Architecture Decision Records

For major deviations, create:

```text
docs/adr/
```

Example:

```text
0001-use-get-it-watch-it-command-it.md
0002-custom-modal-host.md
0003-server-session-scoping.md
0004-localization-resource-layout.md
```

An ADR should state:

```text
Context
Decision
Alternatives
Consequences
Migration impact
```

This prevents future agents from repeatedly re-deciding settled architecture.

---

## 34. Final Reference

The default RemoteOS Flutter dependency chain is:

```text
Widget
  ↓
View
  ↓
ViewModel
  ↓
UseCase (only when useful)
  ↓
Repository
  ↓
Service
  ↓
RemoteOS.Server / local platform
```

The lifetime chain is:

```text
Application
  ↓
Window
  ↓
ServerSession
  ↓
Feature
```

The primary architectural principle is:

> Preserve business intent, isolate platform/UI mechanics, keep dependencies directional, and make every feature small enough to reason about independently.
