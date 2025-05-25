import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tripmate/geofenceCheckOutPage.dart';

class GeofenceCheckinPage extends StatefulWidget {
  final String phoneNumber;

  const GeofenceCheckinPage({super.key, required this.phoneNumber});

  @override
  State<GeofenceCheckinPage> createState() => _GeofenceCheckinPageState();
}

class _GeofenceCheckinPageState extends State<GeofenceCheckinPage> {
  CameraController? _controller;
  File? _selfie;
  bool _loading = false;
  String? _statusMessage;
  bool _checkinSuccess = false;
  int? _tripNumber;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCam = cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front);
    _controller = CameraController(frontCam, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services disabled');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _captureSelfie() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final image = await _controller!.takePicture();

    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'checkin_selfie.jpg');
    final file = File(path);
    await file.writeAsBytes(await image.readAsBytes());

    setState(() => _selfie = file);
  }

  Future<Map<String, dynamic>> _sendCheckin(
      File selfie, String phone, double lat, double lng) async {
    final backendUrl = 'http://192.168.149.20:8000'; // Replace with your IP
    final uri = Uri.parse('$backendUrl/checkin');

    final request = http.MultipartRequest('POST', uri)
      ..fields['phone_number'] = phone
      ..fields['latitude'] = lat.toString()
      ..fields['longitude'] = lng.toString()
      ..files.add(await http.MultipartFile.fromPath('selfie', selfie.path));

    final response = await request.send();

    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      return {
        "success": false,
        "result": "error",
        "message": "Server error",
      };
    }
  }

  Future<void> _submitCheckin() async {
    if (_selfie == null) return;

    setState(() {
      _loading = true;
      _statusMessage = null;
      _checkinSuccess = false;
      _tripNumber = null;
    });

    try {
      final position = await _getCurrentLocation();
      final response = await _sendCheckin(
          _selfie!, widget.phoneNumber, position.latitude, position.longitude);

      String message;
      if (response["success"] == true && response["trip_number"] != null) {
        message = "✅ Check-in successful! Trip #: ${response["trip_number"]}";
        _checkinSuccess = true;
        _tripNumber = response["trip_number"];
      } else if (response["result"] == "face_mismatch") {
        message = "❌ Face does not match. Please try again.";
        _selfie = null;
      } else if (response["result"] == "location_invalid") {
        message = "📍 You are outside the allowed geofence.";
      } else {
        message = "⚠️ Something went wrong. Please try again.";
        _selfie = null;
      }

      setState(() => _statusMessage = message);
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Failed to check-in: $e";
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

  void _navigateToCheckout(BuildContext ctx) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => GeofenceCheckoutPage(phoneNumber: widget.phoneNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Geofence Check-In")),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
                "Please take a new selfie for check-in within geofence."),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 4),
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: _selfie == null
                      ? CameraPreview(_controller!)
                      : Image.file(_selfie!, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Capture New Selfie"),
              onPressed: _captureSelfie,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.login),
              label: const Text("Submit Check-In"),
              onPressed: (_selfie != null && !_loading)
                  ? _submitCheckin
                  : null,
            ),
            const SizedBox(height: 20),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: _statusMessage!.contains("✅")
                      ? Colors.green
                      : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            if (_tripNumber != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  "🎫 Your Trip Number: $_tripNumber",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Proceed to Checkout"),
              onPressed:
              _checkinSuccess ? () => _navigateToCheckout(context) : null,
              style:
              ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
