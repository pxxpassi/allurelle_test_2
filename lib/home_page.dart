import 'package:flutter/material.dart';
import 'dart:io'; // To use exit()

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Navigate to the Settings page
  void _settings(BuildContext context) {
    Navigator.pushNamed(context, '/settings');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Exit the app if the back button is pressed on the home page
        exit(0);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          elevation: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: Image.asset(
              'assets/allurelle_logo.png', // Same logo from login page
              height: 50,
              width: 50,
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              color: Colors.pink, // Icon color for notifications
              onPressed: () {
                // Handle notifications icon click
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications Clicked')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              color: Colors.pink, // Icon color for settings
              onPressed: () => _settings(context), // Pass context to _settings
            ),
          ],
        ),
        body: const Center(
          child: Text(
            'Welcome to the Home Page!',
            style: TextStyle(
              color: Color(0xFF363636),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
          ],
          currentIndex: 0, // Set the initial selected index
          selectedItemColor: Colors.pink,
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            // Handle tap events based on the selected index
            switch (index) {
              case 0:
              // Home tapped, do nothing since we're already on the HomePage
                break;
              case 1:
                _settings(context); // Navigate to Settings
                break;
              case 2:
              // Handle Notifications tap
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications Clicked')),
                );
                break;
            }
          },
        ),
      ),
    );
  }
}
