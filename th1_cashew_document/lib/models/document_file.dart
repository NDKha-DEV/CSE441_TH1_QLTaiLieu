import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class DocumentFile {
  final String name;
  final String? path;
  final Future<Uint8List> Function() readBytes;

  const DocumentFile({
    required this.name,
    required this.path,
    required this.readBytes,
  });

  factory DocumentFile.fromPlatformFile(PlatformFile file) {
    return DocumentFile(
      name: file.name,
      path: file.path,
      readBytes: file.readAsBytes,
    );
  }
}
