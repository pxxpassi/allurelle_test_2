import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:allurelle_test_2/analysed_image_page.dart';


class ImagePreviewPage extends StatefulWidget {
  final String imagePath;
  const ImagePreviewPage({super.key, required this.imagePath});

  @override
  _ImagePreviewPageState createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  bool _isUploading = false;
  String? processedImageUrl;

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
        print("Image uploaded: $downloadUrl");

        _showOverlayMessage("Image Uploaded Successfully!");

        // Send URL to Flask API for processing
        await _sendToFlaskAPI(context, downloadUrl);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar(context, "Upload failed: $e");

      }
    }
  }


  Future<void> _sendToFlaskAPI(BuildContext context, String imageUrl) async {
    final String flaskUrl = "http://192.168.94.137:5000/analyze"; // Update with correct IP

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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnalyzedImagePage(processedImageUrl: processedImageUrl!),
            ),
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
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
