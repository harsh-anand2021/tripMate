import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeofenceCheckoutPage extends StatefulWidget {
  final String phoneNumber;

  const GeofenceCheckoutPage({super.key, required this.phoneNumber});

  @override
  State<GeofenceCheckoutPage> createState() => _GeofenceCheckoutPageState();
}

class _GeofenceCheckoutPageState extends State<GeofenceCheckoutPage> {
  CameraController? _controller;
  File? _selfie;
  bool _loading = false;
  String? _statusMessage;
  String _tripNumber = "";
  String? _storedTripNumber;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadStoredTripNumber();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCam = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.front);
    _controller = CameraController(frontCam, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _loadStoredTripNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storedTripNumber = prefs.getString('trip_number');
    });
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services disabled');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _captureSelfie() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final image = await _controller!.takePicture();

    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'checkout_selfie.jpg');
    final file = File(path);
    await file.writeAsBytes(await image.readAsBytes());

    setState(() => _selfie = file);
  }

  Future<String> _sendCheckout(File selfie, String phone, String tripNumber, double lat, double lng) async {
    final backendUrl = 'http://192.168.149.20:8000'; // change to your backend IP
    final uri = Uri.parse('$backendUrl/checkout');

    final request = http.MultipartRequest('POST', uri)
      ..fields['phone_number'] = phone
      ..fields['trip_number'] = tripNumber
      ..fields['latitude'] = lat.toString()
      ..fields['longitude'] = lng.toString()
      ..files.add(await http.MultipartFile.fromPath('selfie', selfie.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      if (body.contains('success')) return 'success';
      if (body.contains('face_mismatch')) return 'face_mismatch';
      if (body.contains('location_invalid')) return 'location_invalid';
      return 'error';
    } else {
      return 'error';
    }
  }

  Future<void> _submitCheckout() async {
    if (_selfie == null || _tripNumber.isEmpty) return;

    // Check trip number match
    if (_tripNumber != _storedTripNumber) {
      setState(() {
        _statusMessage = "❌ Trip number does not match the one from check-in.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      final position = await _getCurrentLocation();
      final status = await _sendCheckout(_selfie!, widget.phoneNumber, _tripNumber, position.latitude, position.longitude);

      String message;
      switch (status) {
        case 'success':
          message = "✅ Checkout successful!";
          break;
        case 'face_mismatch':
          message = "❌ Face does not match. Please try again.";
          setState(() => _selfie = null); // force recapture
          break;
        case 'location_invalid':
          message = "📍 You are outside the allowed geofence.";
          break;
        default:
          message = "⚠️ Something went wrong. Please try again.";
          setState(() => _selfie = null);
      }

      setState(() {
        _statusMessage = message;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Failed to checkout: $e";
        _selfie = null;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Geofence Checkout")),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Enter your Trip Number and capture a selfie to check out."),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: "Trip Number",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _tripNumber = value.trim(),
            ),
            const SizedBox(height: 16),
            ClipOval(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(border: Border.all(width: 3, color: Colors.deepOrange)),
                child: _selfie == null
                    ? CameraPreview(_controller!)
                    : Image.file(_selfie!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Capture Checkout Selfie"),
              onPressed: _captureSelfie,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.logout),
              label: const Text("Submit Checkout"),
              onPressed: (_selfie != null && !_loading && _tripNumber.isNotEmpty)
                  ? _submitCheckout
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            ),
            const SizedBox(height: 20),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: _statusMessage!.contains("✅") ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
