import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  static const String _documentsFolder = 'documents';

  final Directory? baseDirectory;

  FileStorageService({this.baseDirectory});

  Future<Directory> _getDocumentsDirectory() async {
    final appDirectory =
        baseDirectory ?? await getApplicationSupportDirectory();

    final documentsDirectory = Directory(
      p.join(appDirectory.path, _documentsFolder),
    );

    if (!await documentsDirectory.exists()) {
      await documentsDirectory.create(recursive: true);
    }

    return documentsDirectory;
  }

  Future<String> saveFile(File sourceFile) async {
    final directory = await _getDocumentsDirectory();

    final fileName = p.basename(sourceFile.path);
    final targetPath = p.join(directory.path, fileName);

    final savedFile = await sourceFile.copy(targetPath);

    return savedFile.path;
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }
}
