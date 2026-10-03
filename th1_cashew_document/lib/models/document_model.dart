class DocumentModel {
  final int? id;
  final String title;
  final String? description;
  final String subject;
  final String type;
  final String filePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentModel({
    this.id,
    required this.title,
    this.description,
    required this.subject,
    required this.type,
    required this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });
}
