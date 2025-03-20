import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:firebase_storage/firebase_storage.dart';

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


  @override
  void initState() {
    super.initState();
    _getUserData().then((_) {
      _fetchLatestImageResponse(user!.uid);
      fetchLatestQuizResponse(user!.uid);
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (latestQuizResponse != null) ...[
          Text("Latest Skin Quiz Response",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
          const SizedBox(height: 5),
          Text("Skin Type: ${latestQuizResponse!['skinType']}", style: TextStyle(fontSize: 16, color: Colors.black87)),
          Text("Sunscreen Usage: ${latestQuizResponse!['sunscreenUsage']}", style: TextStyle(fontSize: 16, color: Colors.black87)),
          Text("Skin Allergies: ${latestQuizResponse!['skinAllergies']}", style: TextStyle(fontSize: 16, color: Colors.black87)),
          Text("Exfoliation Frequency: ${latestQuizResponse!['exfoliationFrequency']}", style: TextStyle(fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 20),
        ],

        Text("Latest Analyzed Images",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
        const SizedBox(height: 5),

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
                    /*const SizedBox(height: 10),

                    Text("Original $faceType Face",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),

                    // Original Image or Warning Box
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: hasOriginalImage
                          ? Image.network(
                        image['uploadedImageUrl']!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.warning, size: 50, color: Colors.red),
                      )
                          : Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning, size: 50, color: Colors.red),
                              SizedBox(height: 10),
                              Text("No Original Image Available",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),*/
                  ],
                ),
              ),
            );
          },
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
              ElevatedButton(
                onPressed: () {
                  // Call API to generate recommendations OR navigate to recommendation page
                  Navigator.pushNamed(context, '/recommendations');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                  padding: EdgeInsets.symmetric(vertical: 14.6, horizontal: 20),
                ),
                child: Text("Recommend Me", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              const Text("Recommended Products",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    productCard("Hydrating Serum", "assets/1.png"),
                    productCard("Vitamin C Cream", "assets/2.png"),
                    productCard("Sunscreen SPF 50", "assets/3.png"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("Skincare Routine",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
              const SizedBox(height: 10),
              routineStep("1. Cleanse your face with a gentle cleanser."),
              routineStep("2. Apply a hydrating toner to prep your skin."),
              routineStep("3. Use a serum (Vitamin C in the morning, Retinol at night)."),
              routineStep("4. Moisturize your skin to keep it hydrated."),
              routineStep("5. Apply sunscreen (SPF 30+ during the day)."),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
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
            Navigator.pushNamed(context, '/faceselection');
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.camera_alt,
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
