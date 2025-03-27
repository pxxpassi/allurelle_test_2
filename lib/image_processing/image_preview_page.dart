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
// import 'package:connectivity_plus/connectivity_plus.dart';


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
  List<Map<String, dynamic>> detectedIssues = [];

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

  Future<void> _uploadImage(BuildContext context) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      if (user == null) {
        _showSnackBar(context, "User not authenticated");
        return;
      }

      final file = File(widget.imagePath);
      if (!await file.exists()) {
        _showSnackBar(context, "File not found");
        return;
      }

      // Generate unique image ID
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String imageId = "${widget.faceType}_$timestamp";
      String fileName = "$imageId.jpg";
      final storageRef = FirebaseStorage.instance.ref().child('images/$fileName');

      final compressedFile = await _compressImage(file);
      final fileBytes = await compressedFile.readAsBytes();
      UploadTask uploadTask = storageRef.putData(fileBytes);

      await uploadTask.whenComplete(() async {
        final uploadedImageUrl = await storageRef.getDownloadURL();
        await _sendToFlaskAPI(context, uploadedImageUrl);
      });
    } catch (e) {
      _showSnackBar(context, "Upload failed: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }



  Future<String> getIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }
      throw Exception("No local network IP found");
    } catch (e) {
      throw Exception("Failed to get IP: $e");
    }
  }

  Future<String> getFlaskUrl() async {
    String ipAddress = await getIpAddress();
    return 'http://192.168.118.137:5000/analyze';
  }

  Future<void> _sendToFlaskAPI(BuildContext context, String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception("Failed to download image");

      Uint8List imageBytes = response.bodyBytes;
      var request = http.MultipartRequest("POST", Uri.parse('http://172.16.20.58:5000/analyze'))
        ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: "uploaded.jpg", contentType: MediaType("image", "jpeg")));

      var streamedResponse = await request.send();
      var responseData = await streamedResponse.stream.bytesToString();
      if (streamedResponse.statusCode == 200) {
        var jsonResponse = json.decode(responseData);
        final Map<String, dynamic> data = jsonDecode(responseData);

        if (data.containsKey("processed_image_url")) {
          String processedImageUrl = data["processed_image_url"];
          String firebaseProcessedImageUrl = await _uploadProcessedImageToStorage(processedImageUrl);

          detectedIssues = List<Map<String, dynamic>>.from(jsonResponse["issues_detected"]);
          print("Detected Issues: $detectedIssues");
          await _saveProcessedImageToFirestore(imageUrl, firebaseProcessedImageUrl,detectedIssues);

          if (mounted) {
            setState(() => this.processedImageUrl = firebaseProcessedImageUrl);

          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => AnalysedPage(uploadedImageUrl: imageUrl, processedImageUrl: firebaseProcessedImageUrl, faceType: widget.faceType),
            ),
                (route) => false,
          );
        }
      } else {
        throw Exception("Processing failed");
      }
    } catch (e) {
      _showSnackBar(context, "Error: $e");
    }
  }



  Future<String> _uploadProcessedImageToStorage(String processedImageUrl) async {
    final response = await http.get(Uri.parse(processedImageUrl));

    if (response.statusCode != 200) throw Exception("Failed to download processed image");

    Uint8List imageBytes = response.bodyBytes;
    String fileName = "${user!.uid}_${widget.faceType}_processed_${DateTime.now().millisecondsSinceEpoch}.jpg";
    Reference storageRef = FirebaseStorage.instance.ref().child('processed_images/$fileName');
    UploadTask uploadTask = storageRef.putData(imageBytes);
    TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }

  Future<void> _saveProcessedImageToFirestore(String uploadedImageUrl, String processedImageUrl, List<Map<String, dynamic>> detectedIssues) async {
    try {
      String timestamp = DateTime.now().toString();
      String imageId = "${widget.faceType}_$timestamp"; // Unique image ID

      List<String> issueNames = detectedIssues.map((issue) {
        String label = issue["label"];
        return label.split(" (")[0]; // Extract text before " ("
      }).toList();

      Set<String> issueNamesSet = issueNames.toSet();


      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('image_responses')
          .doc(imageId)
          .set({
        'imageId': imageId,
        'uploadedImageUrl': uploadedImageUrl,
        'processedImageUrl': processedImageUrl,
        'faceType': widget.faceType,
        'detectedIssues': issueNamesSet,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ Processed Image metadata saved to Firestore with ID: $imageId");

      _showOverlayMessage("Image Processed Succesfully");
    } catch (e) {
      throw Exception("❌ Failed to save processed image metadata to Firestore: $e");
    }
  }


  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                  onPressed: _isUploading ? null : () => _uploadImage(context),
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
