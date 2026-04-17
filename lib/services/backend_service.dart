import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendService {
  // 🔥 AUTO-CONFIGURED FOR BOTH DEVICES
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:5000"; // Works for PC Browser
    } else {
      // 🚀 Use your PC's IP address so your phone can connect
      // For Android Emulator, you can also use "http://10.0.2.2:5000"
      return "http://192.168.1.2:5000";
    }
  }

  // Singleton
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  final _alertsController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get alertsStream => _alertsController.stream;

  Timer? _timer;

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        // Fetch status
        final statusResponse = await http.get(Uri.parse("$baseUrl/status"));
        if (statusResponse.statusCode == 200) {
          final data = json.decode(statusResponse.body);
          _statusController.add(data);
        }

        // Fetch alerts
        final alertsResponse = await http.get(Uri.parse("$baseUrl/alerts"));
        if (alertsResponse.statusCode == 200) {
          final data = json.decode(alertsResponse.body);
          if (data is List) {
            _alertsController.add(data);
          }
        }
      } catch (e) {
        // Silently ignore errors
      }
    });
  }

  void stopPolling() {
    _timer?.cancel();
  }

  void dispose() {
    stopPolling();
    _statusController.close();
    _alertsController.close();
  }
}
