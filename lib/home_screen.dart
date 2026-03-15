import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard_page.dart';
import 'add_child_page.dart';
import 'login.dart';
import 'filtered_vans.dart';

class SelectChildPage extends StatefulWidget {
  const SelectChildPage({super.key});

  @override
  State<SelectChildPage> createState() => _SelectChildPageState();
}

class _SelectChildPageState extends State<SelectChildPage> {
  final String parentId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> handleChildTap(String studentId, String studentName) async {
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('Children')
          .doc(studentId)
          .get();

      final data = childDoc.data();
      final hasVan = data != null &&
          data.containsKey('vanId') &&
          data['vanId'] != null &&
          data['vanId'].toString().isNotEmpty;

      if (!mounted) return;

      if (hasVan) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              childId: studentId,
              childName: studentName,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FilteredVansPage(
              childId: studentId,
              childName: studentName,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Something went wrong. Please try again.")),
      );
    }
  }

  // Links a child to a van:
  // 1. Writes vanId + vanCode to the child's doc
  // 2. Adds childId to the van's linkedChildren array
  Future<void> linkChildToVan({
    required String childId,
    required String vanId,
    required String vanCode,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    // Update child doc
    final childRef =
        FirebaseFirestore.instance.collection('Children').doc(childId);
    batch.update(childRef, {
      'vanId': vanId,
      'code': vanCode,
    });

    // Update van doc — add childId to linkedChildren array
    final vanRef =
        FirebaseFirestore.instance.collection('vehicles').doc(vanId);
    batch.update(vanRef, {
      'linkedChildren': FieldValue.arrayUnion([childId]),
    });

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final Color navy = const Color(0xFF001F3F);
    final Color blue = const Color(0xFF005792);
    final Color teal = const Color(0xFF00B894);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: teal,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "Select child",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // STUDENT LIST FROM FIRESTORE
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Children')
                    .where('parentId', isEqualTo: parentId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: teal),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.child_care_outlined,
                            size: 64,
                            color: blue.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No children added yet",
                            style: TextStyle(
                              fontSize: 18,
                              color: blue.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Tap the button below to add your first student",
                            style: TextStyle(
                              fontSize: 14,
                              color: blue.withOpacity(0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final students = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final data =
                          student.data() as Map<String, dynamic>;
                      final hasVan = data.containsKey('vanId') &&
                          data['vanId'] != null &&
                          data['vanId'].toString().isNotEmpty;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 6,
                              shadowColor: navy.withOpacity(0.18),
                            ),
                            onPressed: () =>
                                handleChildTap(student.id, student['name']),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  student['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  hasVan
                                      ? Icons.directions_bus
                                      : Icons.search,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                if (hasVan && data['code'] != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: teal.withOpacity(0.25),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      data['code'].toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            // ADD STUDENT BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddChildPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Add New Child",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: teal.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}