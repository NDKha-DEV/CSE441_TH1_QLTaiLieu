import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:th1_cashew_document/application/file_storage_service_web.dart';
import 'package:th1_cashew_document/models/document_file.dart';

void main() {
  test('stores picked file bytes in the browser database value', () async {
    final expectedBytes = Uint8List.fromList([1, 2, 3, 4]);
    final service = FileStorageService();
    final filePath = await service.saveFile(
      DocumentFile(
        name: 'test.pdf',
        path: null,
        readBytes: () async => expectedBytes,
      ),
    );

    expect(
      base64Decode(filePath.substring('browser-file:'.length)),
      expectedBytes,
    );
    expect(service.fileExists(filePath), completion(isTrue));
    expect(
      service.displayFilePath(filePath),
      'Đã lưu trong bộ nhớ trình duyệt',
    );
  });
}
