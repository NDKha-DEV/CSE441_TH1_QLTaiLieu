import 'dart:io';

import 'package:drift/drift.dart';

import '../data/dao/document_dao.dart';
import '../data/database/app_database.dart';
import '../models/document_model.dart';
import 'file_storage_service.dart';

class DocumentService {
  final DocumentDao _documentDao;
  final FileStorageService _fileStorageService;

  DocumentService(this._documentDao, this._fileStorageService);

  Future<List<DocumentModel>> getAllDocuments() async {
    final documents = await _documentDao.getAllDocuments();

    return documents.map(_toModel).toList();
  }

  Future<DocumentModel?> getDocumentById(int id) async {
    final document = await _documentDao.getDocumentById(id);

    if (document == null) {
      return null;
    }

    return _toModel(document);
  }

  Future<DocumentModel> addDocument({
    required String title,
    String? description,
    required String subject,
    required String type,
    required File sourceFile,
  }) async {
    final filePath = await _fileStorageService.saveFile(sourceFile);

    final now = DateTime.now();

    final id = await _documentDao.insertDocument(
      DocumentsCompanion.insert(
        title: title,
        description: description == null
            ? const Value(null)
            : Value(description),
        subject: subject,
        type: type,
        filePath: filePath,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final document = await _documentDao.getDocumentById(id);

    if (document == null) {
      await _fileStorageService.deleteFile(filePath);
      throw Exception('Không thể lấy tài liệu vừa tạo.');
    }

    return _toModel(document);
  }

  Future<DocumentModel> updateDocument({
    required int id,
    required String title,
    String? description,
    required String subject,
    required String type,
  }) async {
    final existing = await _documentDao.getDocumentById(id);

    if (existing == null) {
      throw Exception('Không tìm thấy tài liệu.');
    }

    final updated = await _documentDao.updateDocument(
      DocumentsCompanion(
        id: Value(existing.id),
        title: Value(title),
        description: Value(description),
        subject: Value(subject),
        type: Value(type),
        filePath: Value(existing.filePath),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (!updated) {
      throw Exception('Không thể cập nhật tài liệu.');
    }

    final document = await _documentDao.getDocumentById(id);

    if (document == null) {
      throw Exception('Không thể lấy tài liệu sau khi cập nhật.');
    }

    return _toModel(document);
  }

  Future<void> deleteDocument(int id) async {
    final document = await _documentDao.getDocumentById(id);

    if (document == null) {
      throw Exception('Không tìm thấy tài liệu.');
    }

    await _documentDao.deleteDocument(id);

    await _fileStorageService.deleteFile(document.filePath);
  }

  Future<List<DocumentModel>> searchDocuments(String keyword) async {
    final documents = await _documentDao.searchDocuments(keyword);

    return documents.map(_toModel).toList();
  }

  DocumentModel _toModel(Document document) {
    return DocumentModel(
      id: document.id,
      title: document.title,
      description: document.description,
      subject: document.subject,
      type: document.type,
      filePath: document.filePath,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
    );
  }
}
