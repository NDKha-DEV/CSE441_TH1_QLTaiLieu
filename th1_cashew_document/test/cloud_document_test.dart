import 'package:flutter_test/flutter_test.dart';
import 'package:th1_cashew_document/models/cloud_document.dart';

CloudDocument makeDocument({String? sharedRole}) {
  return CloudDocument(
    id: 'document-id',
    ownerUid: 'owner-uid',
    title: 'Study notes',
    description: null,
    subject: 'Architecture',
    type: 'PDF',
    fileName: 'notes.pdf',
    storagePath: 'document-id/notes.pdf',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    sharedRole: sharedRole,
  );
}

void main() {
  test('owner can edit their document', () {
    final document = makeDocument();

    expect(document.isOwnedBy('owner-uid'), isTrue);
    expect(document.canEdit('owner-uid'), isTrue);
  });

  test('viewer cannot edit a shared document', () {
    final document = makeDocument(sharedRole: 'viewer');

    expect(document.isOwnedBy('viewer-uid'), isFalse);
    expect(document.canEdit('viewer-uid'), isFalse);
  });

  test('editor can edit a shared document', () {
    final document = makeDocument(sharedRole: 'editor');

    expect(document.isOwnedBy('editor-uid'), isFalse);
    expect(document.canEdit('editor-uid'), isTrue);
  });
}
