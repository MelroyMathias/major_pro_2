import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import 'video_view.dart';

class DetectionPanel extends StatefulWidget {
  final bool showVideo;
  final bool showAlerts;

  const DetectionPanel({
    super.key,
    this.showVideo = true,
    this.showAlerts = true,
  });

  @override
  State<DetectionPanel> createState() => _DetectionPanelState();
}

class _DetectionPanelState extends State<DetectionPanel> {
  @override
  void initState() {
    super.initState();
    BackendService().startPolling();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🎥 VIDEO
        if (widget.showVideo)
          SizedBox(
            height: 300,
            width: double.infinity,
            child: VideoStreamView(
              streamUrl: "${BackendService.baseUrl}/video",
            ),
          ),

        /// 🚨 REAL-TIME STATUS
        StreamBuilder<Map<String, dynamic>>(
          stream: BackendService().statusStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final status = snapshot.data!;
            final threat = status['threat'] ?? 'LOW';
            final weapon = status['weapon'] ?? 'None';

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: threat == 'HIGH' ? Colors.red[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    "THREAT: $threat",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: threat == 'HIGH' ? Colors.red : Colors.green,
                    ),
                  ),
                  Text(
                    "WEAPON: $weapon",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        ),

        /// 🚨 ALERTS
        if (widget.showAlerts)
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: BackendService().alertsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final detections = snapshot.data!;

                if (detections.isEmpty) {
                  return const Center(child: Text("No alerts yet"));
                }

                return ListView.builder(
                  itemCount: detections.length,
                  itemBuilder: (context, index) {
                    final data = detections[index];
                    final imagePath = data['image_path'] as String?;
                    final imageName = imagePath?.split(RegExp(r'[/\\]')).last;
                    final imageUrl = imageName != null
                        ? "http://127.0.0.1:5000/captures/$imageName"
                        : null;

                    return ListTile(
                      leading: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.warning, color: Colors.red),
                            )
                          : const Icon(Icons.warning, color: Colors.red),
                      title: Text("${data['weapon']} detected"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Threat: ${data['threatLevel']}"),
                          Text("Area: ${data['area']}"),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
