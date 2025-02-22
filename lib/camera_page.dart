import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  int _cameraIndex = 0;
  List<CameraDescription> _cameras = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isCameraPermissionGranted = true);
      await _initializeCamera();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    } else {
      setState(() {
        _errorMessage = 'Camera permission was denied';
        _isCameraPermissionGranted = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on device';
        });
        return;
      }

      // Dispose previous controller before reinitializing
      if (_controller != null) {
        await _controller!.dispose();
      }

      _controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera initialization error: $e';
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _switchCamera() async {
    if (_cameras.length > 1) {
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;

      // Dispose of the old camera before switching
      await _controller?.dispose();
      _controller = null;

      setState(() {
        _isCameraInitialized = false;
      });

      await _initializeCamera();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No other camera found")),
      );
    }
  }


  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      _navigateToPreview(pickedFile.path);
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      if (!mounted) return;
      _navigateToPreview(image.path);
    } catch (e) {
      _showSnackBar('Error taking picture: $e');
    }
  }

  void _navigateToPreview(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagePreviewPage(imagePath: imagePath),
      ),
    );
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraPermissionGranted) {
      return _buildPermissionScreen();
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: _isCameraInitialized
          ? Stack(
        children: [
          CameraPreview(_controller!),
          _buildCameraControls(),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildPermissionScreen() {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Camera permission is required', style: TextStyle(fontSize: 18, color: Colors.grey)),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            ElevatedButton(
              onPressed: _requestCameraPermission,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              child: const Text('Request Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraControls() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            onPressed: _switchCamera,
            backgroundColor: Colors.white,
            heroTag: 'switchCameraButton',
            child: const Icon(Icons.switch_camera, color: Colors.pinkAccent),
          ),
          FloatingActionButton(
            onPressed: _captureImage,
            backgroundColor: Colors.pinkAccent,
            heroTag: 'captureButton',
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
          FloatingActionButton(
            onPressed: _pickImage,
            backgroundColor: Colors.white,
            heroTag: 'imagePickerButton',
            child: const Icon(Icons.image, color: Colors.pinkAccent),
          ),
        ],
      ),
    );
  }
}

// ---------------------- Image Preview Page ----------------------

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

    final resizedImage = img.copyResize(rawImage, width: 800); // Resize to 800px width
    final compressedImage = img.encodeJpg(resizedImage, quality: 50); // Reduce quality to 50%

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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text("Retake"),
                ),
                ElevatedButton(
                  onPressed: () => _uploadImage(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                  child: _isUploading ? CircularProgressIndicator() : const Text("Submit"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
