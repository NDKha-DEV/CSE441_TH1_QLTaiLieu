import 'package:flutter/material.dart';

import '../../application/document_service.dart';
import '../../models/document_model.dart';
import 'document_form_page.dart';

class DocumentDetailPage extends StatefulWidget {
  final DocumentService documentService;
  final int documentId;

  const DocumentDetailPage({
    super.key,
    required this.documentService,
    required this.documentId,
  });

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? _document;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final document = await widget.documentService.getDocumentById(
        widget.documentId,
      );

      if (!mounted) return;

      setState(() {
        _document = document;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Không thể tải tài liệu: $e');
    }
  }

  Future<void> _editDocument() async {
    final document = _document;

    if (document == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentFormPage(
          documentService: widget.documentService,
          document: document,
        ),
      ),
    );

    if (result == true) {
      await _loadDocument();
    }
  }

  Future<void> _deleteDocument() async {
    final document = _document;

    if (document == null || document.id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa tài liệu'),
          content: Text('Bạn có chắc muốn xóa "${document.title}" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await widget.documentService.deleteDocument(document.id!);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage('Không thể xóa tài liệu: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết tài liệu')),
        body: const Center(child: Text('Không tìm thấy tài liệu.')),
      );
    }

    final document = _document!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết tài liệu'),
        actions: [
          IconButton(
            tooltip: 'Sửa',
            onPressed: _editDocument,
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: 'Xóa',
            onPressed: _deleteDocument,
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            document.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          _buildInfo('Môn học', document.subject),
          _buildInfo('Loại tài liệu', document.type),
          _buildInfo(
            'Mô tả',
            document.description?.isNotEmpty == true
                ? document.description!
                : 'Không có mô tả.',
          ),
          _buildInfo('Đường dẫn file', document.filePath),
          _buildInfo('Ngày tạo', _formatDate(document.createdAt)),
          _buildInfo('Cập nhật lần cuối', _formatDate(document.updatedAt)),
        ],
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(value),
        ],
      ),
    );
  }
}
