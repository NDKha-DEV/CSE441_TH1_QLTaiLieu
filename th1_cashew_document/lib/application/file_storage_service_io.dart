import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document_file.dart';

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

  Future<String> saveFile(DocumentFile sourceFile) async {
    final directory = await _getDocumentsDirectory();
    final targetPath = p.join(directory.path, p.basename(sourceFile.name));
    final sourcePath = sourceFile.path;

    if (sourcePath != null) {
      return (await File(sourcePath).copy(targetPath)).path;
    }

    await File(targetPath).writeAsBytes(await sourceFile.readBytes());
    return targetPath;
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> fileExists(String filePath) {
    return File(filePath).exists();
  }

  String displayFilePath(String filePath) => filePath;
}
