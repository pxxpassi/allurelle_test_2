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
  List<Map<String, dynamic>> recommendedProducts =[];
  String? skinType;
  String? product;

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

    // Fetch latest skin quiz responses
    QuerySnapshot<Map<String, dynamic>> quizSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('skinquiz_responses')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    QuerySnapshot<Map<String, dynamic>> detectedIssuesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('image_responses')
        .orderBy('createdAt', descending: true)
        .get();

    print("fetched");

    if (quizSnapshot.docs.isNotEmpty) {
        var latestQuizDoc = quizSnapshot.docs.first;
        var quizData = latestQuizDoc.data();


        skinType = quizData['responses']?[0] ?? 'N/A';
        skinQuizResponses = {
          'createdAt': quizData['createdAt'].toDate().toString(),  // Convert Firestore Timestamp
          'skinType': quizData['responses']?[0] ?? 'N/A',
          'sunscreenUsage': quizData['responses']?[1] ?? 'N/A',
          'skinAllergies': quizData['responses']?[2] ?? 'N/A',
          'exfoliationFrequency': quizData['responses']?[3] ?? 'N/A',
        };

        Map<String, Map<String, dynamic>> latestImagesBySkinType = {}; // To store latest entry per skinType
        Set<String> detectedIssuesSet = {}; // To store unique detected issues

        for (var doc in detectedIssuesSnapshot.docs) {
          Map<String, dynamic> data = doc.data();
          String skinType = (data["skinType"] ?? "Unknown").toString();

          // Store the first occurrence of each skinType
          if (!latestImagesBySkinType.containsKey(skinType)) {
            latestImagesBySkinType[skinType] = data;

            // Extract detected issues from this entry
            if (data.containsKey("detected_issues")) {
              List<dynamic> issues = data["detected_issues"];

              for (var issue in issues) {
                if (issue is Map<String, dynamic> && issue.containsKey("label")) {
                  String issueName = issue["label"].split(" (")[0]; // Extract issue name
                  detectedIssuesSet.add(issueName); // Add to set (ensures uniqueness)
                }
              }
            }
          }
        }

        print("Unique detected issues: $detectedIssuesSet");

    }
    else {
      print("no record found");}


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
    const String serverUrl = "http://192.168.202.137:5000/recommend";

    if (skinQuizResponses == null) {
      print("❌ No skin quiz responses found.");
      return;
    }

    try {
      final client = http.Client(); // Create an HTTP client
      final request = http.Request("POST", Uri.parse(serverUrl));

      // Add headers
      request.headers["Content-Type"] = "application/json";

      // Attach body
      request.body = jsonEncode({
        "detectedIssues": detectedIssues,
        "skinType": skinType,
        "skinQuizResponses": skinQuizResponses,
      });

      // Send request and await response
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print("✅ Raw Recommendation Response: ${response.body}");

        final Map<String, dynamic> decodedResponse = jsonDecode(response.body);

        // Validate response structure
        if (decodedResponse.containsKey("recommendedProducts") &&
            decodedResponse["recommendedProducts"] != null) {
          final rawProducts = decodedResponse["recommendedProducts"];

          if (rawProducts is Map<String, dynamic>) {
            setState(() {
              recommendedProducts = rawProducts.entries
                  .map((entry) {
                // Convert category key-value pairs into a standard format
                Map<String, dynamic> product = entry.value;
                product["Category"] = entry.key; // Add category name to product data
                return product;
              })
                  .toList();
            });
          }
          print("✅ Processed Recommended Products: $recommendedProducts");}

    else {
          print("❌ Unexpected response structure: ${decodedResponse}");
        }
      } else {
        print("❌ Failed to get recommendations: ${response.statusCode} - ${response.body}");
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

            // ✅ Null check added to prevent crash
            recommendedProducts.isEmpty
                ? Text("No recommendations yet.")
                : Expanded(
                  child: recommendedProducts.isEmpty
                      ? Center(child: Text("No recommendations yet."))
                      : ListView.builder(
                          itemCount: recommendedProducts.length,
                          itemBuilder: (context, index) {
                            final product = recommendedProducts[index];
                            return ListTile(
                              title: Text(product['Name'] ?? 'Unknown Product'),
                              subtitle: Text("${product['Brand'] ?? 'Unknown Brand'} - ${product['Category'] ?? 'N/A'} - \$${product['Price'] ?? 'N/A'}"),
                            );
                },
              ),
            ),
          ],
        ),
      ),

    );
  }
}
