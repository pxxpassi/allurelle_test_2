import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? userData;
  String profileImageUrl = "assets/default_avatar.webp";

  Future<void> _getUserData() async {
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      setState(() {
        userData = userDoc.data() as Map<String, dynamic>? ?? {};
        profileImageUrl = (userData?['profile_image']?.isNotEmpty ?? false)
            ? userData!['profile_image']
            : "assets/default_avatar.webp";
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      bool? confirm = await _showConfirmationDialog(imageFile);
      if (confirm == true) {
        await _uploadImage(imageFile);
      }
    }
  }

  Future<void> _uploadImage(File image) async {
    if (user == null) return;
    Reference storageRef = FirebaseStorage.instance.ref().child('profile_images/${user!.uid}');

    try {
      if (profileImageUrl.startsWith("http")) {
        await FirebaseStorage.instance.refFromURL(profileImageUrl).delete();
      }
    } catch (e) {
      debugPrint("Error deleting old image: $e");
    }

    UploadTask uploadTask = storageRef.putFile(image);
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'profile_image': downloadUrl,
    });

    setState(() {
      profileImageUrl = downloadUrl;
    });
  }

  Future<bool?> _showConfirmationDialog(File imageFile) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Profile Picture", style: TextStyle(color: Colors.pinkAccent),),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(imageFile, height: 100, width: 100, fit: BoxFit.cover),
              const SizedBox(height: 10),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.red),),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Confirm", style: TextStyle(color: Colors.green),),
            ),
          ],
        );
      },
    );
  }


  @override
  void initState() {
    super.initState();
    _getUserData();
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
          child: Image.asset('assets/allurelle_logo.png', height: 50, width: 50),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notification_add_rounded, color: Colors.pinkAccent, size: 30),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.login_outlined, color: Colors.pinkAccent, size: 30),
            padding: const EdgeInsets.only(right: 35.0, left: 15),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: _image != null
                        ? FileImage(_image!)
                        : (profileImageUrl.startsWith('http')
                        ? NetworkImage(profileImageUrl) as ImageProvider
                        : AssetImage(profileImageUrl)),
                    child: const Icon(Icons.camera_alt, size: 30, color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildEditableField("Name", "name", Icons.person),
              _buildEditableField("Username", "username", Icons.alternate_email),
              ListTile(
                title: const Text("Email"),
                subtitle: Text(user?.email ?? 'No email found'),
                leading: const Icon(Icons.email),
              ),
              _buildEditableField("Gender", "gender", Icons.wc),
              _buildEditableField("Age", "age", Icons.cake),
              const SizedBox(height: 100),
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
              _buildNavItem(Icons.analytics_rounded, "For You", Colors.grey, () {
                Navigator.pushReplacementNamed(context, '/foryou');
              }),
              const SizedBox(width: 50), // Spacer for FAB
              _buildNavItem(Icons.chat, "SkinQuiz", Colors.grey, () {
                Navigator.pushReplacementNamed(context, '/skinquiz');
              }),
              _buildNavItem(Icons.person, "Profile", Colors.pinkAccent, () {

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

  Widget _buildEditableField(String label, String field, IconData icon) {
    return ListTile(
      title: Text(label),
      subtitle: Text(userData?[field] ?? 'Not set'),
      leading: Icon(icon),
      trailing: const Icon(Icons.edit),
      onTap: () async {
        if (field == "gender") {
          String? newValue = await _showGenderEditDialog(userData?[field] ?? '');
          if (newValue != null && newValue.isNotEmpty) {
            _updateUserData(field, newValue);
          }
        } else {
          String? newValue = await _showEditDialog(label, userData?[field] ?? '');
          if (newValue != null && newValue.isNotEmpty) {
            _updateUserData(field, newValue);
          }
        }
      },
    );
  }

  Future<void> _updateUserData(String field, String value) async {
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        field: value,
      });
      _getUserData();
    }
  }

  Future<String?> _showGenderEditDialog(String currentGender) async {
    String? selectedGender = currentGender.isNotEmpty ? currentGender : "Female";

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Gender", style: TextStyle(color: Colors.pinkAccent)),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: const InputDecoration(labelText: "Select Gender"),
                items: ["Male", "Female"].map((String gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedGender = newValue;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(context, selectedGender), child: const Text("Save", style: TextStyle(color: Colors.green))),
          ],
        );
      },
    );
  }

  Future<String?> _showEditDialog(String field, String currentValue) async {
    TextEditingController controller = TextEditingController(text: currentValue);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit $field", style: const TextStyle(color: Colors.pinkAccent)),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Enter new value")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text("Save", style: TextStyle(color: Colors.green))),
          ],
        );
      },
    );
  }
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
