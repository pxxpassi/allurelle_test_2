import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart';

class ImagePreviewPage extends StatefulWidget {
  final String imagePath;

  const ImagePreviewPage({Key? key, required this.imagePath}) : super(key: key);

  @override
  _ImagePreviewPageState createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  bool _isUploading = false;
  String _uploadStatus = '';

  Future<void> _uploadImageToFirestore(BuildContext context) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading image...';
    });

    try {
      // Check if user is authenticated
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isUploading = false;
          _uploadStatus = 'User not authenticated';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      File imageFile = File(widget.imagePath);
      String fileName = basename(imageFile.path);

      // Upload to Firebase Storage
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('images/${user.uid}/$fileName');
      await ref.putFile(imageFile);

      // Get the download URL
      String downloadURL = await ref.getDownloadURL();

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('photos').add({
        'url': downloadURL,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isUploading = false;
        _uploadStatus = 'Image successfully uploaded';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image successfully uploaded')),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Failed to upload image: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: Image.asset(
            'assets/allurelle_logo.png',
            height: 50,
            width: 50,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const Text('Image preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.pinkAccent)),
          const SizedBox(height: 10),
          Expanded(
            child: Image.file(File(widget.imagePath)),
          ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(_uploadStatus),
                ],
              ),
            ),
          if (!_isUploading)
            Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.pinkAccent,
                        backgroundColor: Colors.pink[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14.6, horizontal: 20),
                        minimumSize: const Size(70, 40),
                      ),
                      child: const Text('Retake', style: TextStyle(fontSize: 14)),
                    ),
                    ElevatedButton(
                      onPressed: () => _uploadImageToFirestore(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14.6, horizontal: 20),
                        minimumSize: const Size(70, 40),
                      ),
                      child: const Text('Proceed'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
        ],
      ),
    );
  }
}
