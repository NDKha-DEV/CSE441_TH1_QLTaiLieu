import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:th1_cashew_document/application/document_service.dart';
import 'package:th1_cashew_document/application/file_storage_service.dart';
import 'package:th1_cashew_document/data/database/app_database.dart';

void main() {
  late AppDatabase database;
  late DocumentService service;
  late Directory testDirectory;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());

    testDirectory = Directory.systemTemp.createTempSync('th1_cashew_test_');

    service = DocumentService(
      database.documentDao,
      FileStorageService(baseDirectory: testDirectory),
    );
  });

  tearDown(() async {
    await database.close();

    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('add document through service', () async {
    final sourceFile = File('${Directory.systemTemp.path}/test_document.txt');

    await sourceFile.writeAsString('Test document content');

    final document = await service.addDocument(
      title: 'Tài liệu test',
      description: 'Tài liệu kiểm thử',
      subject: 'Công nghệ phần mềm',
      type: 'TXT',
      sourceFile: sourceFile,
    );

    expect(document.id, isNotNull);
    expect(document.title, 'Tài liệu test');
    expect(document.subject, 'Công nghệ phần mềm');

    final storedFile = File(document.filePath);

    expect(await storedFile.exists(), isTrue);

    await storedFile.delete();
    await sourceFile.delete();
  });
}
