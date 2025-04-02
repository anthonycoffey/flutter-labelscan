import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart'; // For BuildContext and SnackBar
import 'package:flutter_labelscan/screens/camera_screen.dart'; // Assuming CameraScreen is still used

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> captureImage(BuildContext context) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorSnackBar(context, 'No cameras found on this device.');
        return null;
      }

      // Show the camera screen and wait for a result (XFile object)
      // Note: This assumes CameraScreen is designed to return an XFile?
      // You might need to adjust CameraScreen or this logic depending on its implementation.
      final imageFile = await Navigator.push<XFile?>(
        context,
        MaterialPageRoute(builder: (context) => CameraScreen(cameras: cameras)),
      );

      return imageFile;
    } catch (e) {
      debugPrint("Error opening camera: $e");
      _showErrorSnackBar(context, 'Error accessing camera.');
      return null;
    }
  }

  Future<XFile?> pickImageFromGallery(BuildContext context) async {
    try {
      final XFile? imageFile = await _picker.pickImage(source: ImageSource.gallery);
      return imageFile;
    } catch (e) {
      debugPrint("Error picking image from gallery: $e");
      _showErrorSnackBar(context, 'Error accessing gallery.');
      return null;
      return null;
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    // Check if the context is still mounted before showing SnackBar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
} // Added missing closing brace for the class
