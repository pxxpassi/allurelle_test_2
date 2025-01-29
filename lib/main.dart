import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'camera_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'skinquiz_page.dart';
import 'landing_page.dart';
import 'user_auth/login_page.dart';
import 'user_auth/signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

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
        // Add more routes as needed
      },
    );
  }
}

// Widget that checks if the user is logged in or not
class AuthCheck extends StatelessWidget {
  const AuthCheck({Key? key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const LoginPage(); // If user is not logged in, show login page
          } else {
            // Initialize Firebase Messaging
            _initializeFirebaseMessaging(user.uid);
            return const HomePage(); // If logged in, show home page
          }
        }
        // Show loading screen while checking auth status
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  void _initializeFirebaseMessaging(String userId) {
    FirebaseMessaging.instance.getToken().then((token) {
      print("Firebase Messaging Token: $token");

      // Store the token in Firestore or your database
      // Example: Firestore.instance.collection('users').doc(userId).set({'fcmToken': token});
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Received notification: ${message.notification?.title}");
      // Handle foreground notification messages
      _showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("App opened from notification: ${message.notification?.title}");
      // Handle notification messages when the app is in the background or terminated state
      _handleNotificationClick(message);
    });

    // Request permission for iOS only
    FirebaseMessaging.instance
        .requestPermission(sound: true, badge: true, alert: true);
  }

  void _showNotification(RemoteMessage message) {
    // Implement your notification UI here
    // Example: showDialog(context: context, builder: (context) => AlertDialog(...));
  }

  void _handleNotificationClick(RemoteMessage message) {
    // Implement navigation or data handling when notification is clicked
    // Example: Navigator.pushNamed(context, '/details', arguments: message.data['postId']);
  }
}
