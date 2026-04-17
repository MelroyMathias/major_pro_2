import 'package:flutter/material.dart';

class VideoStreamView extends StatelessWidget {
  final String streamUrl;
  const VideoStreamView({super.key, required this.streamUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Image.network(
          streamUrl,
          fit: BoxFit.contain,
          gaplessPlayback: true, // Prevents flickering
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off, color: Colors.white, size: 50),
                const SizedBox(height: 10),
                Text(
                  "Connecting to Stream...\n$streamUrl",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 10),
                const CircularProgressIndicator(color: Colors.white),
              ],
            );
          },
        ),
      ),
    );
  }
}
