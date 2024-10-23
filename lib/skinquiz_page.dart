import 'package:flutter/material.dart';


class SkinquizPage extends StatefulWidget {
  const SkinquizPage({Key? key}) : super(key: key);

  @override
  _SkinquizPageState createState() => _SkinquizPageState();
}


class _SkinquizPageState extends State<SkinquizPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // List of questions and their options
  final List<Question> questions = [
    Question(
      questionText: "What is your skin type?",
      options: ["Oily", "Dry", "Normal", "Combination"],
    ),
    Question(
      questionText: "How often do you use sunscreen?",
      options: ["Every day", "Sometimes", "Rarely", "Never"],
    ),
    Question(
      questionText: "Do you have any skin allergies?",
      options: ["Yes", "No", "Not sure"],
    ),
  ];

  void _nextPage() {
    if (_currentPage < questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
                });
              },
              itemCount: questions.length,
              itemBuilder: (context, index) {
                return QuizQuestionWidget(
                  question: questions[index],
                  onOptionSelected: (selectedOption) {
                    // Handle the option selected
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('You selected: $selectedOption')),
                    );
                  },
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _previousPage,
                child: const Text("Previous"),
              ),
              ElevatedButton(
                onPressed: _nextPage,
                child: const Text("Next"),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
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
              Navigator.pushNamed(context, '/homepage');
              break;
            case 1:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('history Clicked')),
              );

              break;
            case 2:
// Handle Notifications tap
              Navigator.pushNamed(context, '/skinquiz');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
            case 4:
            // Navigate to Settings
              break;

          }
        },
      ),
    );
  }
}

class QuizQuestionWidget extends StatelessWidget {
  final Question question;
  final ValueChanged<String> onOptionSelected;

  const QuizQuestionWidget({
    Key? key,
    required this.question,
    required this.onOptionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question.questionText,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          for (String option in question.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton(
                onPressed: () {
                  onOptionSelected(option); // Call the callback on option selection
                },
                child: Text(option),
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

