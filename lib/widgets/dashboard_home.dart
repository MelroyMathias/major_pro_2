import 'package:flutter/material.dart';
import 'detection_panel.dart';
import 'alert_panel.dart';

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "Live Weapon Detection",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: isDesktop
              ? Row(
                  children: [

                    /// 🎥 LEFT - LIVE VIDEO (70%)
                    Expanded(
                      flex: 7,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black,
                        ),
                        child: const DetectionPanel(
                          showVideo: true,
                          showAlerts: false,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    /// 🚨 RIGHT - ALERT PANEL (30%)
                    Expanded(
                      flex: 3,
                      child: const AlertPanel(),
                    ),
                  ],
                )
              : Column(
                  children: const [
                    DetectionPanel(showVideo: true, showAlerts: false),
                    SizedBox(height: 10),
                    AlertPanel(),
                  ],
                ),
        ),
      ],
    );
  }
}