import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DocumentInsertDiagnosticsClient extends http.BaseClient {
  final http.Client _inner;

  DocumentInsertDiagnosticsClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' &&
        request.url.path.endsWith('/rest/v1/documents') &&
        request is http.Request) {
      _logDocumentInsertClaims(request);
    }
    return _inner.send(request);
  }

  void _logDocumentInsertClaims(http.Request request) {
    final authorization = request.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value)
        .firstOrNull;
    final token = authorization != null && authorization.startsWith('Bearer ')
        ? authorization.substring('Bearer '.length)
        : null;
    final claims = _decodeClaims(token);
    final body = _decodeBody(request.body);
    final ownerUid = body?['owner_uid'];
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;

    debugPrint('documentsInsertHasBearerToken=${token != null}');
    debugPrint(
      'documentsInsertOwnerMatchesRequestSub='
      '${ownerUid is String && ownerUid == claims['sub']}',
    );
    debugPrint(
      'documentsInsertRequestSubMatchesFirebaseUid='
      '${firebaseUid != null && claims['sub'] == firebaseUid}',
    );
    debugPrint(
      'documentsInsertRequestRoleIsAuthenticated='
      '${claims['role'] == 'authenticated'}',
    );
    debugPrint(
      'documentsInsertRequestAudienceMatchesProject='
      '${claims['aud'] == 'mobileth1qltailieu'}',
    );
    debugPrint(
      'documentsInsertRequestIssuerMatchesProject='
      '${claims['iss'] == 'https://securetoken.google.com/mobileth1qltailieu'}',
    );
    final expiration = claims['exp'];
    final tokenNotExpired =
        expiration is num &&
        expiration > DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    debugPrint('documentsInsertRequestTokenNotExpired=$tokenNotExpired');
  }

  Map<String, dynamic> _decodeClaims(String? token) {
    if (token == null) return const {};
    final segments = token.split('.');
    if (segments.length != 3) return const {};

    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  Map<String, dynamic>? _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  void close() => _inner.close();
}
