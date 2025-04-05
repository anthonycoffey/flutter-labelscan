import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// import 'main_screen.dart'; // Import MainScreen for navigation

// Enum for menu actions
enum MyAccountMenuAction { scanLabel } // Removed inviteFriend

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  User? _user;
  String? _avatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _avatarUrl = _user?.photoURL;
    // Listen for auth changes (e.g., profile updates)
    _auth.userChanges().listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          _avatarUrl = user?.photoURL;
        });
      }
    });
  }

  // Method to handle menu item selection
  // unused for now, but kept for future use
  // TODO: REMOVE OR REIMPLEMENT LATER
  // void _handleMenuSelection(MyAccountMenuAction action) {
  //   switch (action) {
  //     case MyAccountMenuAction.scanLabel:
  //       // Navigate to MainScreen, which defaults to the HomeScreen (index 0)
  //       Navigator.pushAndRemoveUntil(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => const MainScreen(),
  //         ), // Navigate to MainScreen
  //         (Route<dynamic> route) => false, // Remove all previous routes
  //       );
  //       break;
  //     // Removed inviteFriend case
  //   }
  // }

  Future<void> _pickAndUploadAvatar() async {
    if (_user == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, // Or ImageSource.camera
        imageQuality: 50, // Reduce quality to save storage/bandwidth
        maxWidth: 500, // Resize image
      );

      if (image == null) return; // User cancelled picker

      setState(() {
        _isUploading = true;
      });

      File imageFile = File(image.path);
      String userId = _user!.uid;
      String filePath = 'users/$userId/avatar.jpg'; // Define storage path

      // Upload to Firebase Storage
      UploadTask uploadTask = _storage.ref(filePath).putFile(imageFile);

      // Wait for upload completion
      TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile
      await _user!.updatePhotoURL(downloadUrl);

      // Update local state (though userChanges listener might also catch this)
      setState(() {
        _avatarUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading avatar: ${e.toString()}')),
      );
      debugPrint('Error uploading avatar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      // AuthWrapper handles navigation
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Use logo image instead of text title
        title: Image.asset(
          'lib/assets/logo-text@4x.png',
          height: 35, // Match height used in other screens
          semanticLabel: 'LabelScan Logo',
        ),
        // Keep AppBar background white (from theme), remove elevation if needed explicitly
        elevation: 0,
        centerTitle: false, // Ensure left alignment
        actions: [], // Removed PopupMenuButton
      ),
      body: SingleChildScrollView(
        // Allow scrolling if content overflows
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Avatar Section
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor:
                        Colors.grey.shade300, // Placeholder background
                    backgroundImage:
                        _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child:
                        _avatarUrl == null
                            ? Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey.shade600,
                            )
                            : null, // Show icon only if no image
                  ),
                  // Upload Button Overlay
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      // Wrap IconButton for InkWell effect
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isUploading ? null : _pickAndUploadAvatar,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child:
                              _isUploading
                                  ? const SizedBox(
                                    // Show spinner when uploading
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // User Info Section
              if (_user != null) ...[
                Text(
                  _user!.displayName ?? 'No display name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  _user!.email ?? 'No email address',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ] else ...[
                const Text(
                  'Not logged in',
                ), // Should not happen if AuthWrapper works
              ],
              const SizedBox(height: 30), // Adjusted Spacer

              // Invite Friend Section
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Invite a Friend'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Placeholder action - show a SnackBar for now
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Invite a friend feature coming soon!')),
                  );
                },
              ),
              const SizedBox(height: 20), // Spacer before sign out

              // Future Settings Section Placeholder
              // Divider(),
              // Text('Settings', style: Theme.of(context).textTheme.titleLarge),
              // Add settings widgets here later...
              // SizedBox(height: 20),

              // Sign Out Button (moved to bottom)
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, // Make it stand out
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
