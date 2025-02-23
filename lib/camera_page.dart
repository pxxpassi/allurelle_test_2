import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'image_preview_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


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

  String userName = ''; // Default user name
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  String profileImageUrl = "assets/default_avatar.webp";

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _getUserData();
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

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      _navigateToPreview(pickedFile.path);
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
          actions:[
            IconButton(
              icon: const Icon(Icons.notification_add_rounded, color: Colors.pinkAccent, size: 30),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/settings');
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 30.0, left: 10),
              child: CircleAvatar(
                backgroundImage: profileImageUrl.startsWith("http")
                    ? NetworkImage(profileImageUrl)
                    : AssetImage(profileImageUrl) as ImageProvider,
              ),
            ),]
      ),
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
          actions:[
            IconButton(
              icon: const Icon(Icons.notification_add_rounded, color: Colors.pinkAccent, size: 30),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/settings');
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 30.0, left: 10),
              child: CircleAvatar(
                backgroundImage: profileImageUrl.startsWith("http")
                    ? NetworkImage(profileImageUrl)
                    : AssetImage(profileImageUrl) as ImageProvider,
              ),
            ),]
      ),
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
