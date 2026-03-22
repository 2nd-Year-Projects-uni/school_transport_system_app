import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PayPage extends StatefulWidget {
  final String childId;
  final String childName;

  const PayPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  static const Color navy = Color(0xFF001F3F);
  static const Color teal = Color(0xFF00B894);
  static const Color blue = Color(0xFF005792);
  static const Color amber = Color(0xFFF39C12);

  bool _isUploading = false;

  String get _currentMonthLabel {
    final now = DateTime.now();
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month]} ${now.year}';
  }

  Future<void> _pickAndUploadSlip() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // compress to save bandwidth
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(pickedFile.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child('${widget.childId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId)
          .update({
        'receiptUrl': downloadUrl,
        'receiptDate': FieldValue.serverTimestamp(),
        'receiptNote': 'Bank Slip Uploaded',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank slip uploaded successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _viewReceiptImage(String url) async {
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
              height: 350,
              width: double.infinity,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text('Could not load image.', style: TextStyle(color: navy.withOpacity(0.5))),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: teal));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        title: const Text('Fee Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Children').doc(widget.childId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: teal));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildMessageState('Child not found', 'Unable to retrieve child information.');
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final vanId = data['vanId']?.toString() ?? '';
          final feeAmount = (data['feeAmount'] as num?)?.toDouble() ?? 0.0;
          final status = data['feeStatus']?.toString() ?? 'pending';
          final receiptUrl = data['receiptUrl']?.toString() ?? '';

          if (vanId.isEmpty) {
            return _buildMessageState('Not Assigned', 'This child is not assigned to a van yet.');
          }

          if (feeAmount <= 0) {
            return _buildMessageState('Fee Not Set', 'The driver has not yet set a monthly fee amount for this child.');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildChildHeader(),
                const SizedBox(height: 24),
                _buildPaymentCard(feeAmount, status, receiptUrl),
                const SizedBox(height: 30),
                if (status != 'paid') _buildUploadSection(receiptUrl),
                if (status == 'paid') _buildReceiptSection(receiptUrl, isPaid: true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChildHeader() {
    final initials = widget.childName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: teal.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: teal.withOpacity(0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(color: teal, fontWeight: FontWeight.w900, fontSize: 22),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment For',
                style: TextStyle(color: navy.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.childName,
                style: const TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(double amount, String status, String receiptUrl) {
    final isPaid = status == 'paid';
    final hasReceipt = receiptUrl.isNotEmpty;

    Color badgeBg;
    Color badgeFg;
    String badgeLabel;
    IconData badgeIcon;

    if (isPaid) {
      badgeBg = teal.withOpacity(0.15);
      badgeFg = teal;
      badgeLabel = 'Paid';
      badgeIcon = Icons.check_circle_rounded;
    } else if (hasReceipt) {
      badgeBg = amber.withOpacity(0.15);
      badgeFg = amber;
      badgeLabel = 'Verifying';
      badgeIcon = Icons.hourglass_top_rounded;
    } else {
      badgeBg = Colors.red.withOpacity(0.15);
      badgeFg = Colors.red;
      badgeLabel = 'Pending';
      badgeIcon = Icons.error_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentMonthLabel,
                  style: const TextStyle(color: blue, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeFg, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      badgeLabel,
                      style: TextStyle(color: badgeFg, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'LKR ${amount.toInt()}',
            style: const TextStyle(
              color: navy,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monthly Transport Fee',
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

  Widget _buildUploadSection(String receiptUrl) {
    final hasReceipt = receiptUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasReceipt) _buildReceiptSection(receiptUrl, isPaid: false),
        if (!hasReceipt)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: amber.withOpacity(0.8), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Fee is due for this month. Please transfer the amount and upload the bank slip, OR directly hand over the cash to your driver.',
                    style: TextStyle(color: navy.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _pickAndUploadSlip,
          icon: _isUploading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(hasReceipt ? Icons.cloud_upload_rounded : Icons.upload_file_rounded, size: 22),
          label: Text(
            _isUploading ? 'Uploading...' : (hasReceipt ? 'Re-Upload Slip' : 'Upload Bank Slip'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptSection(String url, {required bool isPaid}) {
    if (url.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: isPaid ? 0 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: blue.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Uploaded Slip',
                  style: TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (isPaid)
                Icon(Icons.verified_rounded, color: teal, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _viewReceiptImage(url),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: blue.withOpacity(0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('View Slip Image', style: TextStyle(color: blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: blue.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.money_off_csred_rounded, color: blue.withOpacity(0.3), size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: navy.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}