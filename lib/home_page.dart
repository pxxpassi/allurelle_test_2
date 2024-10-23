import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = ''; // Default user name
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Fetch the user's name when the widget is initialized
  }

  Future<void> _fetchUserName() async {
    try {
      // Get the current user ID
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('Fetching data for user: ${currentUser.uid}');

        // Fetch the user document from Firestore using the user's ID
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        // Check if the document exists and has a 'name' field
        if (userDoc.exists) {
          print('Document exists');
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('name')) {
            setState(() {
              userName = data['name'] ?? 'User'; // Set the name from Firestore
            });
            print('User name: $userName');
          } else {
            print('Name field does not exist in document');
          }
        } else {
          print('Document does not exist');
        }
      } else {
        print('No current user found');
      }
    } catch (e) {
      print('Error fetching user data: $e');
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
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
                          text: userName, // Display the fetched user name here
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
              const SizedBox(height: 30),

              // Buttons for SkinQuiz and Capture Face
              // Buttons for SkinQuiz and Capture Face
              // Buttons for SkinQuiz and Capture Face
              Column(
                children: [
                  Container(
                    width: double.infinity, // Makes the button take full width
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/camera');
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text(
                        "Capture Face",
                        style: TextStyle(fontSize: 18), // Set the font size here
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[50],
                        foregroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14.6, horizontal: 20),
                        minimumSize: const Size(150, 50), // Adjust the size as needed
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity, // Makes the button take full width
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/skinquiz');
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text(
                        "Take SkinQuiz",
                        style: TextStyle(fontSize: 18), // Set the font size here
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[50],
                        foregroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14.6, horizontal: 20),
                        minimumSize: const Size(150, 50), // Adjust the size as needed
                      ),
                    ),
                  ),
                  // Space between buttons

                ],
              ),


              const SizedBox(height: 30),

              // Product Recommendations
              const Text(
                "Recommended for You",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    productCard("Product 1", "assets/1.png"),
                    productCard("Product 2", "assets/2.png"),
                    productCard("Product 3", "assets/3.png"),
                    productCard("Product 4", "assets/4.png"),
                    productCard("Product 5", "assets/5.png"),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Dermatologist Consult Banner
              Container(
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Get 10% off your first dermatologist consultation!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.pinkAccent,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: Colors.pinkAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),



      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'SkinQuiz',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          // Handle tap events based on the selected index
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/homepage');
              break;
            case 1:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History Clicked')),
              );
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/skinquiz');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }

  // Product Card Widget
  Widget productCard(String title, String imagePath) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(imagePath, height: 100, width: 120 , fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
