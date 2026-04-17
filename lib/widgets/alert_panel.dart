import 'package:flutter/material.dart';
import '../services/backend_service.dart';

class AlertPanel extends StatefulWidget {
  const AlertPanel({super.key});

  @override
  State<AlertPanel> createState() => _AlertPanelState();
}

class _AlertPanelState extends State<AlertPanel> {
  @override
  void initState() {
    super.initState();
    BackendService().startPolling();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🚨 Live Alerts",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: BackendService().alertsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final alerts = snapshot.data!;

                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.grey[400], size: 40),
                        const SizedBox(height: 10),
                        Text(
                          "No active alerts\nMonitoring...",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                /// 🔥 SHOW ONLY LATEST ALERT
                final data = alerts.first;
                final imagePath = data['image_path'] as String?;
                final imageName = imagePath?.split(RegExp(r'[/\\]')).last;
                final imageUrl = imageName != null 
                    ? "${BackendService.baseUrl}/captures/$imageName"
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 📸 IMAGE
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(child: Text("Image Load Error")),
                            )
                          : const Center(child: Text("No Image Available")),
                    ),

                    const SizedBox(height: 10),

                    /// 🔫 Weapon
                    Text(
                      "Weapon: ${data['weapon']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    /// 🚨 Threat
                    Text("Threat: ${data['threatLevel']}"),

                    /// 📍 Area
                    Text("Area: ${data['area']}"),

                    const SizedBox(height: 10),

                    /// 🔴 STATUS
                    const Text(
                      "STATUS: ACTIVE ALERT",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
