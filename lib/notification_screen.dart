import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // Sample notifications (replace with Firestore later if needed)
  final List<Map<String, String>> notifications = const [
    {
      "title": "Payment Approved",
      "subtitle": "Your March payment has been verified successfully.",
      "time": "2 hours ago",
    },
    {
      "title": "New Transport Fee",
      "subtitle": "April transport fee is now available.",
      "time": "1 day ago",
    },
    {
      "title": "Reminder",
      "subtitle": "Don't forget to pay May transport fee.",
      "time": "3 days ago",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: const Color(0xff2B4CDB),
        elevation: 1,
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text(
                "No notifications yet",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(
                      Icons.notifications,
                      color: Color(0xff2B4CDB),
                    ),
                    title: Text(
                      notification['title']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(notification['subtitle']!),
                    trailing: Text(
                      notification['time']!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }
}