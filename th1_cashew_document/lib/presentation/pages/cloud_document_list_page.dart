import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/cloud_document_service.dart';
import '../../application/document_service.dart';
import '../../models/cloud_document.dart';
import 'cloud_document_detail_page.dart';
import 'cloud_document_form_page.dart';
import 'document_list_page.dart';

class CloudDocumentListPage extends StatefulWidget {
  final CloudDocumentService service;
  final DocumentService localService;
  final String accountLabel;
  final Future<void> Function() onSignOut;

  const CloudDocumentListPage({
    super.key,
    required this.service,
    required this.localService,
    required this.accountLabel,
    required this.onSignOut,
  });

  @override
  State<CloudDocumentListPage> createState() => _CloudDocumentListPageState();
}

class _CloudDocumentListPageState extends State<CloudDocumentListPage> {
  final _searchController = TextEditingController();
  List<CloudDocument> _documents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final documents = await widget.service.getDocuments(
        keyword: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'Supabase chưa sẵn sàng: ${error.message}. '
            'Hãy áp dụng migration và tạo bucket/policies trước.';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải tài liệu cloud: $error';
        _loading = false;
      });
    }
  }

  Future<void> _addDocument() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudDocumentFormPage(service: widget.service),
      ),
    );
    if (result == true) await _loadDocuments();
  }

  Future<void> _openDocument(CloudDocument document) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudDocumentDetailPage(
          service: widget.service,
          documentId: document.id,
        ),
      ),
    );
    if (result == true) await _loadDocuments();
  }

  Future<void> _openLocalDocuments() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentListPage(
          documentService: widget.localService,
          accountLabel: '${widget.accountLabel} • SQLite cục bộ',
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await widget.onSignOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể đăng xuất: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu cloud'),
        actions: [
          IconButton(
            tooltip: 'Dữ liệu SQLite cục bộ',
            onPressed: _openLocalDocuments,
            icon: const Icon(Icons.storage),
          ),
          IconButton(
            tooltip: 'Đăng xuất: ${widget.accountLabel}',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadDocuments(),
              decoration: InputDecoration(
                labelText: 'Tìm tài liệu theo tên hoặc môn học',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Tìm kiếm',
                  onPressed: _loadDocuments,
                  icon: const Icon(Icons.search),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDocument,
        icon: const Icon(Icons.add),
        label: const Text('Thêm tài liệu'),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadDocuments,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_documents.isEmpty) {
      return const Center(child: Text('Chưa có tài liệu cloud.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final document = _documents[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.description),
            title: Text(
              document.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${document.subject} • ${document.type}'
              '${document.sharedRole == null ? '' : ' • ${document.sharedRole}'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDocument(document),
          ),
        );
      },
    );
  }
}
