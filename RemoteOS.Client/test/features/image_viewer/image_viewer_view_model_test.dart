import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remoteos_client/features/image_viewer/application/image_viewer_view_model.dart';
import 'package:remoteos_client/features/image_viewer/domain/image_repository.dart';

void main() {
  group('ImageViewerViewModel', () {
    test('loads image files in directory order and navigates both ways',
        () async {
      final repository = _FakeImageRepository(
        bytes: {
          '/pictures/a.png': [1],
          '/pictures/b.jpg': [2],
          '/pictures/c.webp': [3],
        },
        images: {
          '/pictures': const [
            ImageFile(name: 'c.webp', path: '/pictures/c.webp'),
            ImageFile(name: 'a.png', path: '/pictures/a.png'),
            ImageFile(name: 'b.jpg', path: '/pictures/b.jpg'),
          ],
        },
      );
      final vm = ImageViewerViewModel(repository: repository);
      addTearDown(vm.dispose);

      await vm.load('/pictures/b.jpg');

      expect(vm.state.value.fileName, 'b.jpg');
      expect(vm.state.value.imageIndex, 1);
      expect(vm.state.value.canGoPrevious, isTrue);
      expect(vm.state.value.canGoNext, isTrue);

      await vm.goPrevious();
      expect(vm.state.value.remotePath, '/pictures/a.png');
      expect(vm.state.value.canGoPrevious, isFalse);

      await vm.goNext();
      await vm.goNext();
      expect(vm.state.value.remotePath, '/pictures/c.webp');
      expect(vm.state.value.canGoNext, isFalse);
    });

    test('opens the file returned by the window-owned picker', () async {
      final repository = _FakeImageRepository(
        bytes: {
          'C:\\Pictures\\photo.png': [5, 6]
        },
        images: {
          'C:\\Pictures': const [
            ImageFile(name: 'photo.png', path: 'C:\\Pictures\\photo.png'),
          ],
        },
      );
      final vm = ImageViewerViewModel(repository: repository)
        ..requestImagePath = () async => 'C:\\Pictures\\photo.png';
      addTearDown(vm.dispose);

      await vm.open();

      expect(vm.state.value.fileName, 'photo.png');
      expect(vm.state.value.remotePath, 'C:\\Pictures\\photo.png');
      expect(repository.requestedDirectories, ['C:\\Pictures']);
    });

    test('limits zoom to the supported range', () {
      final vm = ImageViewerViewModel(repository: _FakeImageRepository());
      addTearDown(vm.dispose);

      vm.setZoom(12);
      expect(vm.state.value.zoom, 5);
      vm.setZoom(0);
      expect(vm.state.value.zoom, 0.1);
    });
  });
}

class _FakeImageRepository implements ImageRepository {
  _FakeImageRepository({
    this.bytes = const {},
    this.images = const {},
  });

  final Map<String, List<int>> bytes;
  final Map<String, List<ImageFile>> images;
  final List<String> requestedDirectories = [];

  @override
  Future<List<ImageFile>> listImages(String directoryPath) async {
    requestedDirectories.add(directoryPath);
    final entries = List<ImageFile>.from(images[directoryPath] ?? const [])
      ..sort((left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()));
    return entries;
  }

  @override
  Future<Uint8List> readBytes(String remotePath) async {
    final data = bytes[remotePath];
    if (data == null) throw StateError('Missing $remotePath');
    return Uint8List.fromList(data);
  }
}
