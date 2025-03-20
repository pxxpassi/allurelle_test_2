import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  String profileImageUrl = "assets/default_avatar.webp";

  List<Map<String, dynamic>> latestImages = [];
  List<String> detectedIssues = [];
  Map<String, dynamic>? skinQuizResponses;
  List<dynamic> recommendedProducts = [];

  @override
  void initState() {
    super.initState();
    _getUserData();
    _fetchLatestImagesAndQuiz();
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

  Future<void> _fetchLatestImagesAndQuiz() async {
    if (user == null) return;

    // Fetch latest images
    QuerySnapshot imageDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('images')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .get();

    if (imageDocs.docs.isNotEmpty) {
      List<Map<String, dynamic>> images = imageDocs.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();

      setState(() {
        latestImages = images;
        detectedIssues = _extractDetectedIssues(images);
      });
    }

    // Fetch latest skin quiz responses
    QuerySnapshot<Map<String, dynamic>> quizSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('skinquiz_responses')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (quizSnapshot.docs.isNotEmpty) {
      setState(() {
        skinQuizResponses = quizSnapshot.docs.first.data();
      });
    }

    // Send request for recommendations
    _sendRecommendationRequest();
  }

  List<String> _extractDetectedIssues(List<Map<String, dynamic>> images) {
    List<String> issues = [];
    for (var image in images) {
      if (image.containsKey('detectedIssues') && image['detectedIssues'] is List) {
        issues.addAll(List<String>.from(image['detectedIssues']));
      }
    }
    return issues.toSet().toList(); // Removing duplicates
  }

  Future<void> _sendRecommendationRequest() async {
    const String serverUrl = "http://192.168.250.251:5000/recommend";

    if (skinQuizResponses == null) {
      print("❌ No skin quiz responses found.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "detectedIssues": detectedIssues,
          "skinQuizResponses": skinQuizResponses,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          recommendedProducts = jsonDecode(response.body)['recommendedProducts'];
        });
      } else {
        print("❌ Failed to get recommendations: ${response.body}");
      }
    } catch (e) {
      print("❌ Error sending request: $e");
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Detected Issues:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Wrap(
              children: detectedIssues.map((issue) => Chip(label: Text(issue))).toList(),
            ),
            SizedBox(height: 20),
            Text("Recommended Products:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            recommendedProducts.isNotEmpty
                ? Expanded(
              child: ListView.builder(
                itemCount: recommendedProducts.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(recommendedProducts[index]['name']),
                    subtitle: Text(recommendedProducts[index]['description']),
                  );
                },
              ),
            )
                : Text("No recommendations yet."),
          ],
        ),
      ),
    );
  }
}
