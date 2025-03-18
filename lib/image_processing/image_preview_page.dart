import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:allurelle_test_2/image_processing/analysed_image_page.dart';


class ImagePreviewPage extends StatefulWidget {
  final String imagePath;
  final String faceType;
  const ImagePreviewPage({super.key, required this.imagePath, required this.faceType});

  @override
  _ImagePreviewPageState createState() => _ImagePreviewPageState();
}


class _ImagePreviewPageState extends State<ImagePreviewPage> {
  bool _isUploading = false;
  String? processedImageUrl;
  final User? user = FirebaseAuth.instance.currentUser;
  String profileImageUrl = "assets/default_avatar.webp";
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<File> _compressImage(File file) async {
    final rawImage = img.decodeImage(await file.readAsBytes());
    if (rawImage == null) return file;

    final resizedImage = img.copyResize(rawImage, width: 800);
    final compressedImage = img.encodeJpg(resizedImage, quality: 50);

    final newFile = File(file.path)..writeAsBytesSync(compressedImage);
    return newFile;
  }

  Future<void> _getUserData() async {
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      setState(() {
        userData = userDoc.data() as Map<String, dynamic>?;
        profileImageUrl = (userData?['profile_image'] != null && userData?['profile_image'].isNotEmpty)
            ? userData!['profile_image']
            : "assets/default_avatar.webp";
      });
    }
  }

  Future<void> _uploadImage(BuildContext context, String faceType) async {
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

      final fileName = "${user.uid}_${widget.faceType}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final storageRef = FirebaseStorage.instance.ref().child('images/$fileName');

      final compressedFile = await _compressImage(file);
      final fileBytes = await compressedFile.readAsBytes();

      UploadTask uploadTask = storageRef.putData(fileBytes);

      await uploadTask.whenComplete(() async {
        final downloadUrl = await storageRef.getDownloadURL();
        print("Image uploaded: $downloadUrl");

        _showOverlayMessage("Image Uploaded Successfully!");

        // Send URL to Flask API for processing
        await _sendToFlaskAPI(context, downloadUrl, faceType);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar(context, "Upload failed: $e");

      }
    }
  }


  Future<void> _sendToFlaskAPI(BuildContext context, String imageUrl, String faceType) async {
    final String flaskUrl = "http://192.168.250.251:5000/analyze"; // Update with correct IP

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception("Failed to download image from Firebase.");
      }

      Uint8List imageBytes = response.bodyBytes;

      var request = http.MultipartRequest("POST", Uri.parse(flaskUrl))
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: "uploaded_image.jpg",
          contentType: MediaType("image", "jpeg"),
        ));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var responseData = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseData);
        if (data.containsKey("processed_image_url")) {
          setState(() {
            processedImageUrl = data["processed_image_url"];  // ✅ Updates UI dynamically
          });
          print("Processed Image Updated: $processedImageUrl");
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => AnalysedPage(processedImageUrl: processedImageUrl!, faceType: faceType),
            ),
                (route) => false, // This removes all previous routes (including camera)
          );
        }
        else {
          throw Exception("Invalid response from API");
        }
      } else {
        throw Exception("Failed to process image: ${streamedResponse.statusCode}");
      }
    } catch (e) {
      _showSnackBar(context, "Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }


  void _showSnackBar(BuildContext context, String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showOverlayMessage(String message) {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 600,
        left: MediaQuery.of(context).size.width * 0.175 ,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry?.remove();
    });
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: processedImageUrl == null // ✅ Display processed image if available
                ? Image.file(File(widget.imagePath))
                : Image.network(processedImageUrl!),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isUploading ? null : () => Navigator.pop(context), // Disable only if uploading
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.pinkAccent),
                  child: const Text("Retake"),
                ),
                ElevatedButton(
                  onPressed: _isUploading ? null : () => _uploadImage(context, widget.faceType),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
                  child: _isUploading
                      ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                      : const Text("Submit"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
