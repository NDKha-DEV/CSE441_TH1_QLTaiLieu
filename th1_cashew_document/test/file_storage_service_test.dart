// import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:th1_cashew_document/application/file_storage_service.dart';

void main() {
  late FileStorageService service;

  setUp(() {
    service = FileStorageService();
  });

  test('fileExists returns false for nonexistent file', () async {
    final result = await service.fileExists('this_file_does_not_exist.pdf');

    expect(result, isFalse);
  });
}
