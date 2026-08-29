// Image Viewer repository interface (ARCHITECTURE.md § 11).
//
// For now, only byte-level read is implemented — the same RemoteFileApi is
// used by File Manager.  Save and navigation APIs will be added in a later
// pass, alongside the Avalonia Open/Previous/Next wiring.

import 'dart:typed_data';

abstract interface class ImageRepository {
  Future<Uint8List> readBytes(String remotePath);
}
