import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SkinquizPage extends StatefulWidget {
  const SkinquizPage({super.key});

  @override
  _SkinquizPageState createState() => _SkinquizPageState();
}

class _SkinquizPageState extends State<SkinquizPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLastPage = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String userName = ''; // Default user name
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  String profileImageUrl = "assets/default_avatar.webp";

  final List<Question> questions = [
    Question(questionText: "What is your skin type?", options: ["Oily", "Dry", "Normal", "Combination"]),
    Question(questionText: "How often do you use sunscreen?", options: ["Every day", "Sometimes", "Rarely", "Never"]),
    Question(questionText: "Do you have any skin allergies?", options: ["Yes", "No", "Not sure"]),
    Question(questionText: "How often do you exfoliate your skin?", options: ["Daily", "Weekly", "Monthly", "Never"]),
    Question(questionText: "What is your age range?", options: ["Under 18", "18-30", "31-50", "50 above"]),
    Question(questionText: "What is your gender?", options: ["Male", "Female"]),
  ];

  List<String?> selectedOptions = [];

  @override
  void initState() {
    super.initState();
    selectedOptions = List<String?>.filled(questions.length, null);
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

  void _nextPage() {
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 600,
        left: MediaQuery.of(context).size.width * 0.06,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Please select an option before proceeding",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );


    if (_currentPage < questions.length - 1 && selectedOptions[_currentPage] != null) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() {
        _currentPage += 1;
        _isLastPage = _currentPage == questions.length - 1;
      });
    } else {
      Overlay.of(context).insert(overlayEntry);
      Future.delayed(const Duration(seconds: 2), () {
        overlayEntry?.remove();
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() {
        _currentPage -= 1;
        _isLastPage = false;
      });
    }
  }


  void _submitQuiz() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    if (selectedOptions.contains(null)) {
      _showOverlayMessage("Please select an option before submitting");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('quiz_responses').doc(user.uid).set({
        'responses': selectedOptions,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showOverlayMessage("Quiz Submitted Successfully!", success: true);
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacementNamed(context, '/homepage');
      });

    } catch (e) {
      _showOverlayMessage("Submission Failed. Try again!");
    }
  }

  void _showOverlayMessage(String message, {bool success = false}) {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 600,
        left: success ? MediaQuery.of(context).size.width * 0.2 : MediaQuery.of(context).size.width * 0.05,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: success ? Colors.green : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: TextStyle(color: success ? Colors.white : Colors.red),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry?.remove();
    });
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
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                return QuizQuestionWidget(
                  question: questions[index],
                  selectedOption: selectedOptions[index],
                  onOptionSelected: (selectedOption) {
                    setState(() {
                      selectedOptions[index] = selectedOption;
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousPage,
                  icon: const Icon(Icons.arrow_back, color: Colors.pinkAccent, size: 32),
                ),
                _isLastPage
                    ? ElevatedButton(
                      onPressed: _submitQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        shadowColor: Colors.pink.shade200,
                        elevation: 2,
                      ),
                      child: const Text(
                        "Submit",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                    : IconButton(
                      onPressed: _nextPage,
                      icon: const Icon(Icons.arrow_forward, color: Colors.pinkAccent, size: 32),
                    ),
              ],
            ),
          ),

        ],
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
              _buildNavItem(Icons.analytics_rounded, "For You", Colors.grey, () {
                Navigator.pushReplacementNamed(context, '/foryou');
              }),
              const SizedBox(width: 50), // Spacer for FAB
              _buildNavItem(Icons.chat, "SkinQuiz", Colors.pinkAccent, () {

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


class QuizQuestionWidget extends StatelessWidget {
  final Question question;
  final String? selectedOption;
  final ValueChanged<String> onOptionSelected;

  const QuizQuestionWidget({
    super.key,
    required this.question,
    required this.selectedOption,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question.questionText,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          for (String option in question.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton(
                onPressed: () => onOptionSelected(option),
                style: ElevatedButton.styleFrom(
                  backgroundColor: option == selectedOption ? Colors.pink[300] : Colors.white,
                  side: const BorderSide(color: Colors.pinkAccent, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: option == selectedOption ? Colors.white : Colors.pinkAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

  }
}

class Question {
  final String questionText;
  final List<String> options;

  Question({required this.questionText, required this.options});
}
