import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/features/code_editor/application/code_editor_view_model.dart';
import 'package:remoteos_client/features/code_editor/domain/code_editor_models.dart';
import 'package:remoteos_client/features/code_editor/domain/code_editor_repository.dart';

void main() {
  group('CodeEditorViewModel', () {
    test('opens remote files as tabs and re-activates an existing path',
        () async {
      final repository =
          _FakeCodeEditorRepository({'/src/main.dart': 'void main() {}'});
      final vm = CodeEditorViewModel(repository: repository);
      addTearDown(vm.dispose);

      await vm.openPath('/src/main.dart');
      vm.updateActiveDocument('changed');
      await vm.openPath('/src/main.dart');

      expect(vm.state.value.documents, hasLength(1));
      expect(vm.state.value.activeDocument?.text, 'changed');
      expect(vm.state.value.activeDocument?.isDirty, isTrue);
    });

    test('saving an untitled document requests a remote target path', () async {
      final repository = _FakeCodeEditorRepository({});
      final vm = CodeEditorViewModel(repository: repository)
        ..requestSavePath = (_) async => '/tmp/new.dart';
      addTearDown(vm.dispose);

      vm.newDocument();
      vm.updateActiveDocument('final answer = 42;');
      await vm.save();

      expect(repository.writes['/tmp/new.dart'], 'final answer = 42;');
      expect(vm.state.value.activeDocument?.path, '/tmp/new.dart');
      expect(vm.state.value.activeDocument?.isDirty, isFalse);
    });

    test('adds a workspace root and loads its immediate tree children',
        () async {
      final repository = _FakeCodeEditorRepository({})
        ..folders['/workspace'] = const [
          CodeEditorFolderNode(
              name: 'lib', path: '/workspace/lib', isDirectory: true),
          CodeEditorFolderNode(
              name: 'README.md',
              path: '/workspace/README.md',
              isDirectory: false),
        ];
      final vm = CodeEditorViewModel(repository: repository)
        ..requestFolderPath = () async => '/workspace';
      addTearDown(vm.dispose);

      await vm.addFolder();

      expect(vm.state.value.workspaceRoots.single.children, hasLength(2));
      expect(vm.state.value.workspaceRoots.single.isLoaded, isTrue);
    });
  });
}

class _FakeCodeEditorRepository implements CodeEditorRepository {
  _FakeCodeEditorRepository(this._files);
  final Map<String, String> _files;
  final Map<String, String> writes = {};
  final Map<String, List<CodeEditorFolderNode>> folders = {};

  @override
  Future<List<CodeEditorFolderNode>> listFolder(String path) async =>
      folders[path] ?? const [];

  @override
  Future<String?> readText(String path, String encodingName) async =>
      _files[path];

  @override
  Future<void> writeText(String path, String text, String encodingName) async {
    writes[path] = text;
  }
}
