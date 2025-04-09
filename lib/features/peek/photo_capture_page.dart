import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class PhotoCapturePage extends StatefulWidget {
  const PhotoCapturePage({super.key});

  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends State<PhotoCapturePage> {
  File? _imageFile;
  bool _uploading = false;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _sendPhoto() async {
    if (_imageFile == null) return;

    setState(() => _uploading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final fileName = 'peeks/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(fileName);

    try {
      print('📤 Starting photo upload to Firebase Storage...');
      print('🖼️ File path: ${_imageFile!.path}');
      print('🔗 Upload target: $fileName');

      final uploadTask = await ref.putFile(_imageFile!);

      print(
        '✅ Upload complete: ${uploadTask.bytesTransferred} bytes transferred',
      );

      await Future.delayed(const Duration(seconds: 1)); // UX pause

      if (mounted) {
        setState(() => _uploading = false);
        context.go('/'); // Go back to home after upload
      }
    } catch (e, stack) {
      print('❌ Upload failed: $e');
      print('🔍 Stack trace:\n$stack');

      setState(() => _uploading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to upload photo')));
    }
  }

  @override
  void initState() {
    super.initState();
    _takePhoto(); // Open camera on screen load
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a Peek')),
      body: Center(
        child:
            _uploading
                ? const CircularProgressIndicator()
                : _imageFile == null
                ? const Text('Opening camera...')
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.file(_imageFile!, height: 300),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _sendPhoto,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Photo'),
                    ),
                  ],
                ),
      ),
    );
  }
}
