import 'package:flutter/material.dart';

import '../../application/document_service.dart';
import 'document_list_page.dart';

class CloudConfigurationPage extends StatelessWidget {
  final DocumentService documentService;
  final String accountLabel;
  final Future<void> Function() onSignOut;

  const CloudConfigurationPage({
    super.key,
    required this.documentService,
    required this.accountLabel,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chưa cấu hình Supabase')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cloud chưa được khởi tạo. Chạy ứng dụng với '
                '--dart-define=SUPABASE_URL và '
                '--dart-define=SUPABASE_PUBLISHABLE_KEY. '
                'Metadata/tệp SQLite cục bộ vẫn được giữ nguyên.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentListPage(
                        documentService: documentService,
                        accountLabel: '$accountLabel • SQLite cục bộ',
                      ),
                    ),
                  );
                },
                child: const Text('Mở dữ liệu SQLite cục bộ'),
              ),
              TextButton(onPressed: onSignOut, child: const Text('Đăng xuất')),
            ],
          ),
        ),
      ),
    );
  }
}
