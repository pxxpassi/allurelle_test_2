import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FaceSelectionPage extends StatefulWidget {
  const FaceSelectionPage({super.key});

  @override
  State<FaceSelectionPage> createState() => _FaceSelectionPage();
}

class _FaceSelectionPage extends State<FaceSelectionPage> {
  String userName = ''; // Default user name
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  String profileImageUrl = "assets/default_avatar.webp";

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection(
          'users').doc(user!.uid).get();
      setState(() {
        userData = userDoc.data() as Map<String, dynamic>?;
        profileImageUrl = (userData?['profile_image'] != null &&
            userData?['profile_image'].isNotEmpty)
            ? userData!['profile_image']
            : "assets/default_avatar.webp";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFaceOption(
                context, "Capture Front Face", "assets/face_front.png",
                "front"),
            const SizedBox(height: 15),
            _buildFaceOption(
                context, "Capture Left Side", "assets/face_left.png", "left"),
            const SizedBox(height: 15),
            _buildFaceOption(
                context, "Capture Right Side", "assets/face_right.png",
                "right"),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceOption(BuildContext context, String label, String imagePath,
      String faceSide) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/camera', arguments: faceSide);
      },
      child: Center( // Ensures each button is centered
        child: Container(
          height: 200,
          // Fixed height for better alignment
          width: MediaQuery
              .of(context)
              .size
              .width * 0.8,
          // 80% of screen width
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.pink[50],
            borderRadius: BorderRadius.circular(12), // Smaller border radius
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(imagePath, height: 90), // Adjusted size
              const SizedBox(height: 15),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.pinkAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
