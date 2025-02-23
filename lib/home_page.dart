import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = ''; // Default user name
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  String profileImageUrl = "assets/default_avatar.webp";

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Fetch the user's name when the widget is initialized
    _getUserData();
  }

  Future<void> _fetchUserName() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('name')) {
            setState(() {
              userName = data['name'] ?? 'User';
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
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

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      // Show a dialog prompting the user to enable location services
      _showLocationDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permission denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permission permanently denied. Enable it in settings.");
      return;
    }

    print("Location permission granted.");
  }

  /// Show a dialog asking users to enable location services
  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Enable Location Services", style: TextStyle(color: Colors.pinkAccent),),
          content: const Text("Please enable location services to find nearby dermatologists.", style: TextStyle(color: Colors.grey),),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openLocationSettings(); // Opens device settings
              },
              child: const Text("Open Settings", style: TextStyle(color: Colors.pinkAccent),),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openGoogleMaps() async {
    try {
      // Ensure location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _requestLocationPermission();
      }

      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied. Please enable them in settings.';
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // Open Google Maps
      Uri googleMapsUrl = Uri.parse(
          "https://www.google.com/maps/search/dermatologist/@${position.latitude},${position.longitude},14z"
      );

      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        throw 'Could not open Google Maps';
      }
    } catch (e) {
      print('Error opening Google Maps: $e');
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Welcome Message
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Welcome back, ",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: userName,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.pinkAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Text(
                "It's great to see you again!",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // Buttons for SkinQuiz and Capture Face
            Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/camera');
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 30),
                      label: const Text("Capture Face", style: TextStyle(fontSize: 18)),
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
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/skinquiz');
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 30,),
                      label: const Text("Take SkinQuiz", style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[50],
                        foregroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14.6, horizontal: 20),
                      ),
                    ),
                  ],
                ),
            ),

              const SizedBox(height: 10),

              // Product Recommendations
              const Text(
                "Recommended for You",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 160,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    productCard("Hydrating Moisturizer", "assets/1.png"),
                    productCard("Vitamin C Serum", "assets/2.png"),
                    productCard("Gycolic Acid Facewash", "assets/3.png"),
                    productCard("SPF 40 Sunscreen", "assets/4.png"),
                    productCard("Acne Patches", "assets/5.png"),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Dermatologist Consult Banner
              Container(
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          Text(
                              "Find the nearest Dermatologists Clinics!",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.pinkAccent,
                              ),
                            ),
                          Text("for your skin concerns.",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.pinkAccent,
                            ),
                          ),
                          ]
                      ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Colors.pinkAccent, size: 30,),
                      onPressed: _openGoogleMaps,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),


      // Bottom Navigation Bar with Floating Button
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        child: SizedBox(
          height: 50, // Increased height for better label spacing
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, "Home", Colors.pinkAccent, () {}),
              _buildNavItem(Icons.analytics_rounded, "For You", Colors.grey, () {
                Navigator.pushReplacementNamed(context, '/foryou');
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
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterDocked, // Moves FAB up slightly

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

  // Product Card Widget
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
            height: 100, // Ensure image doesn't overflow
            width: 120,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 5),
        Expanded( // Prevent overflow
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis, // Truncate text with "..."
            ),
          ),
        ),
      ],
    ),
  );
}



