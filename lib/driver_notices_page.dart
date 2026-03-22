import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DriverNoticesPage extends StatefulWidget {
  const DriverNoticesPage({Key? key}) : super(key: key);

  @override
  State<DriverNoticesPage> createState() => _DriverNoticesPageState();
}

class _DriverNoticesPageState extends State<DriverNoticesPage> {
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);
  
  String? _vehicleId;
  final TextEditingController _noticeController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchVehicleId();
  }

  Future<void> _fetchVehicleId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _vehicleId = doc.data()?['vehicleId']?.toString() ?? 'none';
        });
      }
    }
  }

  Future<void> _sendGlobalNotice() async {
    final text = _noticeController.text.trim();
    if (text.isEmpty || _vehicleId == null) return;

    setState(() => _isSending = true);
    try {
      DateTime now = DateTime.now();
      String dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance.collection('d_notices').add({
        'vanId': _vehicleId,
        'childId': 'all',
        'childName': 'All Students',
        'sender': 'driver',
        'message': text,
        'dateKey': dateString,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      _noticeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice sent to all students successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        title: const Text('Notices', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navy,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _vehicleId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notices')
                        .where('vanId', isEqualTo: _vehicleId)
                        .where('dateKey', isEqualTo: todayKey)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: teal));
                      }
                      if (snapshot.hasError) {
                         debugPrint('Notice fetch error: ${snapshot.error}');
                         return Center(child: Text('Error loading notices', style: TextStyle(color: Colors.red)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No notices yet.',
                            style: TextStyle(color: blue, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        );
                      }

                      final List<QueryDocumentSnapshot> docs = snapshot.data!.docs.toList();
                      docs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>?;
                        final dataB = b.data() as Map<String, dynamic>?;
                        final tA = dataA?['timestamp'] as Timestamp?;
                        final tB = dataB?['timestamp'] as Timestamp?;
                        if (tA == null && tB == null) return 0;
                        if (tA == null) return 1; // Put nulls at the end
                        if (tB == null) return -1;
                        return tB.compareTo(tA); // descending
                      });

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final isDriver = data['sender'] == 'driver';
                          final message = data['message'] ?? '';
                          final childName = data['childName'] ?? 'Unknown';
                          final title = isDriver ? 'You (Driver)' : "$childName's Parent";
                          final ts = data['timestamp'] as Timestamp?;
                          final timeStr = _formatTimestamp(ts);

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: navy.withOpacity(0.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: navy.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isDriver ? Icons.campaign : Icons.person_outline,
                                      color: isDriver ? teal : blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: navy,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: navy.withOpacity(0.5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: TextStyle(
                                    color: navy.withOpacity(0.85),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: navy.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, -5),
                      ),
                    ],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.campaign_rounded, color: teal, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Broadcast Notice',
                            style: TextStyle(
                              color: navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noticeController,
                        decoration: InputDecoration(
                          hintText: 'Type your official announcement here...',
                          hintStyle: TextStyle(color: navy.withOpacity(0.4)),
                          filled: true,
                          fillColor: const Color(0xFFF5F8FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        maxLines: 4,
                        minLines: 2,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                        label: Text(
                          _isSending ? 'Sending...' : 'Send to All Parents',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSending ? null : _sendGlobalNotice,
                      ),
                      const SizedBox(height: 8), // Padding for safer bottom area
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
