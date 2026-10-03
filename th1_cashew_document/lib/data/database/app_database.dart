import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../dao/document_dao.dart';
import 'tables/documents.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Documents], daos: [DocumentDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();

    final file = File(p.join(directory.path, 'study_documents.sqlite'));

    return NativeDatabase.createInBackground(file);
  });
}
