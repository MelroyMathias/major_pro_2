import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/backend_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  String mode = "live";

  final TextEditingController areaController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController lonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    BackendService().startPolling();
  }

  /// 🔥 Send demo detection
  Future<void> sendDetection() async {
    await FirebaseFirestore.instance.collection('detections').add({
      "weapon": "Gun",
      "threatLevel": "HIGH",
      "area": areaController.text,
      "cameraLat": double.tryParse(latController.text) ?? 0,
      "cameraLon": double.tryParse(lonController.text) ?? 0,
      "alertSent": false,
      "timestamp": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🚀 Detection Sent to Firebase")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        /// 🔄 MODE SWITCH
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => setState(() => mode = "live"),
              style: ElevatedButton.styleFrom(
                backgroundColor: mode == "live" ? Colors.blue : Colors.grey,
              ),
              child: const Text("Live (Backend)", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => setState(() => mode = "demo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: mode == "demo" ? Colors.blue : Colors.grey,
              ),
              child: const Text("Demo (Firebase)", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),

        const SizedBox(height: 20),

        /// 🔴 LIVE DETECTION
        if (mode == "live")
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: BackendService().alertsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!;

                if (data.isEmpty) {
                  return const Center(child: Text("No live alerts from backend"));
                }

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final d = data[index];
                    final imagePath = d['image_path'] as String?;
                    final imageName = imagePath?.split(RegExp(r'[/\\]')).last;
                    final imageUrl = imageName != null 
                        ? "${BackendService.baseUrl}/captures/$imageName"
                        : null;

                    return Card(
                      child: ListTile(
                        leading: imageUrl != null 
                          ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.warning, color: Colors.red))
                          : const Icon(Icons.warning, color: Colors.red),
                        title: Text("${d['weapon']} detected"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Threat: ${d['threatLevel']}"),
                            Text("Area: ${d['area']}"),
                            Text("Time: ${d['timestamp']}"),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

        /// 🎥 DEMO MODE
        if (mode == "demo")
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [

                  TextField(
                    controller: areaController,
                    decoration: const InputDecoration(labelText: "Camera Area"),
                  ),

                  TextField(
                    controller: latController,
                    decoration: const InputDecoration(labelText: "Latitude"),
                    keyboardType: TextInputType.number,
                  ),

                  TextField(
                    controller: lonController,
                    decoration: const InputDecoration(labelText: "Longitude"),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: sendDetection,
                    child: const Text("Simulate Detection"),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}