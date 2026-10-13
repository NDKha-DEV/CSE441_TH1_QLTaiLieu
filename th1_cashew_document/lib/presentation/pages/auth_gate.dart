import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../application/cloud_document_service.dart';
import '../../application/document_service.dart';
import 'cloud_document_list_page.dart';
import 'cloud_configuration_page.dart';
import 'document_list_page.dart';
import 'google_sign_in_page.dart';

class AuthGate extends StatelessWidget {
  final DocumentService documentService;
  final SupabaseClient? supabaseClient;

  const AuthGate({
    super.key,
    required this.documentService,
    required this.supabaseClient,
  });

  @override
  Widget build(BuildContext context) {
    final supportsCloudAuth =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!supportsCloudAuth) {
      return DocumentListPage(documentService: documentService);
    }

    final auth = FirebaseAuth.instance;
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Không thể kiểm tra trạng thái đăng nhập: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return GoogleSignInPage(
            onSignIn: () {
              final provider = GoogleAuthProvider();
              return kIsWeb
                  ? auth.signInWithPopup(provider)
                  : auth.signInWithProvider(provider);
            },
          );
        }

        final accountLabel = user.displayName ?? user.email ?? user.uid;
        final client = supabaseClient;
        if (client == null) {
          return CloudConfigurationPage(
            documentService: documentService,
            accountLabel: accountLabel,
            onSignOut: auth.signOut,
          );
        }

        return CloudDocumentListPage(
          service: CloudDocumentService(
            client: client,
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
          ),
          localService: documentService,
          accountLabel: accountLabel,
          onSignOut: auth.signOut,
        );
      },
    );
  }
}
