import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BillingHistoryScreen extends StatelessWidget {
  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Billing History"),
        backgroundColor: const Color(0xff2B4CDB),
      ),

      // 🔥 Fetch data from Firestore
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments') // your collection name
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          // ⏳ Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ No Data
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No payment history found",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final payments = snapshot.data!.docs;

          // ✅ Show Data
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),

                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long,
                    color: Color(0xff2B4CDB),
                  ),

                  title: Text(
                    "${payment['month']} - Rs ${payment['amount']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: Text(
                    "Paid on: ${payment['date']}",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}