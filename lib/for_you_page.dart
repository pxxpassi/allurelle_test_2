import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> _fetchLatestData() async {
    if (user == null) return;

    try {
      // Ensure userData is fetched before querying
      if (userData == null) {
        await _getUserData();
      }

      // Fetch latest image based on user ID and createdAt timestamp
      QuerySnapshot imageSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('images')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (imageSnapshot.docs.isNotEmpty) {
        setState(() {
          latestImage = imageSnapshot.docs.first.data() as Map<String, dynamic>;
        });
        print("✅ Latest Image Data: $latestImage");
      } else {
        print("❌ No image found.");
      }

      // Fetch latest quiz response based on user ID and createdAt timestamp
      QuerySnapshot quizSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('skinquiz_responses')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (quizSnapshot.docs.isNotEmpty) {
        setState(() {
          latestQuizResponse = quizSnapshot.docs.first.data() as Map<String, dynamic>;
        });
        print("✅ Latest Quiz Data: $latestQuizResponse");
      } else {
        print("❌ No quiz response found.");
      }
    } catch (e) {
      print("⚠️ Error fetching latest data: $e");
    }
  }



  @override
  void initState() {
    super.initState();
    _getUserData().then((_) {
      _fetchLatestData();
    });
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
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/analytics');
                },
                icon: const Icon(Icons.bar_chart, size: 30),
                label: const Text("View Latest Analytics", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink[50],
                  foregroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14.6, horizontal: 20),
                ),
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
            Navigator.pushNamed(context, '/camera');
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

  Widget latestDataCard() {
    if (latestImage == null && latestQuizResponse == null) {
      return const Center(
        child: Text(
          "No recent data available.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (latestImage != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Latest Analysis Image",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      latestImage!['imageUrl'] ?? "",
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 80, color: Colors.red),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 15),
            if (latestQuizResponse != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Latest Skin Quiz Response",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                  const SizedBox(height: 5),
                  Text(
                    "Skin Type: ${latestQuizResponse!['skinType'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  Text(
                    "Concerns: ${latestQuizResponse!['concerns']?.join(", ") ?? 'N/A'}",
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
          ],
        ),
      ),
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
