import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore

class SkinquizPage extends StatefulWidget {
  const SkinquizPage({Key? key}) : super(key: key);

  @override
  _SkinquizPageState createState() => _SkinquizPageState();
}

class _SkinquizPageState extends State<SkinquizPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLastPage = false;

  final List<Question> questions = [
    Question(
      questionText: "What is your skin type?",
      options: ["Oily", "Dry", "Normal", "Combination"],
    ),
    Question(
      questionText: "How often you use sunscreen?",
      options: ["Every day", "Sometimes", "Rarely", "Never"],
    ),
    Question(
      questionText: "Do you have any skin allergies?",
      options: ["Yes", "No", "Not sure"],
    ),
    Question(
      questionText: "How often do you exfoliate your skin?",
      options: ["Daily", "Weekly", "Monthly", "Never"],
    ),
    Question(
      questionText: "What is your age range?",
      options: ["Under 18", "18-24", "25-34", "35-44", "45 and above"],
    ),
    Question(
      questionText: "What is your gender?",
      options: ["Male", "Female", "Prefer not to say"],
    ),
  ];

  List<String?> selectedOptions = [];

  // Firebase references
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    selectedOptions = List<String?>.filled(questions.length, null);
  }

  void _nextPage() {
    if (_currentPage < questions.length) {
      if (_currentPage < questions.length - 1 && selectedOptions[_currentPage] != null) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentPage += 1;
          _isLastPage = _currentPage == questions.length;
        });
      } else if (_currentPage == questions.length - 1) {
        setState(() {
          _isLastPage = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an option to proceed.')),
        );
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage -= 1;
        _isLastPage = false;
      });
    }
  }
  void _submitQuiz() async {
    // Show confirmation dialog before submitting
    bool confirmSubmit = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Submission'),
          content: const Text('Are you sure you want to submit the quiz?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Return false on cancel
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.black45) ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Return true on submit
              },
              child: const Text('Submit', style: TextStyle(color: Colors.pinkAccent)),
            ),
          ],
        );
      },
    );

    // If user confirms submission, proceed with submitting quiz
    if (confirmSubmit == true) {
      try {
        // Get current user
        User? user = _auth.currentUser;
        if (user != null) {
          // Construct data to be stored in Firestore
          Map<String, dynamic> quizData = {
            'userId': user.uid, // User ID from Firebase Authentication
            'timestamp': DateTime.now(), // Timestamp of quiz submission
            'responses': selectedOptions, // Array of selected options
          };

          // Add quiz data to Firestore
          await _firestore.collection('skinquiz').add(quizData);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz submitted successfully!')),
          );

          Navigator.pushReplacementNamed(context, '/homepage');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated.')),
          );
        }
      } catch (e) {
        print('Error submitting quiz: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit quiz. Please try again later.')),
        );
      }
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
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                  _isLastPage = index == questions.length;
                });
              },
              itemCount: questions.length + 1,
              itemBuilder: (context, index) {
                if (index == questions.length) {
                  return SubmitQuizWidget(onSubmit: _submitQuiz);
                }
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
          if (!_isLastPage)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _previousPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFDBE7),
                      foregroundColor: Colors.pinkAccent,
                    ),
                    child: const Text("Back", style: TextStyle(fontSize: 18),),
                  ),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Next", style: TextStyle(fontSize: 18),),
                  ),
                ],
              ),
            ),
          if (_isLastPage)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ElevatedButton(
                  onPressed: _submitQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Submit", style: TextStyle(fontSize: 18),),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.camera_alt),
            label: 'Camera', // Added button for capturing face
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
              Navigator.pushReplacementNamed(context, '/camera');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/skinquiz');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }
}

class QuizQuestionWidget extends StatelessWidget {
  final Question question;
  final String? selectedOption;
  final ValueChanged<String> onOptionSelected;

  const QuizQuestionWidget({
    Key? key,
    required this.question,
    required this.selectedOption,
    required this.onOptionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question.questionText,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pinkAccent),),
          const SizedBox(height: 20),
          for (String option in question.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton(
                onPressed: () {
                  onOptionSelected(option);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: option == selectedOption ? Colors.pinkAccent : const Color(0xFFFFDBE7),
                  foregroundColor: option == selectedOption ? Colors.white : Colors.pinkAccent,
                ),
                child: Text(option),
              ),
            ),
        ],
      ),
    );
  }
}

class SubmitQuizWidget extends StatelessWidget {
  final VoidCallback onSubmit;

  const SubmitQuizWidget({Key? key, required this.onSubmit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Please review your answers and submit the quiz.',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _showConfirmationDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Submission'),
          content: const Text('Are you sure you want to submit the quiz?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSubmit(); // Call the onSubmit callback to submit the quiz
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}

class Question {
  final String questionText;
  final List<String> options;

  Question({required this.questionText, required this.options});
}
