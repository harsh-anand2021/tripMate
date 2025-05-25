import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TelegramBotRedirectPage extends StatefulWidget {
  const TelegramBotRedirectPage({Key? key}) : super(key: key);

  @override
  State<TelegramBotRedirectPage> createState() => _TelegramBotRedirectPageState();
}

class _TelegramBotRedirectPageState extends State<TelegramBotRedirectPage> {
  final String botUsername = 'TripMateOTP_bot'; // Replace this with your bot username
  late final Uri telegramUrl;

  @override
  void initState() {
    super.initState();
    telegramUrl = Uri.parse('https://t.me/$botUsername');
    _openTelegramBot();
  }

  Future<void> _openTelegramBot() async {
    if (await canLaunchUrl(telegramUrl)) {
      await launchUrl(telegramUrl, mode: LaunchMode.externalApplication);
    } else {
      // Could not open Telegram
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Telegram. Please try manually.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Telegram'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'We are redirecting you to our Telegram chatbot.\n\n'
                  'Please press "Start" in the chat and follow the instructions to link your phone number.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openTelegramBot,
              icon: const Icon(Icons.telegram),
              label: const Text('Open Telegram Chatbot'),
            ),
          ],
        ),
      ),
    );
  }
}
