import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:tripmate/geofenceCheckOutPage.dart';
import 'package:tripmate/geofencecheckInPage.dart';
import 'package:tripmate/registerSelfiePage.dart';
import 'package:tripmate/telegramBotRedirectPage.dart';
import 'package:permission_handler/permission_handler.dart';

// Theme Provider
class ThemeProvider with ChangeNotifier {
  bool _isDark = true;
  bool get isDark => _isDark;
  ThemeMode get currentTheme => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  final statuses = await [
    Permission.camera,
    Permission.storage,
  ].request();
  if (statuses[Permission.camera] != PermissionStatus.granted) {
    print("Camera permission not granted.");
  }
  if (statuses[Permission.storage] != PermissionStatus.granted) {
    print("Storage permission not granted.");
  }
}

Future<String> getBackendUrl() async {
  return 'http://192.168.149.20:8000'; // Replace with your backend IP
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'TripMate',
      themeMode: themeProvider.currentTheme,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'TripMate'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool isLoading = false;

  Future<void> sendOtp() async {
    String phone = _phoneController.text.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      showAlert("Enter a valid 10-digit phone number.");
      return;
    }

    setState(() {
      isLoading = true;
      _otpController.clear();
    });

    try {
      final baseUrl = await getBackendUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/send_otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "chat_id": "5598478937"
        }),
      );

      final json = jsonDecode(res.body);
      setState(() => isLoading = false);

      if (json['success'] == true) {
        showOtpDialog();
      } else {
        showAlert("Error: ${json['message']}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      showAlert("Failed to connect to server.");
    }
  }

  Future<void> verifyOtp() async {
    String otp = _otpController.text.trim();
    String phone = _phoneController.text.trim();
    if (otp.isEmpty) {
      showAlert("Please enter OTP.");
      return;
    }

    try {
      final baseUrl = await getBackendUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/verify_otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone, "otp": otp}),
      );

      final json = jsonDecode(res.body);
      Navigator.pop(context); // Close OTP dialog

      if (json['success'] == true) {
        showPostVerificationOptions(phone);
      } else {
        showAlert("Invalid OTP.");
      }
    } catch (e) {
      showAlert("Failed to connect to server.");
    }
  }

  void showAlert(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Alert"),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  void showOtpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enter OTP"),
        content: TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "OTP"),
        ),
        actions: [
          TextButton(
            child: const Text("Submit"),
            onPressed: verifyOtp,
          ),
        ],
      ),
    );
  }

  void showPostVerificationOptions(String phoneNumber) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select an Option"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterSelfiePage(phoneNumber: phoneNumber)),
                );
              },
              child: const Text("Register New Selfie"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => GeofenceCheckinPage(phoneNumber: phoneNumber)),
                );
              },
              child: const Text("Check-In"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => GeofenceCheckoutPage(phoneNumber: phoneNumber)),
                );
              },
              child: const Text("Check-Out"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: isDark ? Colors.grey[850] : Colors.grey[300],
      ),
      drawer: Drawer(
        child: Container(
          color: isDark ? Colors.grey[900] : Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey,
                child: const Icon(Icons.location_on_outlined, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text("TripMate", style: TextStyle(fontSize: 16, color: textColor)),
              const SizedBox(height: 20),
              SwitchListTile(
                title: Text("Dark Mode", style: TextStyle(color: textColor)),
                value: isDark,
                onChanged: (_) => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
              ),
              const Spacer(),

            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth > 500 ? 450 : constraints.maxWidth * 0.9;
          return Container(
            color: bgColor,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text("Welcome to TripMate", style: TextStyle(fontSize: 26, color: textColor)),
                  const SizedBox(height: 40),
                  Container(
                    width: width,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text("Login with Telegram OTP", style: TextStyle(fontSize: 20, color: textColor)),
                        const SizedBox(height: 25),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: "Phone Number",
                            hintText: "Enter your 10-digit phone number",
                            labelStyle: TextStyle(color: textColor),
                            hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                            prefixIcon: Icon(Icons.phone, color: textColor),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: textColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: textColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton(
                          onPressed: isLoading ? null : sendOtp,
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          child: isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                              : const Text("Send OTP via Telegram"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
