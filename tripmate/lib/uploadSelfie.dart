import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class UploadSelfiePage extends StatefulWidget {
  @override
  _UploadSelfiePageState createState() => _UploadSelfiePageState();
}

class _UploadSelfiePageState extends State<UploadSelfiePage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String _phoneNumber = "8676096370"; // replace with your phone number or input field

  bool _isLoading = false;
  String? _responseMessage;

  Future<void> _pickImage() async {
    final XFile? pickedFile =
    await _picker.pickImage(source: ImageSource.camera); // or gallery

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _responseMessage = null;
      });
    }
  }

  Future<void> _uploadSelfie() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
      _responseMessage = null;
    });

    try {
      // Read image bytes and convert to base64 string
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse("http://192.168.14.20:8000/upload_selfie");
      final body = jsonEncode({
        "phone_number": _phoneNumber,
        "image_base64": base64Image,
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        setState(() {
          _responseMessage = "Upload successful!";
        });
      } else {
        setState(() {
          _responseMessage = "Upload failed: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _responseMessage = "Error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Upload Selfie")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_imageFile != null)
                Image.file(_imageFile!, height: 200),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.camera_alt),
                label: Text("Pick Image"),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _uploadSelfie,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Upload Selfie"),
              ),
              SizedBox(height: 16),
              if (_responseMessage != null)
                Text(_responseMessage!,
                    style: TextStyle(
                        color: _responseMessage!.startsWith("Error")
                            ? Colors.red
                            : Colors.green)),
            ],
          ),
        ));
  }
}
