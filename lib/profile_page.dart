import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _imageFile; // Initialize as null (no need for late keyword)
  final ImagePicker _picker = ImagePicker();
  User? _user;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
    setState(() {
      _userData = docSnapshot.data() as Map<String, dynamic>;
    });
  }

  Future<void> _updateUserData(Map<String, dynamic> newData) async {
    if (_user != null) {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update(newData);
      setState(() {
        _userData.addAll(newData);
      });
    }
  }

  Future<void> _changeProfilePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      // Implement logic to upload the image to Firebase Storage or other backend
      // Update user's profile picture in Firestore or Storage
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.black45) ),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              child: const Text('Logout',style: TextStyle(color: Colors.pinkAccent)),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          ],
        );
      },
    );
  }


  void _editName() {
    String newName = _userData['name'] ?? ''; // Initialize with current user name
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Name', style: TextStyle(color: Colors.pinkAccent)),
          content: TextField(
            onChanged: (value) {
              newName = value;
            },
            decoration: const InputDecoration(hintText: 'Enter your name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.black45)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save', style: TextStyle(color: Colors.pinkAccent)),
              onPressed: () async {
                await _updateUserData({'name': newName.trim()});
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name updated')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _editUsername() {
    String newUsername = _userData['username'] ?? ''; // Initialize with current user username
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Username', style: TextStyle(color: Colors.pinkAccent)),
          content: TextField(
            onChanged: (value) {
              newUsername = value;
            },
            decoration: const InputDecoration(hintText: 'Enter new username'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.black45)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save', style: TextStyle(color: Colors.pinkAccent)),
              onPressed: () async {
                await _updateUserData({'username': newUsername.trim()});
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username updated')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _editAge() {
    String newAge = _userData['age'] ?? ''; // Initialize with current user age
    final _formKey = GlobalKey<FormState>(); // Add a GlobalKey for form validation

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: ThemeData(
            dialogBackgroundColor: Colors.white,
            primaryColor: Colors.pinkAccent,
          ),
          child: AlertDialog(
            title: const Text('Edit Age', style: TextStyle(color: Colors.pinkAccent)),
            content: Form(
              key: _formKey,
              child: TextFormField(
                keyboardType: TextInputType.number, // Allow only numeric keyboard
                onChanged: (value) {
                  newAge = value;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter age';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter valid age';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText: 'Enter age',
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: Colors.black45)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Save', style: TextStyle(color: Colors.pinkAccent)),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await _updateUserData({'age': newAge.trim()});
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Age updated')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }


  void _editGender() {
    String newGender = _userData['gender'] ?? ''; // Initialize with current user gender

    // Determine the initial selection based on current gender value
    int initialIndex = newGender.isEmpty
        ? -1
        : ['Male', 'Female', 'Prefer Not to Say'].indexOf(newGender);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: ThemeData(
            dialogBackgroundColor: Colors.white,
            primaryColor: Colors.pinkAccent,
          ),
          child: AlertDialog(
            title: const Text('Edit Gender', style: TextStyle(color: Colors.pinkAccent)),
            content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Gender:', style: TextStyle(color: Colors.pinkAccent)),
                    Column(
                      children: [
                        RadioListTile<int>(
                          title: const Text('Male', style: TextStyle(color: Colors.pinkAccent)),
                          value: 0,
                          groupValue: initialIndex,
                          onChanged: (int? value) {
                            setState(() {
                              initialIndex = value!;
                              newGender = 'Male';
                            });
                          },
                        ),
                        RadioListTile<int>(
                          title: const Text('Female', style: TextStyle(color: Colors.pinkAccent)),
                          value: 1,
                          groupValue: initialIndex,
                          onChanged: (int? value) {
                            setState(() {
                              initialIndex = value!;
                              newGender = 'Female';
                            });
                          },
                        ),
                        RadioListTile<int>(
                          title: const Text('Prefer Not to Say', style: TextStyle(color: Colors.pinkAccent)),
                          value: 2,
                          groupValue: initialIndex,
                          onChanged: (int? value) {
                            setState(() {
                              initialIndex = value!;
                              newGender = 'Prefer Not to Say';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: Colors.black45)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Save', style: TextStyle(color: Colors.pinkAccent)),
                onPressed: () async {
                  await _updateUserData({'gender': newGender});
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gender updated')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
        actions: [
          IconButton(
            icon: Icon(Icons.logout_sharp),
            onPressed: _logout,
          ),
          const SizedBox(width : 20),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Text(
              "User Profile",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.pinkAccent,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _changeProfilePicture,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFF8BBD0),
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : (_user?.photoURL != null
                      ? NetworkImage(_user!.photoURL!)
                      : null),
                  child: (_imageFile == null && _user?.photoURL == null)
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text("Username"),
              subtitle: Text(_userData['username'] ?? 'No username found'),
              leading: const Icon(Icons.verified_user),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editUsername,
              ),
            ),
            ListTile(
              title: const Text("Name"),
              subtitle: Text(_userData['name'] ?? 'No name found'),
              leading: const Icon(Icons.person),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editName,
              ),
            ),
            ListTile(
              title: const Text("Email"),
              subtitle: Text(_user?.email ?? 'No email found'),
              leading: const Icon(Icons.email),
            ),
            ListTile(
              title: const Text("Age"),
              subtitle: Text(_userData['age'] ?? 'No age found'),
              leading: const Icon(Icons.calendar_today),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editAge,
              ),
            ),
            ListTile(
              title: const Text("Gender"),
              subtitle: Text(_userData['gender'] ?? 'No gender found'),
              leading: const Icon(Icons.person_outline),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editGender,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
