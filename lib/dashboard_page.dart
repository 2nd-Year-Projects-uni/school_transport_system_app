import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_tab.dart';
import 'd_info_child.dart';
import 'c_home_page.dart';
import 'driver_tracking_map.dart';
import 'dart:async';
import 'services/notification_service.dart';

class DashboardPage extends StatefulWidget {
  final String childId;
  final String childName;

  const DashboardPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color navy = Color(0xFF001F3F);
  static const Color teal = Color(0xFF00B894);

  int _currentIndex = 0;
  StreamSubscription<QuerySnapshot>? _noticesSubscription;
  bool _isFirstLoad = true;
  final Set<String> _seenNoticeIds = {};

  late final List<Widget> _pages;
  final List<String> _tabLabels = const [
    'Home',
    'Map',
    'Attendance',
    'Notices',
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeTab(
        childId: widget.childId, 
        childName: widget.childName,
        onNavigateToMap: () {
          setState(() {
            _currentIndex = 1;
          });
        },
      ),
      MapTab(childId: widget.childId, childName: widget.childName),
      AttendanceTab(childId: widget.childId, childName: widget.childName),
      NoticesTab(childId: widget.childId, childName: widget.childName),
    ];

    _listenToNewNotices();
  }

  Future<void> _listenToNewNotices() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Children').doc(widget.childId).get();
      final vanId = doc.data()?['vanId']?.toString() ?? '';
      if (vanId.isEmpty) return;

      _noticesSubscription = FirebaseFirestore.instance
          .collection('d_notices')
          .where('vanId', isEqualTo: vanId)
          .snapshots()
          .listen((snapshot) {
            
            if (_isFirstLoad) {
              for (var doc in snapshot.docs) {
                _seenNoticeIds.add(doc.id);
              }
              _isFirstLoad = false;
              return;
            }

            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                if (!_seenNoticeIds.contains(change.doc.id)) {
                  _seenNoticeIds.add(change.doc.id);
                  final data = change.doc.data();
                  if (data != null) {
                    final message = data['message'] ?? 'You have a new notice.';
                    NotificationService.instance.showNoticeNotification(
                      id: change.doc.id.hashCode & 0x7FFFFFFF,
                      title: 'New Notice from Driver',
                      body: message.toString(),
                    );
                  }
                }
              }
            }
          });
    } catch (e) {
      debugPrint('Error listening to notices: $e');
    }
  }

  @override
  void dispose() {
    _noticesSubscription?.cancel();
    super.dispose();
  }

  void _onMenuSelected(String value) {
    if (value == 'vehicle_info') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverInfoPage(
            childId: widget.childId,
            childName: widget.childName,
          ),
        ),
      );
      return;
    }


    if (value == 'logout') {
      // Redirect to root/login upon logging out.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _tabLabels[_currentIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0x22001F3F)),
              ),
              elevation: 12,
              offset: const Offset(0, 60),
              onSelected: _onMenuSelected,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'vehicle_info',
                  child: Row(
                    children: [
                      Icon(Icons.directions_bus_rounded, color: navy, size: 22),
                      SizedBox(width: 12),
                      Text('Vehicle Info', style: TextStyle(color: navy, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Color(0xFFD62828), size: 22),
                      SizedBox(width: 12),
                      Text('Sign Out', style: TextStyle(color: Color(0xFFD62828), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: const Color(0xFFF4F8FD),
                  indicatorColor: teal.withValues(alpha: 0.18),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      color: selected
                          ? const Color(0xFF008B6F)
                          : navy.withValues(alpha: 0.62),
                      size: selected ? 24 : 22,
                    );
                  }),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      color: selected
                          ? const Color(0xFF008B6F)
                          : navy.withValues(alpha: 0.62),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    );
                  }),
                ),
                child: NavigationBar(
                  height: 66,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _currentIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map_rounded),
                      label: 'Map',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month_rounded),
                      label: 'Attendance',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_outlined),
                      selectedIcon: Icon(Icons.notifications_rounded),
                      label: 'Notices',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── MAP TAB ───────────────────────────────────────────────
class MapTab extends StatelessWidget {
  final String childId;
  final String childName;
  const MapTab({super.key, required this.childId, required this.childName});

  @override
  Widget build(BuildContext context) {
    return DriverTrackingMapPage(childId: childId, childName: childName);
  }
}

// ── NOTICES TAB ───────────────────────────────────────────
class NoticesTab extends StatefulWidget {
  final String childId;
  final String childName;
  const NoticesTab({super.key, required this.childId, required this.childName});

  @override
  State<NoticesTab> createState() => _NoticesTabState();
}

class _NoticesTabState extends State<NoticesTab> {
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);

  String _vanId = '';

  @override
  void initState() {
    super.initState();
    _fetchVanId();
  }

  Future<void> _fetchVanId() async {
    final doc = await FirebaseFirestore.instance
        .collection('Children')
        .doc(widget.childId)
        .get();
    if (mounted) {
      setState(() {
        _vanId = doc.data()?['vanId']?.toString() ?? '';
      });
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = TimeOfDay.fromDateTime(dt);
      final period = h.period == DayPeriod.am ? 'AM' : 'PM';
      final hour = h.hourOfPeriod == 0 ? 12 : h.hourOfPeriod;
      final min = h.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$min $period';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F8FC),
      child: _vanId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('d_notices')
                  .where('vanId', isEqualTo: _vanId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: navy.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'No notices from your driver yet.',
                          style: TextStyle(color: navy.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                // Sort newest first
                final sorted = docs.toList()
                  ..sort((a, b) {
                    final tA = (a.data() as Map)['timestamp'] as Timestamp?;
                    final tB = (b.data() as Map)['timestamp'] as Timestamp?;
                    if (tA == null) return 1;
                    if (tB == null) return -1;
                    return tB.compareTo(tA);
                  });

                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = sorted[index].data() as Map<String, dynamic>;
                    final message = data['message']?.toString() ?? '';
                    final ts = data['timestamp'] as Timestamp?;
                    final timeStr = _formatTimestamp(ts);

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: index == 0 ? teal.withOpacity(0.3) : navy.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.05),
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
                              color: index == 0 ? teal.withOpacity(0.1) : const Color(0xFFF5F8FC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.campaign_rounded,
                              color: index == 0 ? teal : blue,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Driver Notice',
                                      style: TextStyle(
                                        color: navy,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: navy.withOpacity(0.45),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  message,
                                  style: TextStyle(
                                    color: navy.withOpacity(0.8),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
