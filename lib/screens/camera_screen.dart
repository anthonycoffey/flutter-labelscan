import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    // Use the first available camera (usually the back camera)
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high, // Adjust resolution as needed
    );

    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
     if (_isTakingPicture) return; // Prevent multiple taps

     setState(() { _isTakingPicture = true; });

     try {
        // Ensure controller is initialized
        await _initializeControllerFuture;

        // Attempt to take a picture and get the XFile
        final image = await _controller.takePicture();

         if (!mounted) return; // Check if widget is still mounted

         // If picture was taken, return the path to the previous screen
         Navigator.pop(context, image.path);

     } catch (e) {
        print("Error taking picture: $e");
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Error taking picture. Please try again.'))
             );
             setState(() { _isTakingPicture = false; });
         }
     }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Label')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return Stack(
               alignment: Alignment.bottomCenter,
               children: [
                  CameraPreview(_controller),
                  Padding(
                     padding: const EdgeInsets.all(20.0),
                     child: FloatingActionButton(
                        onPressed: _takePicture,
                        child: _isTakingPicture
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Icon(Icons.camera),
                     ),
                  ),
               ]
            );
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}