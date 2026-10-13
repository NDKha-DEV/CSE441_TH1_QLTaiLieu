import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cloud_document.dart';
import '../models/document_file.dart';

class ShareRecipientNotRegisteredException implements Exception {
  const ShareRecipientNotRegisteredException();
}

class CloudDocumentService {
  static const String bucketName = 'documents';

  final SupabaseClient client;
  final String uid;
  final String? email;
  final String? displayName;

  CloudDocumentService({
    required this.client,
    required this.uid,
    this.email,
    this.displayName,
  });

  String get currentUid => uid;

  Future<List<CloudDocument>> getDocuments({String keyword = ''}) async {
    await _upsertCurrentUser();
    final rows = await client.from('documents').select();
    final permissions = await client
        .from('permissions')
        .select('document_id, role')
        .eq('user_uid', uid);
    final rolesByDocument = {
      for (final row in permissions)
        row['document_id'] as String: row['role'] as String,
    };
    final normalizedKeyword = keyword.trim().toLowerCase();

    return rows
        .map((row) => _toDocument(row, sharedRole: rolesByDocument[row['id']]))
        .where(
          (document) =>
              normalizedKeyword.isEmpty ||
              document.title.toLowerCase().contains(normalizedKeyword) ||
              document.subject.toLowerCase().contains(normalizedKeyword),
        )
        .toList();
  }

  Future<CloudDocument> getDocument(String id) async {
    await _upsertCurrentUser();
    final row = await client.from('documents').select().eq('id', id).single();
    final permission = await client
        .from('permissions')
        .select('role')
        .eq('document_id', id)
        .eq('user_uid', uid)
        .maybeSingle();

    return _toDocument(row, sharedRole: permission?['role'] as String?);
  }

  Future<CloudDocument> addDocument({
    required String title,
    required String? description,
    required String subject,
    required String type,
    required DocumentFile file,
  }) async {
    await _upsertCurrentUser();
    final id = _newUuid();
    final fileName = _safeFileName(file.name);
    final storagePath = '$id/$fileName';
    final ownerUid = uid;
    await client.from('documents').insert({
      'id': id,
      'owner_uid': ownerUid,
      'title': title,
      'description': description,
      'subject': subject,
      'document_type': type,
      'file_name': fileName,
      'storage_path': storagePath,
    });

    try {
      await client.storage
          .from(bucketName)
          .uploadBinary(
            storagePath,
            await file.readBytes(),
            fileOptions: const FileOptions(
              contentType: 'application/octet-stream',
            ),
          );
    } catch (uploadError) {
      try {
        await client.from('documents').delete().eq('id', id);
      } catch (cleanupError) {
        throw StateError(
          'Tải tệp lên thất bại ($uploadError) và không thể dọn metadata '
          '($cleanupError). Tài liệu có thể cần được xóa thủ công.',
        );
      }
      rethrow;
    }

    final createdAt = DateTime.now().toUtc();
    return CloudDocument(
      id: id,
      ownerUid: ownerUid,
      title: title,
      description: description,
      subject: subject,
      type: type,
      fileName: fileName,
      storagePath: storagePath,
      createdAt: createdAt,
      updatedAt: createdAt,
      sharedRole: null,
    );
  }

  Future<void> updateDocument({
    required String id,
    required String title,
    required String? description,
    required String subject,
    required String type,
    DocumentFile? file,
  }) async {
    final updates = <String, dynamic>{
      'title': title,
      'description': description,
      'subject': subject,
      'document_type': type,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (file != null) {
      final document = await getDocument(id);
      await client.storage
          .from(bucketName)
          .uploadBinary(
            document.storagePath,
            await file.readBytes(),
            fileOptions: const FileOptions(
              contentType: 'application/octet-stream',
              upsert: true,
            ),
          );
      updates['file_name'] = _safeFileName(file.name);
    }

    final updated = await client
        .from('documents')
        .update(updates)
        .eq('id', id)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Không tìm thấy tài liệu hoặc bạn không có quyền sửa.');
    }
  }

  Future<void> deleteDocument(CloudDocument document) async {
    await client.storage.from(bucketName).remove([document.storagePath]);
    await client.from('documents').delete().eq('id', document.id);
  }

  Future<String> createDownloadUrl(CloudDocument document) {
    return client.storage
        .from(bucketName)
        .createSignedUrl(
          document.storagePath,
          60,
          download: DownloadBehavior.withOriginalName,
        );
  }

  Future<List<Map<String, dynamic>>> getPermissions(String documentId) async {
    final rows = await client
        .from('permissions')
        .select('user_uid, role')
        .eq('document_id', documentId)
        .order('user_uid');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> grantPermission({
    required String documentId,
    required String userUid,
    required String role,
  }) async {
    final targetUid = userUid.trim();
    if (targetUid.isEmpty || targetUid == uid) {
      throw ArgumentError('Nhập UID khác UID của chủ sở hữu.');
    }
    if (role != 'viewer' && role != 'editor') {
      throw ArgumentError.value(role, 'role', 'Quyền không hợp lệ.');
    }

    try {
      await client.from('permissions').upsert({
        'document_id': documentId,
        'user_uid': targetUid,
        'role': role,
        'granted_by': uid,
      }, onConflict: 'document_id,user_uid');
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw const ShareRecipientNotRegisteredException();
      }
      rethrow;
    }
  }

  Future<void> revokePermission({
    required String documentId,
    required String userUid,
  }) async {
    await client
        .from('permissions')
        .delete()
        .eq('document_id', documentId)
        .eq('user_uid', userUid);
  }

  Future<void> _upsertCurrentUser() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw StateError(
        'A Firebase user must be signed in before profile upsert.',
      );
    }

    await _diagnoseTokenClaims(firebaseUser);
    await client.from('users').upsert({
      'firebase_uid': uid,
      'email': email,
      'display_name': displayName,
    }, onConflict: 'firebase_uid');
  }

  Future<void> _diagnoseTokenClaims(firebase_auth.User firebaseUser) async {
    final tokenResult = await firebaseUser.getIdTokenResult(true);
    final claims = tokenResult.claims ?? const <String, dynamic>{};

    final subMatchesFirebaseUid =
        claims['sub'] == firebaseUser.uid && firebaseUser.uid == uid;
    final roleIsAuthenticated = claims['role'] == 'authenticated';
    final audienceMatchesProject = claims['aud'] == 'mobileth1qltailieu';
    final issuerMatchesProject =
        claims['iss'] == 'https://securetoken.google.com/mobileth1qltailieu';

    debugPrint('subMatchesFirebaseUid=$subMatchesFirebaseUid');
    debugPrint('roleIsAuthenticated=$roleIsAuthenticated');
    debugPrint('audienceMatchesProject=$audienceMatchesProject');
    debugPrint('issuerMatchesProject=$issuerMatchesProject');
  }

  CloudDocument _toDocument(Map<String, dynamic> row, {String? sharedRole}) {
    return CloudDocument(
      id: row['id'] as String,
      ownerUid: row['owner_uid'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      subject: row['subject'] as String,
      type: row['document_type'] as String,
      fileName: row['file_name'] as String,
      storagePath: row['storage_path'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      sharedRole: sharedRole,
    );
  }

  String _safeFileName(String name) {
    final baseName = name.replaceAll('\\', '/').split('/').last.trim();
    if (baseName.isEmpty || baseName == '.' || baseName == '..') {
      throw ArgumentError.value(name, 'name', 'Tên tệp không hợp lệ.');
    }
    return baseName.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
  }

  String _newUuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
