import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverPaymentsPage extends StatefulWidget {
  const DriverPaymentsPage({Key? key}) : super(key: key);

  @override
  State<DriverPaymentsPage> createState() => _DriverPaymentsPageState();
}

class _DriverPaymentsPageState extends State<DriverPaymentsPage> {
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);
  static const Color pendingColor = Color(0xFFF57C00); // Standard dark orange

  String? _vehicleId;
  double _monthlyFee = 0;
  bool _loadingFee = true;
  bool _savingFee = false;
  List<Map<String, dynamic>> _students = [];
  bool _loadingStudents = true;

  final TextEditingController _feeController = TextEditingController();

  // Month label for UI only
  String get _currentMonthLabel {
    final now = DateTime.now();
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month]} ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadVehicleAndFee();
    if (_vehicleId != null) {
      await _loadStudents();
    }
  }

  Future<void> _loadVehicleAndFee() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final vehicleId = userDoc.data()?['vehicleId'] as String?;
      if (vehicleId == null || vehicleId.isEmpty) {
        if (mounted) setState(() => _loadingFee = false);
        return;
      }

      final vehicleDoc = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vehicleId)
          .get();
      final fee = (vehicleDoc.data()?['monthlyFee'] as num?)?.toDouble() ?? 0;

      if (mounted) {
        setState(() {
          _vehicleId = vehicleId;
          _monthlyFee = fee;
          _feeController.text = fee > 0 ? fee.toInt().toString() : '';
          _loadingFee = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingFee = false);
    }
  }

  Future<void> _loadStudents() async {
    if (_vehicleId == null || _vehicleId!.isEmpty) return;
    if (mounted) setState(() => _loadingStudents = true);

    try {
      // Method 1: Get from vehicle's linkedChildren array (same as DriverStudentsPage)
      final vehicleDoc = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(_vehicleId)
          .get();
      
      final vData = vehicleDoc.data() ?? {};
      final List<dynamic> links = vData['linkedChildren'] as List<dynamic>? ?? [];
      
      Set<String> studentIds = links.map((e) => e.toString()).toSet();

      if (studentIds.isEmpty) {
        if (mounted) setState(() => _loadingStudents = false);
        return;
      }

      final List<Map<String, dynamic>> finalStudents = [];

      for (String childId in studentIds) {
        if (childId.isEmpty) continue;
        try {
          final childDoc = await FirebaseFirestore.instance
              .collection('Children')
              .doc(childId)
              .get();
          
          if (!childDoc.exists) continue;

          final studentData = Map<String, dynamic>.from(childDoc.data()!);
          studentData['id'] = childId;

          // Fetch parent info
          final pId = studentData['parentId']?.toString() ?? '';
          if (pId.isNotEmpty) {
            try {
              final pDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(pId)
                  .get();
              if (pDoc.exists) {
                studentData['parentName'] = pDoc.data()?['name'] ?? '';
              }
            } catch (e) {
              debugPrint('Error loading parent form child $childId: $e');
            }
          }

          // Payment record from Children document
          final amountField = studentData['feeAmount'];
          final statusField = studentData['feeStatus'];
          
          studentData['payAmount'] = (amountField as num?)?.toDouble() ?? _monthlyFee;
          studentData['payStatus'] = statusField?.toString() ?? 'pending';
          studentData['receiptUrl'] = studentData['receiptUrl']?.toString() ?? '';
          studentData['receiptNote'] = studentData['receiptNote']?.toString() ?? '';

          finalStudents.add(studentData);
        } catch (e) {
          debugPrint('Error loading child $childId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _students = finalStudents;
          _loadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint('Global error loading students: $e');
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _saveFee() async {
    final feeText = _feeController.text.trim();
    if (feeText.isEmpty) {
      _showSnack('Please enter a monthly fee amount.');
      return;
    }
    final fee = double.tryParse(feeText);
    if (fee == null || fee <= 0) {
      _showSnack('Please enter a valid fee amount.');
      return;
    }

    final focusScope = FocusScope.of(context);
    setState(() => _savingFee = true);
    try {
      // 1. Update the vehicle's monthly fee
      final int newFeeInt = fee.toInt();
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(_vehicleId)
          .update({'monthlyFee': newFeeInt});

      // 2. Update existing children with the new fee directly
      for (var student in _students) {
        try {
          await FirebaseFirestore.instance
              .collection('Children')
              .doc(student['id'])
              .update({'feeAmount': newFeeInt});
        } catch (e) {
          debugPrint('Failed to update fee for student ${student['id']}: $e');
        }
      }

      setState(() {
        _monthlyFee = fee;
        _savingFee = false;
      });

      _showSnack('Monthly fee updated to LKR $newFeeInt', success: true);
      focusScope.unfocus();

      // Reload students so payment records reflect the new fee
      await _loadStudents();
    } catch (e) {
      setState(() => _savingFee = false);
      _showSnack('Failed to update fee. Try again.');
    }
  }

  Future<void> _updatePaymentStatus(
      String childId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('Children')
          .doc(childId)
          .update({'feeStatus': newStatus});

      if (newStatus == 'paid' && _vehicleId != null) {
        final now = DateTime.now();
        final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final student = _students.firstWhere((s) => s['id'] == childId, orElse: () => {});
        final childName = student['name'] ?? 'Your child';

        await FirebaseFirestore.instance.collection('d_notices').add({
          'vanId': _vehicleId,
          'childId': childId,
          'childName': childName,
          'sender': 'driver',
          'message': 'Your monthly payment receipt has been accepted.',
          'dateKey': dateKey,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      // Refresh local list
      setState(() {
        final idx = _students.indexWhere((s) => s['id'] == childId);
        if (idx != -1) {
          _students[idx]['payStatus'] = newStatus;
        }
      });

      _showSnack(
        newStatus == 'paid'
            ? 'Payment marked as Paid ✓'
            : 'Payment marked as Pending',
        success: newStatus == 'paid',
      );
    } catch (e) {
      _showSnack('Failed to update status. Try again.');
    }
  }

  Future<void> _updateChildFee(String childId, double newFee) async {
    try {
      await FirebaseFirestore.instance
          .collection('Children')
          .doc(childId)
          .update({'feeAmount': newFee});

      setState(() {
        final idx = _students.indexWhere((s) => s['id'] == childId);
        if (idx != -1) {
          _students[idx]['payAmount'] = newFee;
        }
      });
      _showSnack('Custom fee updated for student', success: true);
    } catch (e) {
      _showSnack('Failed to update student fee. Try again.');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
    ));
  }

  void _showEditFeeDialog(Map<String, dynamic> student) {
    final name = student['name'] ?? 'Student';
    final currentAmount = (student['payAmount'] as double?) ?? _monthlyFee;
    final TextEditingController childFeeController = TextEditingController(text: currentAmount.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded, color: blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Custom Fee',
                style: const TextStyle(
                  color: navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.person_outline, 'Student', name),
            const SizedBox(height: 16),
            const Text(
              'Set a specific amount for this child due to distance or other arrangements:',
              style: TextStyle(fontSize: 13, color: navy),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: childFeeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'LKR ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: blue, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(childFeeController.text.trim());
              if (val != null && val >= 0) {
                Navigator.pop(ctx);
                _updateChildFee(student['id'], val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: blue),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: navy),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showReceiptsSheet() {
    final pendingReceipts = _students.where((s) {
      final url = s['receiptUrl']?.toString() ?? '';
      return url.isNotEmpty && s['payStatus'] != 'paid';
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: teal.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: teal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pending Receipts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: navy),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
            ),
            // List of receipts
            Expanded(
              child: pendingReceipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 48, color: navy.withOpacity(0.1)),
                          const SizedBox(height: 12),
                          Text(
                            'No pending receipts.',
                            style: TextStyle(color: navy.withOpacity(0.5), fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pendingReceipts.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, index) {
                        final student = pendingReceipts[index];
                        final name = student['name'] ?? 'Student';
                        final note = student['receiptNote']?.toString() ?? '';

                        final initials = name.toString().trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          leading: CircleAvatar(
                            backgroundColor: teal.withOpacity(0.12),
                            child: Text(initials, style: const TextStyle(color: teal, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 15)),
                          subtitle: Text(note.isNotEmpty ? note : 'Slip uploaded', style: TextStyle(color: navy.withOpacity(0.6), fontSize: 12)),
                          trailing: ElevatedButton(
                            onPressed: () {
                              _viewReceiptImage(student, ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue.withOpacity(0.1),
                              foregroundColor: blue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewReceiptImage(Map<String, dynamic> student, BuildContext sheetContext) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Receipt Slip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: navy)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: navy),
                    onPressed: () => Navigator.pop(ctx)
                  )
                ],
              ),
            ),
            Container(
              color: Colors.grey[100],
              height: 300,
              width: double.infinity,
              child: student['receiptUrl'] != null && student['receiptUrl'].toString().isNotEmpty
                  ? Image.network(
                      student['receiptUrl'],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text('Could not load image.', style: TextStyle(color: navy.withOpacity(0.5))),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: teal));
                      },
                    )
                  : Center(
                      child: Text('No image found.', style: TextStyle(color: navy.withOpacity(0.5))),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: blue.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close', style: TextStyle(color: blue, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx); // close dialog
                        Navigator.pop(sheetContext); // close bottom sheet
                        _updatePaymentStatus(student['id'], 'paid');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Mark as Paid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg, fg;
    IconData ic;
    String label;

    if (status == 'paid') {
      bg = teal.withOpacity(0.12);
      fg = teal;
      ic = Icons.check_circle_rounded;
      label = 'Paid';
    } else {
      bg = pendingColor.withOpacity(0.12);
      fg = pendingColor;
      ic = Icons.access_time_rounded;
      label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navy, Color(0xFF003366)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Fee',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _currentMonthLabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _feeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      prefixText: 'LKR  ',
                      prefixStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: '0',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _savingFee ? null : _saveFee,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: teal,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: teal.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _savingFee
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 13,
                  color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                'This fee applies to all students on your vehicle.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final paid = _students.where((s) => s['payStatus'] == 'paid').length;
    final pending = _students.where((s) => s['payStatus'] != 'paid').length;

    return Row(
      children: [
        _buildSummaryChip('Paid', paid, teal),
        const SizedBox(width: 10),
        _buildSummaryChip('Pending', pending, pendingColor),
      ],
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = (student['name'] ?? 'Unnamed').toString();
    final parentName = student['parentName']?.toString() ?? '';
    final school = student['school']?.toString() ?? '';
    final status = student['payStatus']?.toString() ?? 'pending';
    final amount = (student['payAmount'] as double?) ?? _monthlyFee;

    final initials = name.trim().split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    final isPaid = status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: blue.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + name + status
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: teal.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (parentName.isNotEmpty)
                        Text(
                          parentName,
                          style: TextStyle(
                            color: blue.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (school.isNotEmpty)
                        Text(
                          school,
                          style: TextStyle(
                            color: navy.withOpacity(0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),

            // Amount
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, size: 16, color: blue),
                  const SizedBox(width: 8),
                  Text(
                    'LKR ${amount.toInt()}',
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showEditFeeDialog(student),
                    icon: Icon(Icons.edit_rounded, color: blue.withOpacity(0.6), size: 18),
                    tooltip: 'Edit explicit fee',
                  ),
                ],
              ),
            ),

            // Action buttons
            const SizedBox(height: 14),
            Row(
              children: [
                if (!isPaid)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updatePaymentStatus(student['id'], 'paid'),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Mark as Paid',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updatePaymentStatus(student['id'], 'pending'),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Mark as Pending',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: pendingColor,
                        side: BorderSide(color: pendingColor.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingReceiptsCount = _students.where((s) {
      final url = s['receiptUrl']?.toString() ?? '';
      return url.isNotEmpty && s['payStatus'] != 'paid';
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        backgroundColor: navy,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Payments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: pendingReceiptsCount > 0,
              label: Text(pendingReceiptsCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
            ),
            tooltip: 'View Receipts',
            onPressed: _showReceiptsSheet,
          ),
        ],
      ),
      body: _loadingFee
          ? const Center(child: CircularProgressIndicator(color: teal))
          : _vehicleId == null
              ? _buildNoVehicle()
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  color: teal,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      // Fee section
                      _buildFeeSection(),
                      const SizedBox(height: 20),

                      // Summary chips
                      if (!_loadingStudents && _students.isNotEmpty) ...[
                        _buildSummaryRow(),
                        const SizedBox(height: 20),
                      ],

                      // Section header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Students',
                            style: TextStyle(
                              color: navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!_loadingStudents)
                            Text(
                              '${_students.length} enrolled',
                              style: TextStyle(
                                color: blue.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Student list
                      if (_loadingStudents)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: teal),
                          ),
                        )
                      else if (_students.isEmpty)
                        _buildEmptyState()
                      else
                        ..._students.map(_buildStudentCard).toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNoVehicle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: blue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_bus_rounded,
                color: blue.withOpacity(0.5), size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Vehicle Assigned',
            style: TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join a vehicle first to manage payments.',
            style: TextStyle(
              color: navy.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: blue.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.group_off_rounded,
                color: blue.withOpacity(0.4), size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'No students found',
            style: TextStyle(
              color: navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No students are linked to your vehicle yet.',
            style: TextStyle(
              color: navy.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
