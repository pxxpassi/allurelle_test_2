import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:allurelle_test_2/home_page.dart'; // Ensure HomePage is correctly imported

class AnalysedPage extends StatefulWidget {
  final String processedImageUrl; // Ensure this is passed correctly
  final String faceType;
  const AnalysedPage({super.key, required this.processedImageUrl, required this.faceType});

  @override
  State<AnalysedPage> createState() => _AnalysedPageState();
}

class _AnalysedPageState extends State<AnalysedPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  String profileImageUrl = "assets/default_avatar.webp";

  @override
  void initState() {
    super.initState();
    _getUserData();
    _saveProcessedImage();
  }

  Future<void> _getUserData() async {
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null &&
            userData.containsKey('profile_image') &&
            userData['profile_image'].isNotEmpty) {
          setState(() {
            profileImageUrl = userData['profile_image'];
          });
        }
      }
    }
  }

  Future<void> _saveProcessedImage() async {
    if (user == null || widget.processedImageUrl.isEmpty) return;

    try {
      String userId = user!.uid;
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = "${userId}__${widget.faceType}_$timestamp.jpg";

      // Firebase Storage reference
      Reference storageRef =
      FirebaseStorage.instance.ref().child('processed_images/$fileName');

      // Upload the image from URL
      UploadTask uploadTask =
      storageRef.putData(await _downloadImageBytes(widget.processedImageUrl));
      TaskSnapshot taskSnapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Store metadata in Firestore
      await FirebaseFirestore.instance.collection('processed_images').doc(fileName).set({
        'userId': userId,
        'processedImageUrl': widget.processedImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Image saved successfully: $downloadUrl");
    } catch (e) {
      debugPrint("❌ Error saving image: $e");
    }
  }

  // Helper function to fetch image bytes from a network URL
  Future<Uint8List> _downloadImageBytes(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents default back navigation
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomePage()), // Ensure HomePage is correctly imported
                (route) => false,
          );
        }
      },
      child: Scaffold(
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
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 30.0, left: 10),
              child: CircleAvatar(
                backgroundImage: profileImageUrl.startsWith("http")
                    ? NetworkImage(profileImageUrl)
                    : AssetImage(profileImageUrl) as ImageProvider,
              ),
            ),
          ],
        ),
        body: Center(
          child: widget.processedImageUrl.isNotEmpty
              ? Image.network(widget.processedImageUrl)
              : const Text("No analyzed image available"),
        ),
      ),
    );
  }
}
