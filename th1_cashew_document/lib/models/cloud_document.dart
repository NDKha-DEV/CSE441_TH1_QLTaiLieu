class CloudDocument {
  final String id;
  final String ownerUid;
  final String title;
  final String? description;
  final String subject;
  final String type;
  final String fileName;
  final String storagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sharedRole;

  const CloudDocument({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.description,
    required this.subject,
    required this.type,
    required this.fileName,
    required this.storagePath,
    required this.createdAt,
    required this.updatedAt,
    required this.sharedRole,
  });

  bool isOwnedBy(String uid) => ownerUid == uid;

  bool canEdit(String uid) => isOwnedBy(uid) || sharedRole == 'editor';
}
