import 'package:flutter/material.dart';

import '../../application/document_service.dart';
import '../../models/document_model.dart';
import 'document_detail_page.dart';
import 'document_form_page.dart';

class DocumentListPage extends StatefulWidget {
  final DocumentService documentService;

  const DocumentListPage({super.key, required this.documentService});

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final documents = _keyword.trim().isEmpty
          ? await widget.documentService.getAllDocuments()
          : await widget.documentService.searchDocuments(_keyword.trim());

      if (!mounted) {
        return;
      }

      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage('Không thể tải tài liệu: $e');
    }
  }

  Future<void> _search(String keyword) async {
    _keyword = keyword;
    await _loadDocuments();
  }

  Future<void> _openAddDocumentPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DocumentFormPage(documentService: widget.documentService),
      ),
    );

    if (result == true) {
      await _loadDocuments();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _getFileIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;

      case 'DOC':
      case 'DOCX':
        return Icons.description;

      case 'PPT':
      case 'PPTX':
        return Icons.slideshow;

      case 'XLS':
      case 'XLSX':
        return Icons.table_chart;

      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu học tập'),
        actions: [
          IconButton(
            tooltip: 'Thêm tài liệu',
            onPressed: _openAddDocumentPage,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Tìm kiếm tài liệu',
                hintText: 'Nhập tên hoặc môn học...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(child: _buildDocumentList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDocumentPage,
        icon: const Icon(Icons.add),
        label: const Text('Thêm tài liệu'),
      ),
    );
  }

  Widget _buildDocumentList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_documents.isEmpty) {
      return const Center(
        child: Text('Chưa có tài liệu.', style: TextStyle(fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final document = _documents[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(_getFileIcon(document.type), size: 32),
            title: Text(
              document.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${document.subject} • ${document.type}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentDetailPage(
                    documentService: widget.documentService,
                    documentId: document.id!,
                  ),
                ),
              );

              if (result == true) {
                await _loadDocuments();
              }
            },
          ),
        );
      },
    );
  }
}
