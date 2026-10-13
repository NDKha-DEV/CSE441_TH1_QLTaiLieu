import 'package:drift/drift.dart';

import '../dao/document_dao.dart';
import 'database_connection_native.dart'
    if (dart.library.js_interop) 'database_connection_web.dart'
    as connection;
import 'tables/documents.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Documents], daos: [DocumentDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connection.openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;
}
