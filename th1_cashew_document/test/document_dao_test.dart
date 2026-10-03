import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:th1_cashew_document/data/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('insert and read document', () async {
    final id = await database.documentDao.insertDocument(
      DocumentsCompanion.insert(
        title: 'Bài giảng Lập trình',
        description: const drift.Value('Tài liệu học tập'),
        subject: 'Lập trình',
        type: 'PDF',
        filePath: '/documents/programming.pdf',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final document = await database.documentDao.getDocumentById(id);

    expect(document, isNotNull);
    expect(document!.title, 'Bài giảng Lập trình');
    expect(document.subject, 'Lập trình');
  });

  test('update document', () async {
    final now = DateTime.now();

    final id = await database.documentDao.insertDocument(
      DocumentsCompanion.insert(
        title: 'Tài liệu cũ',
        description: const drift.Value('Mô tả cũ'),
        subject: 'Lập trình',
        type: 'PDF',
        filePath: '/documents/old.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final updated = await database.documentDao.updateDocument(
      DocumentsCompanion(
        id: drift.Value(id),
        title: const drift.Value('Tài liệu mới'),
        description: const drift.Value('Mô tả mới'),
        subject: const drift.Value('Cơ sở dữ liệu'),
        type: const drift.Value('DOCX'),
        filePath: const drift.Value('/documents/new.docx'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    expect(updated, isTrue);

    final document = await database.documentDao.getDocumentById(id);

    expect(document, isNotNull);
    expect(document!.title, 'Tài liệu mới');
    expect(document.subject, 'Cơ sở dữ liệu');
    expect(document.type, 'DOCX');
    expect(document.filePath, '/documents/new.docx');
  });

  test('delete document', () async {
    final id = await database.documentDao.insertDocument(
      DocumentsCompanion.insert(
        title: 'Tài liệu cần xóa',
        subject: 'Lập trình',
        type: 'PDF',
        filePath: '/documents/delete.pdf',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final deleted = await database.documentDao.deleteDocument(id);

    expect(deleted, 1);

    final document = await database.documentDao.getDocumentById(id);

    expect(document, isNull);
  });

  test('search documents by title', () async {
    final now = DateTime.now();

    await database.documentDao.insertDocument(
      DocumentsCompanion.insert(
        title: 'Lập trình C# cơ bản',
        subject: 'Lập trình',
        type: 'PDF',
        filePath: '/documents/csharp.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await database.documentDao.insertDocument(
      DocumentsCompanion.insert(
        title: 'Cơ sở dữ liệu',
        subject: 'Database',
        type: 'PDF',
        filePath: '/documents/database.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final results = await database.documentDao.searchDocuments('C#');

    expect(results.length, 1);
    expect(results.first.title, 'Lập trình C# cơ bản');
  });

  test('search documents by subject', () async {
    final now = DateTime.now();

    await database.documentDao.insertDocument(
      DocumentsCompanion.insert(
        title: 'Tài liệu 1',
        subject: 'Công nghệ phần mềm',
        type: 'PDF',
        filePath: '/documents/se.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await database.documentDao.insertDocument(
      DocumentsCompanion.insert(
        title: 'Tài liệu 2',
        subject: 'Lập trình',
        type: 'PDF',
        filePath: '/documents/programming.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final results = await database.documentDao.searchDocuments(
      'Công nghệ phần mềm',
    );

    expect(results.length, 1);
    expect(results.first.subject, 'Công nghệ phần mềm');
  });
}
