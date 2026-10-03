import 'package:flutter/material.dart';

void main() {
  runApp(const DocumentApp());
}

class DocumentApp extends StatelessWidget {
  const DocumentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study Document Manager',
      home: Scaffold(
        appBar: AppBar(title: const Text('Study Document Manager')),
        body: const Center(child: Text('TH1 - Cashew Architecture')),
      ),
    );
  }
}
