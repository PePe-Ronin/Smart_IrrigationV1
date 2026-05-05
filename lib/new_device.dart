import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WifiProvisionPage extends StatefulWidget {
  const WifiProvisionPage({super.key});

  @override
  State<WifiProvisionPage> createState() => _WifiProvisionPageState();
}

class _WifiProvisionPageState extends State<WifiProvisionPage> {
  final ssidController = TextEditingController();
  final passController = TextEditingController();
  final deviceIdController = TextEditingController();

  bool loading = false;

  Future<void> sendWifi() async {
    setState(() => loading = true);

    try {
      final url = Uri.parse(
        "http://192.168.4.1/setup?"
        "ssid=${ssidController.text}"
        "&pass=${passController.text}"
        "&device=${deviceIdController.text}",
      );

      final res = await http.get(url);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.body)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connect Device")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Connect to ESP32 WiFi first"),
            const SizedBox(height: 10),

            TextField(
              controller: deviceIdController,
              decoration: const InputDecoration(
                labelText: "Device ID (e.g. esp32_001)",
              ),
            ),

            TextField(
              controller: ssidController,
              decoration: const InputDecoration(labelText: "WiFi SSID"),
            ),

            TextField(
              controller: passController,
              decoration: const InputDecoration(labelText: "WiFi Password"),
              obscureText: true,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : sendWifi,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Send to Device"),
            ),
          ],
        ),
      ),
    );
  }
}
