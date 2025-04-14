import 'package:flutter/material.dart';

class DiagnosticHomePage extends StatelessWidget {
  const DiagnosticHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peek App (Diagnostic)')),
      body: const Center(
        child: Text('✅ HomePage loaded!', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
