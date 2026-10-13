import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import 'application/document_service.dart';
import 'application/document_insert_diagnostics_client.dart';
import 'application/file_storage_service.dart';
import 'data/database/app_database.dart';
import 'firebase_options.dart';
import 'presentation/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  if (supabaseUrl.isEmpty != supabasePublishableKey.isEmpty) {
    throw StateError(
      'Both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be configured.',
    );
  }
  SupabaseClient? supabaseClient;

  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    String? refreshedClaimsForUid;
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      debug: false,
      httpClient: DocumentInsertDiagnosticsClient(http.Client()),
      accessToken: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        if (refreshedClaimsForUid != user.uid) {
          final token = await user.getIdToken(true);
          if (token != null) refreshedClaimsForUid = user.uid;
          return token;
        }
        return user.getIdToken();
      },
    );
    supabaseClient = Supabase.instance.client;
  }

  final database = AppDatabase();

  final documentService = DocumentService(
    database.documentDao,
    FileStorageService(),
  );

  runApp(
    StudyDocumentApp(
      documentService: documentService,
      supabaseClient: supabaseClient,
    ),
  );
}

class StudyDocumentApp extends StatelessWidget {
  final DocumentService documentService;
  final SupabaseClient? supabaseClient;

  const StudyDocumentApp({
    super.key,
    required this.documentService,
    required this.supabaseClient,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản lý tài liệu học tập',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: AuthGate(
        documentService: documentService,
        supabaseClient: supabaseClient,
      ),
    );
  }
}
