import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'geofencecheckInPage.dart'; // ✅ Import the check-in page

// Config function to get backend URL
Future<String> getBackendUrl() async {
  return 'http://192.168.14.20:8000'; // Replace with your backend
}

// Upload selfie using multipart/form-data
Future<void> uploadSelfie(File selfieFile, String phoneNumber) async {
  final baseUrl = await getBackendUrl();
  final uri = Uri.parse('$baseUrl/upload_selfie_file');

  final request = http.MultipartRequest('POST', uri)
    ..fields['phone_number'] = phoneNumber
    ..files.add(await http.MultipartFile.fromPath('selfie', selfieFile.path));

  final response = await request.send();

  if (response.statusCode == 200) {
    print("Selfie uploaded successfully");
  } else {
    print("Failed to upload selfie with status ${response.statusCode}");
    throw Exception("Failed to upload selfie");
  }
}

class RegisterSelfiePage extends StatefulWidget {
  final String phoneNumber;

  const RegisterSelfiePage({super.key, required this.phoneNumber});

  @override
  State<RegisterSelfiePage> createState() => _RegisterSelfiePageState();
}

class _RegisterSelfiePageState extends State<RegisterSelfiePage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  File? _capturedImage;
  bool _isUploading = false;
  bool _cameraError = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }

      final frontCamera = _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      setState(() {
        _cameraError = true;
        _capturedImage = null;
      });
      debugPrint('Camera error: $e');
    }
  }

  Future<void> captureSelfie() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = join(directory.path, 'selfie.jpg');
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(await image.readAsBytes());

      setState(() => _capturedImage = imageFile);
    } catch (e) {
      debugPrint('Error capturing selfie: $e');
      setState(() => _capturedImage = null);
    }
  }

  Future<void> submitSelfie() async {
    if (_capturedImage == null) return;

    setState(() => _isUploading = true);

    try {
      await uploadSelfie(_capturedImage!, widget.phoneNumber);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selfie submitted successfully")),
      );

      setState(() => _capturedImage = null);

      // ✅ Navigate to GeofenceCheckinPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GeofenceCheckinPage(phoneNumber: widget.phoneNumber),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission failed: $e")),
        );
        setState(() => _capturedImage = null);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double previewSize = screenSize.shortestSide * 2 / 3;

    return Scaffold(
      appBar: AppBar(title: const Text("Register Selfie")),
      body: _cameraError
          ? const Center(child: Text("Camera not available or permissions denied."))
          : (_controller == null || !_controller!.value.isInitialized)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: previewSize,
                height: previewSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _capturedImage != null ? Colors.green : Colors.grey,
                    width: 4,
                  ),
                ),
                child: ClipOval(
                  child: _capturedImage != null
                      ? Image.file(_capturedImage!, fit: BoxFit.cover)
                      : CameraPreview(_controller!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _capturedImage != null
                  ? "Selfie captured"
                  : "Please capture your selfie",
              style: TextStyle(
                color: _capturedImage != null ? Colors.green : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Capture Selfie"),
              onPressed: captureSelfie,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: _isUploading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.upload),
              label: const Text("Submit"),
              onPressed: (_capturedImage != null && !_isUploading)
                  ? submitSelfie
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
