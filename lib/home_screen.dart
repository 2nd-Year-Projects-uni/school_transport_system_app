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
      final hasVan =
          data != null &&
          data.containsKey('vanId') &&
          data['vanId'] != null &&
          data['vanId'].toString().isNotEmpty;

      if (!mounted) return;

      if (hasVan) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DashboardPage(childId: studentId, childName: studentName),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FilteredVansPage(childId: studentId, childName: studentName),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong. Please try again."),
        ),
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
    final childRef = FirebaseFirestore.instance
        .collection('Children')
        .doc(childId);
    batch.update(childRef, {'vanId': vanId, 'code': vanCode});

    // Update van doc — add childId to linkedChildren array
    final vanRef = FirebaseFirestore.instance.collection('vehicles').doc(vanId);
    batch.update(vanRef, {
      'linkedChildren': FieldValue.arrayUnion([childId]),
    });

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF001F3F);
    const Color blue = Color(0xFF005792);
    const Color teal = Color(0xFF00B894);
    final Color mutedBlue = blue.withOpacity(0.72);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
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
          "Select Child",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.12)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00264D), Color(0xFF005792)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
                boxShadow: [
                  BoxShadow(
                    color: navy.withOpacity(0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.family_restroom,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Children',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap a card to continue to tracking and details.',
                          style: TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            blue.withOpacity(0.0),
                            blue.withOpacity(0.24),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: blue.withOpacity(0.12)),
                    ),
                    child: Text(
                      'Children List',
                      style: TextStyle(
                        color: navy.withOpacity(0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            blue.withOpacity(0.24),
                            blue.withOpacity(0.0),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 28,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: blue.withOpacity(0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.07),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.child_care_outlined,
                            size: 62,
                            color: blue.withOpacity(0.30),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            "No children added yet",
                            style: TextStyle(
                              fontSize: 18,
                              color: navy.withOpacity(0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Use the button below to add your first child",
                            style: TextStyle(
                              fontSize: 13,
                              color: blue.withOpacity(0.58),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final students = snapshot.data!.docs;

                  return ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final data = student.data() as Map<String, dynamic>;
                      final studentName =
                          data['name']?.toString().trim().isNotEmpty == true
                          ? data['name'].toString().trim()
                          : 'Child';
                      final hasVan =
                          data.containsKey('vanId') &&
                          data['vanId'] != null &&
                          data['vanId'].toString().isNotEmpty;

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFF9FCFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: hasVan
                                ? teal.withOpacity(0.20)
                                : blue.withOpacity(0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: navy.withOpacity(0.09),
                              blurRadius: 16,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () =>
                                handleChildTap(student.id, studentName),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: teal.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.child_care,
                                      color: teal,
                                      size: 27,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF001F3F),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasVan
                                                ? teal.withOpacity(0.13)
                                                : blue.withOpacity(0.11),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                hasVan
                                                    ? Icons.link_rounded
                                                    : Icons.link_off_rounded,
                                                size: 14,
                                                color: hasVan
                                                    ? teal
                                                    : mutedBlue,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                hasVan
                                                    ? 'Linked to a van'
                                                    : 'Not linked to a van',
                                                style: TextStyle(
                                                  color: hasVan
                                                      ? teal
                                                      : mutedBlue,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: hasVan
                                          ? teal.withOpacity(0.12)
                                          : blue.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      hasVan
                                          ? Icons.directions_bus_rounded
                                          : Icons.search_rounded,
                                      color: hasVan ? teal : blue,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
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
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddChildPage()),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Add New Child",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 6,
                  shadowColor: navy.withOpacity(0.20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
