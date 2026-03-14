import 'package:flutter/material.dart';
import 'pay.dart';

class HomeTab extends StatelessWidget {
  final String childId;
  final String childName;

  const HomeTab({super.key, required this.childId, required this.childName});

  @override
  Widget build(BuildContext context) {
    const Color teal = Color(0xFF00B894);
    const Color navy = Color(0xFF001F3F);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Home\n$childName",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayPage(
                      childId: childId,
                      childName: childName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text(
                'Pay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}