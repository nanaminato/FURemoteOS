// Docker Manager App — backwards-compatible shell.
//
// The feature implementation now lives in `lib/features/docker/` following
// the ARCHITECTURE.md feature-first MVVM layout:
//
//   features/docker/
//     application/
//       docker_repository.dart    (DockerRepository interface + impl)
//       docker_view_model.dart    (DockerViewModel — presentation logic)
//     data/
//       remote_docker_api.dart    (RemoteDockerApi — REST service layer)
//     domain/
//       docker_ui_state.dart      (DockerUiState — immutable view state)
//     presentation/
//       docker_view.dart          (DockerView — main layout / dialog glue)
//       components/docker_components.dart (shared primitives)
//       pages/...                 (6 resource pages)
//       dialogs/...               (8 dialogs)
//
// This file exists so existing references (`appRegistryProvider`, app launch
// paths, tests) continue to work without code changes.  It simply delegates
// to the new [DockerView].  The ViewModel is obtained from get_it via the
// factory registration in `dependency_injection.dart`.

import 'package:flutter/material.dart';

import '../../features/docker/presentation/docker_view.dart';

/// Entry point used by AppRegistry to launch the Docker manager in a window.
/// Migration note: previously a 2459-line monolith containing a ChangeNotifier
/// VM, 6 pages and 8 dialogs.  All implementation is now in `features/docker/`.
class DockerManagerApp extends StatelessWidget {
  const DockerManagerApp({super.key});

  @override
  Widget build(BuildContext context) => const DockerView();
}
