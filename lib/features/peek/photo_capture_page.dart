import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      } else if (mounted) {
        // User canceled the camera
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: ${e.toString()}')),
        );
        context.go('/');
      }
    }
  }

  Future<void> _sendPhoto() async {
    if (_imageFile == null) return;

    setState(() => _uploading = true);

    try {
      // Get file extension (e.g. jpg, png)
      final extension = _imageFile!.path.split('.').last;
      final fileName =
          'peeks/${widget.requestId}/${DateTime.now().millisecondsSinceEpoch}.$extension';

      // Upload file to default Firebase Storage bucket
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_imageFile!);

      // Get public download URL
      final downloadUrl = await ref.getDownloadURL();

      // Update Firestore with photo URL + status
      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .update({
            'status': 'accepted',
            'imageUrl': downloadUrl,
            'respondedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        context.go('/'); // Return to home or wherever appropriate
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
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
                        onPressed: _sendPhoto,
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
