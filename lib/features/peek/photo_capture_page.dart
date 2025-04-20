// lib/features/peek/photo_capture_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class PhotoCapturePage extends StatefulWidget {
  final String requestId;
  const PhotoCapturePage({super.key, required this.requestId});

  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends State<PhotoCapturePage> {
  File? _imageFile;
  bool _uploading = false;
  bool _cameraOpened = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  Future<void> _openCamera() async {
    if (_cameraOpened) return;
    _cameraOpened = true;
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (!mounted) return;
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      } else {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
        context.go('/');
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_imageFile == null || _uploading) return;
    setState(() => _uploading = true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'peeks/${widget.requestId}/$timestamp.jpg';
    final ref = FirebaseStorage.instance.ref(storagePath);

    try {
      // Upload file
      await ref.putFile(_imageFile!);
      final downloadUrl = await ref.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .update({
            'status': 'accepted',
            'storagePath': storagePath,
            'imageUrl': downloadUrl,
            'respondedAt': FieldValue.serverTimestamp(),
          });

      // Notify user and return home
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image sent')));
        context.go('/');
      }
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Peek'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body:
          _uploading
              ? const Center(child: CircularProgressIndicator())
              : _imageFile == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _uploadPhoto,
                        icon: const Icon(Icons.send),
                        label: const Text('SEND PEEK'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
