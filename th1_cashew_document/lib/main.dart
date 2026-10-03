import 'package:flutter/material.dart';

import 'application/document_service.dart';
import 'application/file_storage_service.dart';
import 'data/database/app_database.dart';
import 'presentation/pages/document_list_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  final documentService = DocumentService(
    database.documentDao,
    FileStorageService(),
  );

  runApp(StudyDocumentApp(documentService: documentService));
}

class StudyDocumentApp extends StatelessWidget {
  final DocumentService documentService;

  const StudyDocumentApp({super.key, required this.documentService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản lý tài liệu học tập',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: DocumentListPage(documentService: documentService),
    );
  }
}
