import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ForYouPage extends StatefulWidget {
  const ForYouPage({super.key});

  @override
  _ForYouPageState createState() => _ForYouPageState();
}

class _ForYouPageState extends State<ForYouPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  String profileImageUrl = "assets/default_avatar.webp";

  Map<String, dynamic>? latestImage;
  Map<String, dynamic>? latestQuizResponse;
  List<Map<String, dynamic>> latestImages = [];
  List<String> detectedIssues = [];
  Map<String, dynamic>? skinQuizResponses;
  List<Map<String, dynamic>> recommendedProducts =[];
  String? skinType;
  String? product;

  final imageAssets = [
    'assets/1.png',
    'assets/2.png',
    'assets/3.png',
    'assets/4.png',
    'assets/5.png',
    'assets/1.png',
  ];

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

  Future<void> _fetchLatestImageResponse(String userID) async {
    if (user == null) return;

    try {
      print("🔄 Fetching latest image responses...");

      QuerySnapshot imageSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('image_responses')
          .orderBy('createdAt', descending: true)
          .get();

      // Face types to track
      Map<String, Map<String, dynamic>?> latestImagesMap = {
        "front": null,
        "left": null,
        "right": null,
      };

      if (imageSnapshot.docs.isNotEmpty) {
        for (var doc in imageSnapshot.docs) {
          var imageData = doc.data() as Map<String, dynamic>;
          String faceType = imageData['faceType'] ?? "unknown";

          if (latestImagesMap.containsKey(faceType) && latestImagesMap[faceType] == null) {
            latestImagesMap[faceType] = {
              'faceType': faceType,
              'imageId': imageData['imageId'] ?? "",
              'uploadedImageUrl': imageData['uploadedImageUrl'] ?? "",
              'processedImageUrl': imageData['processedImageUrl'] ?? "",
              'createdAt': imageData['createdAt'] ?? "",
            };
          }

          if (!latestImagesMap.values.contains(null)) break;
        }
      }

      setState(() {
        latestImages = latestImagesMap.entries
            .where((entry) => entry.value != null)
            .map((entry) => entry.value!)
            .toList();
      });

      print("✅ Latest Images: $latestImages");
    } catch (e) {
      print("⚠️ Error fetching latest image responses: $e");
    }
  }




  Future<void> fetchLatestQuizResponse(String userID) async {
    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('skinquiz_responses')
          .orderBy('createdAt', descending: true) // Ensure `createdAt` exists
          .limit(1) // Fetch latest quiz
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var latestQuizDoc = querySnapshot.docs.first;
        var quizData = latestQuizDoc.data();

        // Debugging: Print the fetched data
        print("🔥 Fetched Quiz Data: $quizData");

        setState(() {
          latestQuizResponse = {
            'createdAt': quizData['createdAt'].toDate().toString(),  // Convert Firestore Timestamp
            'skinType': quizData['responses']?[0] ?? 'N/A',
            'sunscreenUsage': quizData['responses']?[1] ?? 'N/A',
            'skinAllergies': quizData['responses']?[2] ?? 'N/A',
            'exfoliationFrequency': quizData['responses']?[3] ?? 'N/A',
          };
        });
      } else {
        print("❌ No quiz responses found");
        setState(() {
          latestQuizResponse = null;
        });
      }
    } catch (e) {
      print("⚠️ Error fetching latest quiz response: $e");
      setState(() {
        latestQuizResponse = null;
      });
    }
  }

  static const String serverIp = "192.168.31.183"; // <-- easily changeable IP
  static const int serverPort = 5000;
  static const String serverPath = "/recommend";

  Future<void> _sendRecommendationRequest() async {
    final String serverUrl = "http://192.168.31.183:5000/recommend";

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
      final response = await http.Response.fromStream(streamedResponse).timeout(Duration(seconds: 30));;

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
  void initState() {
    super.initState();
    _getUserData().then((_) {
      _fetchLatestImageResponse(user!.uid);
      fetchLatestQuizResponse(user!.uid);
      _fetchLatestImagesAndQuiz();
    });
  }



  Widget latestDataCard() {
    if (latestQuizResponse == null && latestImages.isEmpty) {
      return const Center(
        child: Text(
          "No recent data available.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Define all possible face types to ensure each is displayed
    List<String> allFaceTypes = ["front","left","right"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (latestQuizResponse != null) ...[
          const Text(
            "Latest Skin Quiz Response",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.pink[40],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _quizDetailTile(Icons.face, "Skin Type", latestQuizResponse!['skinType']),
                  const Divider(),
                  _quizDetailTile(Icons.wb_sunny_rounded, "Sunscreen Usage", latestQuizResponse!['sunscreenUsage']),
                  const Divider(),
                  _quizDetailTile(Icons.healing, "Skin Allergies", latestQuizResponse!['skinAllergies']),
                  const Divider(),
                  _quizDetailTile(Icons.spa, "Exfoliation Frequency", latestQuizResponse!['exfoliationFrequency']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],


        Text("Latest Analyzed Images",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
        const SizedBox(height: 10),

        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: allFaceTypes.length,
          itemBuilder: (context, index) {
            String faceType = allFaceTypes[index].toUpperCase();

            // Find the image data for this face type, if it exists
            var image = latestImages.firstWhere(
                  (img) => img['faceType'].toString().toUpperCase() == faceType,
              orElse: () => <String, dynamic>{}, // ✅ Ensures the correct return type
            );

            bool hasProcessedImage = image['processedImageUrl']?.isNotEmpty ?? false;
            //bool hasOriginalImage = image?['uploadedImageUrl']?.isNotEmpty ?? false;


            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.pink[40],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$faceType Face",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),

                    // Processed Image or Warning Box
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: hasProcessedImage
                          ? Image.network(
                        image['processedImageUrl']!,
                        height: 400,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.warning, size: 80, color: Colors.orange),
                      )
                          : Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning, size: 80, color: Colors.red),
                              SizedBox(height: 10),
                              Text("No Processed Image Available",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );


          },
        ),
        const SizedBox(height: 20),

        const Text("Recommended Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
        // ✅ Null check added to prevent crash
        const SizedBox(height: 10),
        recommendedProducts.isEmpty
            ? Text("No recommendations yet.")
            : SizedBox(
          height: 990,
          child : ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: recommendedProducts.length,
            itemBuilder: (context, index) {
              final product = recommendedProducts[index];
              final imagePath = index < imageAssets.length
                  ? imageAssets[index]
                  : 'assets/product1.png'; // fallback if more than 6
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                elevation: 4,
                color: Colors.pink[40],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child :
                        Image.asset(
                          imagePath,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 16),
                      // Product Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['Name'] ?? 'Unknown Product',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              product['Brand'] ?? 'Unknown Brand',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              product['Category'] ?? 'N/A',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "\$${product['Price'] ?? 'N/A'}",
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              latestDataCard(),
              const SizedBox(height: 20),

              const Text("Skincare Routine",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
              const SizedBox(height: 10),
              routineStep("1. Cleanse your face with a gentle cleanser."),
              routineStep("2. Apply a hydrating toner to prep your skin."),
              routineStep("3. Use a serum (Vitamin C in the morning, Retinol at night)."),
              routineStep("4. Moisturize your skin to keep it hydrated."),
              routineStep("5. Apply sunscreen (SPF 30+ during the day)."),
          ]
          )
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 5.0,
        child: SizedBox(
          height: 50, // Increased height for better label spacing
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, "Home", Colors.grey, () {Navigator.pushReplacementNamed(context, '/homepage');}),
              _buildNavItem(Icons.analytics_rounded, "For You", Colors.pinkAccent, () {

              }),
              const SizedBox(width: 50), // Spacer for FAB
              _buildNavItem(Icons.chat, "SkinQuiz", Colors.grey, () {
                Navigator.pushReplacementNamed(context, '/skinquiz');
              }),
              _buildNavItem(Icons.person, "Profile", Colors.grey, () {
                Navigator.pushReplacementNamed(context, '/profile');
              }),
            ],
          ),
        ),
      ),

      floatingActionButton: SizedBox(
        height: 65, // Adjusts the FAB size
        width: 65,
        child: FloatingActionButton(
          backgroundColor: Colors.pinkAccent,
          onPressed: () {
            Navigator.pushNamed(context, '/recommendations');
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.water_drop,
            color: Colors.white,
            size: 34, // Enlarges the icon
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterDocked,
    );
  }


  Widget productCard(String title, String imagePath) {
    return Container(
      width: 120,
      height: 300,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              imagePath,
              height: 100,
              width: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget routineStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.pinkAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}


Widget _quizDetailTile(IconData icon, String title, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Colors.pinkAccent, size: 26),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          ],
        ),
      ),
    ],
  );
}
