import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../application/document_service.dart';
import '../../models/document_model.dart';

class DocumentFormPage extends StatefulWidget {
  final DocumentService documentService;
  final DocumentModel? document;

  const DocumentFormPage({
    super.key,
    required this.documentService,
    this.document,
  });

  @override
  State<DocumentFormPage> createState() => _DocumentFormPageState();
}

class _DocumentFormPageState extends State<DocumentFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();

  File? _selectedFile;
  String? _selectedFileName;
  String _selectedType = 'PDF';

  bool _isSaving = false;

  bool get _isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();

    final document = widget.document;

    if (document != null) {
      _titleController.text = document.title;
      _descriptionController.text = document.description ?? '';
      _subjectController.text = document.subject;
      _selectedType = document.type;
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

      if (result == null || result.isEmpty) {
        return;
      }

      final pickedFile = result.first;

      final extension = pickedFile.extension?.toUpperCase() ?? 'OTHER';

      setState(() {
        _selectedFile = File(pickedFile.path!);
        _selectedFileName = pickedFile.name;
        _selectedType = extension;
      });
    } catch (e) {
      _showMessage('Không thể chọn file: $e');
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Khi thêm mới bắt buộc phải chọn file.
    // Khi sửa thì có thể giữ nguyên file hiện tại.
    if (!_isEditing && _selectedFile == null) {
      _showMessage('Vui lòng chọn file tài liệu.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        await widget.documentService.updateDocument(
          id: widget.document!.id!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          subject: _subjectController.text.trim(),
          type: _selectedType,
        );
      } else {
        await widget.documentService.addDocument(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          subject: _subjectController.text.trim(),
          type: _selectedType,
          sourceFile: _selectedFile!,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        _isEditing
            ? 'Không thể cập nhật tài liệu: $e'
            : 'Không thể lưu tài liệu: $e',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa tài liệu' : 'Thêm tài liệu'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tên tài liệu',
                  hintText: 'Nhập tên tài liệu',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên tài liệu.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Môn học',
                  hintText: 'Ví dụ: Công nghệ phần mềm',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập môn học.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  hintText: 'Nhập mô tả tài liệu (không bắt buộc)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Loại tài liệu',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                  DropdownMenuItem(value: 'DOC', child: Text('DOC')),
                  DropdownMenuItem(value: 'DOCX', child: Text('DOCX')),
                  DropdownMenuItem(value: 'PPT', child: Text('PPT')),
                  DropdownMenuItem(value: 'PPTX', child: Text('PPTX')),
                  DropdownMenuItem(value: 'XLS', child: Text('XLS')),
                  DropdownMenuItem(value: 'XLSX', child: Text('XLSX')),
                  DropdownMenuItem(value: 'TXT', child: Text('TXT')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Chọn file.
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _selectedFileName == null
                      ? _isEditing
                            ? 'Đổi file tài liệu'
                            : 'Chọn file tài liệu'
                      : 'Đổi file tài liệu',
                ),
              ),

              // Hiển thị file vừa chọn.
              if (_selectedFileName != null) ...[
                const SizedBox(height: 10),
                _buildFileInfo(fileName: _selectedFileName!),
              ],

              // Khi sửa nhưng chưa chọn file mới,
              // hiển thị file hiện tại.
              if (_isEditing && _selectedFileName == null) ...[
                const SizedBox(height: 10),
                _buildFileInfo(
                  fileName: widget.document!.filePath,
                  isCurrentFile: true,
                ),
              ],

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isSaving ? null : _saveDocument,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Đang lưu...'
                      : _isEditing
                      ? 'Lưu thay đổi'
                      : 'Lưu tài liệu',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfo({
    required String fileName,
    bool isCurrentFile = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCurrentFile ? 'File hiện tại: $fileName' : fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
