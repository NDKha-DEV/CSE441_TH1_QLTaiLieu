import 'dart:convert';

import '../models/document_file.dart';

class FileStorageService {
  static const String _browserFilePrefix = 'browser-file:';

  FileStorageService();

  Future<String> saveFile(DocumentFile sourceFile) async {
    final contents = base64Encode(await sourceFile.readBytes());
    return '$_browserFilePrefix$contents';
  }

  Future<void> deleteFile(String filePath) async {
    // The file bytes live in the database row, so deleting the row removes them.
  }

  Future<bool> fileExists(String filePath) async {
    return filePath.startsWith(_browserFilePrefix);
  }

  String displayFilePath(String filePath) {
    return filePath.startsWith(_browserFilePrefix)
        ? 'Đã lưu trong bộ nhớ trình duyệt'
        : filePath;
  }
}
