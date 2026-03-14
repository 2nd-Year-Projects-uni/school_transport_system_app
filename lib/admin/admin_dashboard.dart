import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_login.dart';

class AdminDashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F3F),
        title: const Text('Driver Approvals',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => AdminLoginPage()));
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),
        builder: (context, snapshot) {

          // Show exact error if any
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // Still loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final drivers = snapshot.data?.docs ?? [];

          // No documents found
          if (drivers.isEmpty) {
            return const Center(
              child: Text('No drivers registered yet.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: drivers
                  .map((doc) => _DriverCard(doc: doc))
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _DriverCard({required this.doc});

  Future<void> _setApproval(bool value) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(doc.id)
        .update({'approved': value});
  }

  void _viewLicense(BuildContext context, String title, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            Image.network(url, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final bool approved = data['approved'] ?? false;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: approved ? Colors.green : Colors.orange,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data['name'] ?? 'No name',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF001F3F),
                  ),
                ),
              ),
              Chip(
                label: Text(
                  approved ? 'Approved' : 'Pending',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: approved ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Email: ${data['email'] ?? 'N/A'}'),
          Text('Phone: ${data['phone'] ?? 'N/A'}'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.credit_card, size: 16),
                  label: const Text('Front'),
                  onPressed: data['licenseFrontUrl'] != null
                      ? () => _viewLicense(
                          context, 'License Front', data['licenseFrontUrl'])
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.credit_card, size: 16),
                  label: const Text('Back'),
                  onPressed: data['licenseBackUrl'] != null
                      ? () => _viewLicense(
                          context, 'License Back', data['licenseBackUrl'])
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green),
                  onPressed: approved ? null : () => _setApproval(true),
                  child: const Text('Approve',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red),
                  onPressed: !approved ? null : () => _setApproval(false),
                  child: const Text('Revoke',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}