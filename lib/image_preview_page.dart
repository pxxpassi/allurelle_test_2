import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;

class ImagePreviewPage extends StatefulWidget {
  final String imagePath;
  const ImagePreviewPage({super.key, required this.imagePath});

  @override
  _ImagePreviewPageState createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  bool _isUploading = false;

  Future<File> _compressImage(File file) async {
    final rawImage = img.decodeImage(await file.readAsBytes());
    if (rawImage == null) return file;

    final resizedImage = img.copyResize(rawImage, width: 800);
    final compressedImage = img.encodeJpg(resizedImage, quality: 50);

    final newFile = File(file.path)..writeAsBytesSync(compressedImage);
    return newFile;
  }

  Future<void> _uploadImage(BuildContext context) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar(context, "User not authenticated");
        return;
      }

      final file = File(widget.imagePath);
      if (!await file.exists()) {
        _showSnackBar(context, "File not found");
        return;
      }

      final fileName = "${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final storageRef = FirebaseStorage.instance.ref().child('images/$fileName');

      final compressedFile = await _compressImage(file);
      final fileBytes = await compressedFile.readAsBytes();

      UploadTask uploadTask = storageRef.putData(fileBytes);

      await uploadTask.whenComplete(() async {
        final downloadUrl = await storageRef.getDownloadURL();
        print("✅ Image uploaded: $downloadUrl");

        if (mounted) {
          setState(() => _isUploading = false);
          _showSnackBar(context, "Image uploaded successfully!", color: Colors.green);
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar(context, "Upload failed: $e");
      }
    }
  }

  void _showSnackBar(BuildContext context, String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Image.file(File(widget.imagePath))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.pinkAccent),
                  child: const Text("Retake"),
                ),
                ElevatedButton(
                  onPressed: () => _uploadImage(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
                  child: _isUploading ? const CircularProgressIndicator() : const Text("Submit"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
