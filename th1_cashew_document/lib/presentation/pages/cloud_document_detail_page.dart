import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/cloud_document_service.dart';
import '../../models/cloud_document.dart';
import 'cloud_document_form_page.dart';
import 'cloud_sharing_dialog.dart';

class CloudDocumentDetailPage extends StatefulWidget {
  final CloudDocumentService service;
  final String documentId;

  const CloudDocumentDetailPage({
    super.key,
    required this.service,
    required this.documentId,
  });

  @override
  State<CloudDocumentDetailPage> createState() =>
      _CloudDocumentDetailPageState();
}

class _CloudDocumentDetailPageState extends State<CloudDocumentDetailPage> {
  CloudDocument? _document;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final document = await widget.service.getDocument(widget.documentId);
      if (!mounted) return;
      setState(() {
        _document = document;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Không thể tải tài liệu: $error');
    }
  }

  Future<void> _download() async {
    try {
      final document = _document!;
      final url = await widget.service.createDownloadUrl(document);
      if (!await launchUrl(Uri.parse(url))) {
        throw StateError('Trình duyệt không mở được liên kết tải tệp.');
      }
    } catch (error) {
      _message('Không thể tải tệp: $error');
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudDocumentFormPage(
          service: widget.service,
          document: _document!,
        ),
      ),
    );
    if (result == true) await _loadDocument();
  }

  Future<void> _share() async {
    await showDialog<void>(
      context: context,
      builder: (_) => CloudSharingDialog(
        service: widget.service,
        documentId: widget.documentId,
      ),
    );
  }

  Future<void> _delete() async {
    final document = _document!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài liệu'),
        content: Text('Xóa "${document.title}" và tệp cloud?'),
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
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.service.deleteDocument(document);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message('Không thể xóa tài liệu: $error');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final document = _document;
    if (document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết tài liệu cloud')),
        body: const Center(child: Text('Không tìm thấy tài liệu.')),
      );
    }

    final isOwner = document.isOwnedBy(widget.service.currentUid);
    final canEdit = document.canEdit(widget.service.currentUid);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết tài liệu cloud'),
        actions: [
          IconButton(
            tooltip: 'Tải tệp',
            onPressed: _download,
            icon: const Icon(Icons.download),
          ),
          if (isOwner)
            IconButton(
              tooltip: 'Chia sẻ',
              onPressed: _share,
              icon: const Icon(Icons.share),
            ),
          if (canEdit)
            IconButton(
              tooltip: 'Sửa metadata',
              onPressed: _edit,
              icon: const Icon(Icons.edit),
            ),
          if (isOwner)
            IconButton(
              tooltip: 'Xóa',
              onPressed: _delete,
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
          _info('Chủ sở hữu UID', document.ownerUid),
          _info('Môn học', document.subject),
          _info('Loại tài liệu', document.type),
          _info('Mô tả', document.description ?? 'Không có mô tả.'),
          _info('Tên tệp', document.fileName),
          _info('Storage path', document.storagePath),
          _info(
            'Quyền hiện tại',
            isOwner ? 'owner' : (document.sharedRole ?? 'viewer'),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          SelectableText(value),
        ],
      ),
    );
  }
}
