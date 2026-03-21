import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'd_info_child.dart';

class HomeTab extends StatefulWidget {
  final String childId;
  final String childName;
  final VoidCallback onNavigateToMap;

  const HomeTab({
    super.key, 
    required this.childId, 
    required this.childName,
    required this.onNavigateToMap,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const Color navy = Color(0xFF001F3F);
  static const Color teal = Color(0xFF00B894);
  static const Color blue = Color(0xFF005792);

  bool _isLoading = true;
  String _vanId = '';
  
  // Real-time states (to be connected fully soon)
  bool _morningAttendance = true;
  bool _afternoonAttendance = true;

  @override
  void initState() {
    super.initState();
    _fetchBasicData();
  }

  Future<void> _fetchBasicData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Children').doc(widget.childId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _vanId = data['vanId']?.toString() ?? '';
        
        final rawAbsent = data['absentSlots'] is Map ? data['absentSlots'] as Map : {};
        final rawOverrides = data['attendanceOverrides'] is Map ? data['attendanceOverrides'] as Map : {};
        DateTime now = DateTime.now();
        String dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        String weekdayKey = now.weekday.toString();
        
        bool defaultMorning = true;
        bool defaultAfternoon = true;

        if (rawAbsent.containsKey(weekdayKey) && rawAbsent[weekdayKey] is Map) {
          final slotDict = rawAbsent[weekdayKey] as Map;
          defaultMorning = !(slotDict['morning'] == true);
          defaultAfternoon = !(slotDict['afternoon'] == true);
        }
        
        if (rawOverrides.containsKey(dateKey) && rawOverrides[dateKey] is Map) {
          final overrideDict = rawOverrides[dateKey] as Map;
          _morningAttendance = overrideDict['morning'] != false;
          _afternoonAttendance = overrideDict['afternoon'] != false;
        } else {
          _morningAttendance = defaultMorning;
          _afternoonAttendance = defaultAfternoon;
        }
      }
    } catch (e) {
      debugPrint('HomeTab fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: navy));
    }
    
    return RefreshIndicator(
      onRefresh: _fetchBasicData,
      color: teal,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildLiveTripCard(),
          const SizedBox(height: 24),
          _buildAttendanceGlance(),
          const SizedBox(height: 24),
          _buildQuickActions(context),
          const SizedBox(height: 24),
          _buildRecentNoticeCard(),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: teal.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: teal.withOpacity(0.3)),
          ),
          child: const Center(
            child: Icon(Icons.face_retouching_natural_rounded, color: teal, size: 32),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Day,',
                style: TextStyle(
                  color: navy.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.childName,
                style: const TextStyle(
                  color: navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTripCard() {
    if (_vanId.isEmpty) {
      return _buildStaticTripCard(
        title: 'Trip Status',
        status: 'Not Assigned',
        subtitle: 'Please contact the school office.',
      );
    }

    // Using the same database URL as LocationService for consistency
    const String databaseUrl =
        'https://school-transport-system-6eb9f-default-rtdb.asia-southeast1.firebasedatabase.app';
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseUrl,
    );

    return StreamBuilder(
      stream: database.ref('liveTracking/$_vanId').onValue,
      builder: (context, snapshot) {
        String tripTitle = 'Morning Trip';
        String statusText = 'Waiting to Start';
        String subtitleText = 'The van hasn\'t started the trip yet.';
        bool isLive = false;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          final journeyStatus = data['journeyStatus']?.toString() ?? 'waiting';
          final journeyMode = data['journeyMode']?.toString() ?? 'morning';

          tripTitle = journeyMode == 'morning' ? 'Morning Trip' : 'Afternoon Trip';
          isLive = journeyStatus == 'in_progress';

          if (isLive) {
            statusText = 'On the Way';
            subtitleText = 'The van is currently in transit.';
          } else if (journeyStatus == 'ended') {
            statusText = 'Trip Completed';
            subtitleText = 'The van has finished the journey.';
          } else if (journeyStatus == 'paused') {
            statusText = 'Trip Paused';
            subtitleText = 'Live tracking is currently paused.';
          }
        }

        return _buildStaticTripCard(
          title: tripTitle,
          status: statusText,
          subtitle: subtitleText,
          isLive: isLive,
        );
      },
    );
  }

  Widget _buildStaticTripCard({
    required String title,
    required String status,
    required String subtitle,
    bool isLive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navy, Color(0xFF003366)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.directions_bus_rounded,
              size: 140,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: teal.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLive ? Icons.sensors : Icons.trip_origin, 
                            color: teal, 
                            size: 12
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLive ? 'LIVE NOW' : 'TRIP STATUS',
                            style: const TextStyle(
                              color: teal,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onNavigateToMap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: navy,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.map_rounded, size: 20),
                        label: const Text(
                          'View on Map',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTodayAttendance(String slot, bool currentStatus) async {
    // Optimistic UI update
    setState(() {
      if (slot == 'morning') {
        _morningAttendance = !currentStatus;
      } else {
        _afternoonAttendance = !currentStatus;
      }
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('Children').doc(widget.childId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final rawOverrides = data['attendanceOverrides'] is Map ? data['attendanceOverrides'] as Map : {};
      
      final Map<String, dynamic> overrides = Map<String, dynamic>.from(rawOverrides);

      DateTime now = DateTime.now();
      String dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      bool morningStat = slot == 'morning' ? !currentStatus : _morningAttendance;
      bool afternoonStat = slot == 'afternoon' ? !currentStatus : _afternoonAttendance;

      overrides[dateKey] = {
        'morning': morningStat,
        'afternoon': afternoonStat,
      };

      await docRef.update({'attendanceOverrides': overrides});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${slot == 'morning' ? 'Morning' : 'Afternoon'} attendance updated!'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to toggle attendance: $e');
      // Revert if failed
      if (mounted) {
        setState(() {
          if (slot == 'morning') {
            _morningAttendance = currentStatus;
          } else {
            _afternoonAttendance = currentStatus;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update attendance. Please try again.'),
          ),
        );
      }
    }
  }

  Widget _buildAttendanceGlance() {
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    if (isWeekend) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Attendance',
            style: TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: navy.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: navy.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                Icon(Icons.weekend_rounded, color: blue.withOpacity(0.7), size: 32),
                const SizedBox(height: 8),
                const Text(
                  'It\'s the Weekend!',
                  style: TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enjoy your time off. See you on Monday.',
                  style: TextStyle(
                    color: navy.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today\'s Attendance',
              style: TextStyle(
                color: navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Edit in Calendar',
              style: TextStyle(
                color: blue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAttendancePill(
                'Morning', 
                _morningAttendance,
                () => _toggleTodayAttendance('morning', _morningAttendance),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAttendancePill(
                'Afternoon', 
                _afternoonAttendance,
                () => _toggleTodayAttendance('afternoon', _afternoonAttendance),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttendancePill(String slot, bool present, VoidCallback onTap) {
    final color = present ? teal : Colors.red;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            present ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot,
                style: TextStyle(
                  color: navy.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                present ? 'Present' : 'Absent',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionItem(
              context,
              icon: Icons.directions_bus_rounded,
              label: 'Vehicle Info',
              color: blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverInfoPage(
                      childId: widget.childId,
                      childName: widget.childName,
                    ),
                  ),
                );
              },
            ),
            _buildActionItem(
              context,
              icon: Icons.payments_rounded,
              label: 'Fee Status',
              color: const Color(0xFFF39C12),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fee Module coming soon!')),
                );
              },
            ),
            _buildActionItem(
              context,
              icon: Icons.medical_services_rounded,
              label: 'Leave Note',
              color: const Color(0xFF9B59B6),
              onTap: () => _showLeaveNoteSheet(context),
            ),
          ],
        ),
      ],
    );
  }

  void _showLeaveNoteSheet(BuildContext outerContext) {
    if (_vanId.isEmpty) {
      ScaffoldMessenger.of(outerContext).showSnackBar(
        const SnackBar(content: Text('Your child is not assigned to a vehicle yet.')),
      );
      return;
    }

    final TextEditingController noteController = TextEditingController();
    final List<String> quickNotes = [
      "Sick today, not coming.",
      "Uncle will pick up instead.",
      "Leaving early today.",
      "Please drop at main gate."
    ];

    bool isSending = false;

    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {

            Future<void> sendNote() async {
              final text = noteController.text.trim();
              if (text.isEmpty) return;

              setSheetState(() => isSending = true);
              try {
                DateTime now = DateTime.now();
                String dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                await FirebaseFirestore.instance.collection('notices').add({
                  'vanId': _vanId,
                  'childId': widget.childId,
                  'childName': widget.childName,
                  'sender': 'parent',
                  'message': text,
                  'dateKey': dateString,
                  'timestamp': FieldValue.serverTimestamp(),
                  'isRead': false,
                });

                if (outerContext.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(
                      content: Text('Message sent to the driver successfully!'),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Send note error: $e');
                if (outerContext.mounted) {
                  setSheetState(() => isSending = false);
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send note: ${e.toString().split(']').last.trim()}'),
                    ),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: navy.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: navy.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Leave a Note',
                            style: TextStyle(
                              color: navy,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: navy.withOpacity(0.04),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: navy, size: 22),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Send a direct message to the driver. They will receive it on their dashboard instantly.',
                        style: TextStyle(color: navy.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'QUICK SELECT',
                        style: TextStyle(color: navy.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: quickNotes.map((note) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ActionChip(
                                label: Text(note, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9B59B6))),
                                backgroundColor: const Color(0xFF9B59B6).withOpacity(0.08),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF9B59B6).withOpacity(0.2))),
                                onPressed: () {
                                  noteController.text = note;
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: noteController,
                        maxLines: 4,
                        minLines: 3,
                        style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Type your custom message...',
                          hintStyle: TextStyle(color: navy.withOpacity(0.4), fontSize: 15),
                          filled: true,
                          fillColor: const Color(0xFFF5F8FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: const Color(0xFF9B59B6).withOpacity(0.5), width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(20),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: isSending ? null : sendNote,
                          icon: isSending 
                            ? const SizedBox.shrink()
                            : const Icon(Icons.send_rounded, size: 20),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B59B6),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0xFF9B59B6).withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          label: isSending
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('Send Note to Driver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionItem(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: navy.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: navy.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNoticeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Notice',
          style: TextStyle(
            color: navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: navy.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: navy.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No new notices',
                      style: TextStyle(
                        color: navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You will see the latest updates from the driver or admin here.',
                      style: TextStyle(
                        color: navy.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
