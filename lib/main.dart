import 'package:allurelle_test_2/camera_page.dart';
import 'package:allurelle_test_2/home_page.dart';
import 'package:allurelle_test_2/profile_page.dart';
import 'package:allurelle_test_2/settings_page.dart';
import 'package:allurelle_test_2/skinquiz_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'landing_page.dart';
import 'user_auth/login_page.dart';
import 'user_auth/signup_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: const AuthCheck(), // Start the app with the AuthCheck widget
      routes: {
        '/home': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/homepage': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
        '/profile': (context) => const ProfilePage(),
        '/camera': (context) => const CameraPage(),
        '/skinquiz': (context) => const SkinquizPage(),
    },
    );
  }
}

// This widget checks if the user is logged in or not
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the user is logged in, redirect to HomePage
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const LoginPage(); // If the user is not logged in, show login page
          } else {
            return const HomePage(); // If logged in, show home page
          }
        }
        // Show loading screen while checking the auth status
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}