import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverStudentsPage extends StatefulWidget {
  const DriverStudentsPage({Key? key}) : super(key: key);

  @override
  State<DriverStudentsPage> createState() => _DriverStudentsPageState();
}

class _DriverStudentsPageState extends State<DriverStudentsPage> {
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);

  late Future<List<Map<String, dynamic>>> _studentsFuture;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _studentsFuture = _fetchStudents();
  }

  Future<List<Map<String, dynamic>>> _fetchStudents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final vehicleId = userDoc.data()?['vehicleId'] as String?;
    if (vehicleId == null || vehicleId.isEmpty) return [];
    final vehicleDoc = await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(vehicleId)
        .get();
    final linkedChildren =
        vehicleDoc.data()?['linkedChildren'] as List<dynamic>? ?? [];
    if (linkedChildren.isEmpty) return [];
    final childrenCollection = FirebaseFirestore.instance.collection(
      'Children',
    );
    final childrenDocs = await Future.wait(
      linkedChildren.map((id) async {
        if (id == null || (id is! String && id is! int)) return null;
        final doc = await childrenCollection.doc(id.toString()).get();
        final data = doc.data();
        if (data != null) {
          data['id'] = doc.id;
          final pId = data['parentId'];
          if (pId != null && pId.toString().isNotEmpty) {
            try {
              final pDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(pId.toString())
                  .get();
              if (pDoc.exists) {
                data['parentName'] = pDoc.data()?['name'] ?? '';
                data['parentContact'] = pDoc.data()?['phone'] ?? '';
              }
            } catch (_) {}
          }

          final rawAbsent = data['absentSlots'] is Map
              ? data['absentSlots'] as Map
              : {};
          final rawOverrides = data['attendanceOverrides'] is Map
              ? data['attendanceOverrides'] as Map
              : {};
          DateTime now = DateTime.now();
          String dateKey =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          String weekdayKey = now.weekday.toString();

          bool comingMorning = true;
          bool comingAfternoon = true;

          if (rawAbsent.containsKey(weekdayKey) &&
              rawAbsent[weekdayKey] is Map) {
            final slotDict = rawAbsent[weekdayKey] as Map;
            comingMorning = !(slotDict['morning'] == true);
            comingAfternoon = !(slotDict['afternoon'] == true);
          }

          if (rawOverrides.containsKey(dateKey) &&
              rawOverrides[dateKey] is Map) {
            final overrideDict = rawOverrides[dateKey] as Map;
            comingMorning = overrideDict['morning'] != false;
            comingAfternoon = overrideDict['afternoon'] != false;
          }

          data['comingMorning'] = comingMorning;
          data['comingAfternoon'] = comingAfternoon;
        }
        return data;
      }),
    );
    return childrenDocs.whereType<Map<String, dynamic>>().toList();
  }

  Widget _buildAttendanceBadge(String slot, bool coming) {
    return Container(
      width: 105,
      padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: coming ? teal.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: coming ? teal.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            coming ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: coming ? teal : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            '$slot: ${coming ? 'Yes' : 'No'}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: coming ? teal : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Morning', 'Afternoon'].map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: isSelected,
                selectedColor: navy,
                backgroundColor: navy.withOpacity(0.05),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: navy,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Students',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F8FC),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: teal),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No students assigned to this vehicle.',
                      style: TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                var students = snapshot.data!;
                if (_selectedFilter == 'Morning') {
                  students = students
                      .where((s) => s['comingMorning'] == true)
                      .toList();
                } else if (_selectedFilter == 'Afternoon') {
                  students = students
                      .where((s) => s['comingAfternoon'] == true)
                      .toList();
                }

                if (students.isEmpty) {
                  return const Center(
                    child: Text(
                      'No students match this filter.',
                      style: TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final name = (student['name'] ?? 'Unnamed').toString();
                    final school = student['school'] ?? '';
                    final parentName = student['parentName']?.toString() ?? '';
                    final parentContact =
                        student['parentContact']?.toString() ?? '';
                    final address = student['address'] ?? '';
                    final comingMorning = student['comingMorning'] == true;
                    final comingAfternoon = student['comingAfternoon'] == true;
                    final initials = name.isNotEmpty
                        ? name
                              .trim()
                              .split(' ')
                              .map((e) => e.isNotEmpty ? e[0] : '')
                              .take(2)
                              .join()
                              .toUpperCase()
                        : '?';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: blue.withOpacity(0.13)),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.07),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: teal.withOpacity(0.13),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: teal,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: navy,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                  if (school.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.school,
                                          size: 16,
                                          color: blue.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            school,
                                            style: TextStyle(
                                              color: blue.withOpacity(0.8),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (parentName.isNotEmpty ||
                                      parentContact.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 16,
                                          color: blue.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            parentName.isNotEmpty
                                                ? 'Parent: $parentName'
                                                : 'Parent',
                                            style: TextStyle(
                                              color: blue.withOpacity(0.8),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (address.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.home_outlined,
                                          size: 16,
                                          color: blue.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            address,
                                            style: TextStyle(
                                              color: blue.withOpacity(0.8),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildAttendanceBadge(
                                        'Morning',
                                        comingMorning,
                                      ),
                                      _buildAttendanceBadge(
                                        'Afternoon',
                                        comingAfternoon,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (parentContact.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.call_outlined,
                                    color: teal,
                                    size: 26,
                                  ),
                                  onPressed: () async {
                                    final phone = parentContact.replaceAll(
                                      RegExp(r'[^\d+]'),
                                      '',
                                    );
                                    final Uri launchUri = Uri(
                                      scheme: 'tel',
                                      path: phone,
                                    );
                                    try {
                                      await launchUrl(launchUri);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not open phone dialer',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  tooltip: 'Call Parent',
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
