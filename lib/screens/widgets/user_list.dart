import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserList extends StatelessWidget {
  const UserList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] == 'security';
        }).toList();

        final online = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isOnline'] == true;
        }).length;

        final offline = users.length - online;

        return Column(
          children: [

            /// 🔥 STATS MOVED HERE
            Row(
              children: [
                _card("Users", users.length, Colors.blue),
                _card("Online", online, Colors.green),
                _card("Offline", offline, Colors.red),
              ],
            ),

            const SizedBox(height: 15),

            /// 🔻 LIST
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final data = users[index].data() as Map<String, dynamic>;

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(data['name'] ?? ''),
                    subtitle: Text(data['email'] ?? ''),
                    trailing: Text(
                      data['isOnline'] == true ? "Online" : "Offline",
                      style: TextStyle(
                        color: data['isOnline'] == true
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(String title, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text("$count",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Text(title,
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}