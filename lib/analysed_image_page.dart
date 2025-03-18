import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalysedPage extends StatefulWidget {
  const AnalysedPage({super.key});

  @override
  State<AnalysedPage> createState() => _AnalysedPageState();
}

class _AnalysedPageState extends State<AnalysedPage> {

  late String processedImageUrl;
  String userName = ''; // Default user name
  // final FirebaseAuth _auth = FirebaseAuth.instance;
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
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      setState(() {
        userData = userDoc.data() as Map<String, dynamic>?;
        profileImageUrl = (userData?['profile_image'] != null && userData?['profile_image'].isNotEmpty)
            ? userData!['profile_image']
            : "assets/default_avatar.webp";
      });
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
          actions:[
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
        child: processedImageUrl.isNotEmpty
            ? Image.network(processedImageUrl)
            : const Text("No analyzed image available"),
      ),
    );
  }
}
