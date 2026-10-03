import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/tables/documents.dart';

part 'document_dao.g.dart';

@DriftAccessor(tables: [Documents])
class DocumentDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentDaoMixin {
  DocumentDao(super.db);

  Future<List<Document>> getAllDocuments() {
    return select(documents).get();
  }

  Future<Document?> getDocumentById(int id) {
    return (select(
      documents,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertDocument(DocumentsCompanion document) {
    return into(documents).insert(document);
  }

  Future<bool> updateDocument(DocumentsCompanion document) {
    return update(documents).replace(document);
  }

  Future<int> deleteDocument(int id) {
    return (delete(documents)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<List<Document>> searchDocuments(String keyword) {
    final query = select(documents)
      ..where(
        (tbl) => tbl.title.contains(keyword) | tbl.subject.contains(keyword),
      );

    return query.get();
  }
}
