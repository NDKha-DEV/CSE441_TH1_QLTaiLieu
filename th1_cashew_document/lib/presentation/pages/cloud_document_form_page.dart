import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../application/cloud_document_service.dart';
import '../../models/cloud_document.dart';
import '../../models/document_file.dart';

class CloudDocumentFormPage extends StatefulWidget {
  final CloudDocumentService service;
  final CloudDocument? document;

  const CloudDocumentFormPage({
    super.key,
    required this.service,
    this.document,
  });

  @override
  State<CloudDocumentFormPage> createState() => _CloudDocumentFormPageState();
}

class _CloudDocumentFormPageState extends State<CloudDocumentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  DocumentFile? _file;
  String? _fileName;
  String _type = 'PDF';
  bool _saving = false;

  bool get _editing => widget.document != null;

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    if (document != null) {
      _titleController.text = document.title;
      _descriptionController.text = document.description ?? '';
      _subjectController.text = document.subject;
      _type = document.type;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
        ],
      );
      if (result.isEmpty) return;

      final file = result.first;
      setState(() {
        _file = DocumentFile.fromPlatformFile(file);
        _fileName = file.name;
        _type = file.extension?.toUpperCase() ?? 'OTHER';
      });
    } catch (error) {
      _message('Không thể chọn tệp: $error');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_editing && _file == null) {
      _message('Vui lòng chọn tệp tài liệu.');
      return;
    }

    setState(() => _saving = true);
    try {
      final description = _descriptionController.text.trim();
      if (_editing) {
        await widget.service.updateDocument(
          id: widget.document!.id,
          title: _titleController.text.trim(),
          description: description.isEmpty ? null : description,
          subject: _subjectController.text.trim(),
          type: _type,
          file: _file,
        );
      } else {
        await widget.service.addDocument(
          title: _titleController.text.trim(),
          description: description.isEmpty ? null : description,
          subject: _subjectController.text.trim(),
          type: _type,
          file: _file!,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Không thể lưu tài liệu: $error');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Sửa tài liệu cloud' : 'Thêm tài liệu cloud'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tên tài liệu'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập tên tài liệu.'
                  : null,
            ),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Môn học'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập môn học.'
                  : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Mô tả'),
              maxLines: 3,
            ),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Loại tài liệu'),
              items:
                  const [
                    'PDF',
                    'DOC',
                    'DOCX',
                    'PPT',
                    'PPTX',
                    'XLS',
                    'XLSX',
                    'TXT',
                    'OTHER',
                  ].map((value) {
                    return DropdownMenuItem(value: value, child: Text(value));
                  }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _fileName ??
                    (_editing
                        ? 'Giữ tệp cloud hiện tại: ${widget.document!.fileName}'
                        : 'Chọn tệp để tải lên'),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
