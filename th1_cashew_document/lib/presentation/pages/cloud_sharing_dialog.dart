import 'package:flutter/material.dart';

import '../../application/cloud_document_service.dart';

class CloudSharingDialog extends StatefulWidget {
  final CloudDocumentService service;
  final String documentId;

  const CloudSharingDialog({
    super.key,
    required this.service,
    required this.documentId,
  });

  @override
  State<CloudSharingDialog> createState() => _CloudSharingDialogState();
}

class _CloudSharingDialogState extends State<CloudSharingDialog> {
  final _uidController = TextEditingController();
  List<Map<String, dynamic>> _permissions = [];
  String _role = 'viewer';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await widget.service.getPermissions(
        widget.documentId,
      );
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách chia sẻ. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  Future<void> _grant() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.grantPermission(
        documentId: widget.documentId,
        userUid: _uidController.text,
        role: _role,
      );
      _uidController.clear();
      await _loadPermissions();
    } on ShareRecipientNotRegisteredException {
      if (mounted) {
        setState(() {
          _error =
              'Người nhận cần đăng nhập vào ứng dụng ít nhất một lần '
              'trước khi được chia sẻ tài liệu.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Không thể cấp quyền chia sẻ. Kiểm tra UID và thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(String uid) async {
    try {
      await widget.service.revokePermission(
        documentId: widget.documentId,
        userUid: uid,
      );
      await _loadPermissions();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể thu hồi quyền. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chia sẻ tài liệu'),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                shrinkWrap: true,
                children: [
                  TextField(
                    controller: _uidController,
                    decoration: const InputDecoration(
                      labelText: 'Firebase UID người nhận',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Quyền'),
                    items: const [
                      DropdownMenuItem(
                        value: 'viewer',
                        child: Text('Viewer - chỉ xem'),
                      ),
                      DropdownMenuItem(
                        value: 'editor',
                        child: Text('Editor - xem và sửa'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _role = value);
                          },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saving ? null : _grant,
                      child: const Text('Cấp quyền'),
                    ),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const Divider(),
                  if (_permissions.isEmpty)
                    const Text('Chưa chia sẻ tài liệu này.')
                  else
                    ..._permissions.map((permission) {
                      final uid = permission['user_uid'] as String;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(uid),
                        subtitle: Text(permission['role'] as String),
                        trailing: IconButton(
                          tooltip: 'Thu hồi quyền',
                          onPressed: _saving ? null : () => _revoke(uid),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      );
                    }),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
