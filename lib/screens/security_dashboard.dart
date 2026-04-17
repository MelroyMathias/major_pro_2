import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import '../widgets/video_view.dart';
import '../services/backend_service.dart';

class SecurityDashboard extends StatefulWidget {
  const SecurityDashboard({super.key});

  @override
  State<SecurityDashboard> createState() => _SecurityDashboardState();
}

class _SecurityDashboardState extends State<SecurityDashboard> {
  Stream<Position>? positionStream;
  Position? currentPosition;
  bool isLoading = true;
  String statusText = "Initializing...";
  Map<String, dynamic>? latestAlert;

  static const platform = MethodChannel('kiosk_mode');

  @override
  void initState() {
    super.initState();

    print("🔥 GUARD UID: ${FirebaseAuth.instance.currentUser?.uid}");

    enableKioskMode();
    setOnline();
    startLocationUpdates();
    listenForAlerts();
  }

  /// 🚨 ALERT LISTENER
  void listenForAlerts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance
        .collection('alerts')
        .where('targetGuardId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) async {
          for (var doc in snapshot.docs) {
            final data = doc.data();

            if (data['status'] == 'pending') {
              print("🚨 ALERT RECEIVED: $data");

              setState(() {
                latestAlert = data;
              });

              try {
                if (await Vibration.hasVibrator() == true) {
                  Vibration.vibrate(duration: 2000);
                }
              } catch (e) {
                print("Vibration error: $e");
              }

              await doc.reference.update({'status': 'received'});

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "🚨 ALERT: ${data['weapon'] ?? 'Weapon'} detected!",
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          }
        });
  }

  Future<void> enableKioskMode() async {
    try {
      await platform.invokeMethod('startKiosk');
    } catch (e) {
      print("Error enabling kiosk: $e");
    }
  }

  Future<void> disableKioskMode() async {
    try {
      await platform.invokeMethod('stopKiosk');
    } catch (e) {
      print("Error disabling kiosk: $e");
    }
  }

  Future<void> setOnline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isOnline': true},
      );
    }
  }

  Future<void> setOffline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isOnline': false},
      );
    }
  }

  Future<void> startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        isLoading = false;
        statusText = "Enable GPS to continue";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        isLoading = false;
        statusText = "Permission permanently denied";
      });
      return;
    }

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    positionStream!.listen((Position position) async {
      final user = FirebaseAuth.instance.currentUser;

      setState(() {
        currentPosition = position;
        isLoading = false;
        statusText = "Tracking Active";
      });

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'currentLocation': {
                'latitude': position.latitude,
                'longitude': position.longitude,
              },
              'lastUpdated': FieldValue.serverTimestamp(),
            });
      }
    });
  }

  @override
  void dispose() {
    setOffline();
    super.dispose();
  }

  Future<void> logout() async {
    await disableKioskMode();
    await setOffline();
    await FirebaseAuth.instance.signOut();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Guard Dashboard"),
          centerTitle: true,
          backgroundColor: latestAlert != null ? Colors.red : Colors.blue,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: logout),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    /// 🛡️ WELCOME & STATUS SECTION
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.security, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Guard Active",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Status: $statusText",
                                    style: TextStyle(
                                      color: statusText == "Tracking Active"
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (currentPosition != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 25),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "📍 My Location: ${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    /// 🚨 ALERT SECTION
                    if (latestAlert != null)
                      Container(
                        padding: const EdgeInsets.all(15),
                        margin: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.red, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                                SizedBox(width: 10),
                                Text(
                                  "EMERGENCY ALERT",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.red, thickness: 1.5),
                            const SizedBox(height: 15),

                            /// 📸 CAPTURED IMAGE (Primary visual now)
                            Builder(
                              builder: (context) {
                                final imageName = latestAlert!['image_name'] ?? 
                                    (latestAlert!['image_path'] != null 
                                        ? latestAlert!['image_path'].split(RegExp(r'[/\\]')).last 
                                        : null);
                                
                                if (imageName == null) return const SizedBox();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Captured Threat Evidence:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 300,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red[300]!, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                          )
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          "${BackendService.baseUrl}/captures/$imageName",
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.broken_image, color: Colors.red),
                                                    Text("Image Load Error", style: TextStyle(color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _alertInfoItem("Weapon", latestAlert!['weapon'] ?? 'Unknown'),
                                _alertInfoItem("Threat", latestAlert!['threatLevel'] ?? 'Unknown'),
                              ],
                            ),
                            const SizedBox(height: 15),
                            _alertInfoItem("Detected Area", latestAlert!['area'] ?? 'Live Camera'),
                            
                            const SizedBox(height: 25),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final uid = FirebaseAuth.instance.currentUser?.uid;
                                  if (uid == null) return;

                                  // Update alert status in Firestore
                                  final snapshots = await FirebaseFirestore.instance
                                      .collection('alerts')
                                      .where('targetGuardId', isEqualTo: uid)
                                      .where('status', isEqualTo: 'received')
                                      .get();

                                  for (var doc in snapshots.docs) {
                                    await doc.reference.update({'status': 'resolved', 'resolvedAt': FieldValue.serverTimestamp()});
                                  }

                                  setState(() {
                                    latestAlert = null;
                                  });

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("✅ Culprit reported as caught! Well done."),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.verified_user, color: Colors.white),
                                label: const Text(
                                  "CULPRIT CAUGHT",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: Colors.green.withOpacity(0.5),
                              size: 100,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "All Clear",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "No active threats detected. The system is monitoring for your safety.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _alertInfoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
