import 'package:flutter/material.dart';
import 'attendance_tab.dart';
import 'd_info_child.dart';
import 'child_settings.dart';
import 'c_home_page.dart';
import 'driver_tracking_map.dart';

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
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);

  int _currentIndex = 0;

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
      HomeTab(childId: widget.childId, childName: widget.childName),
      MapTab(childId: widget.childId, childName: widget.childName),
      AttendanceTab(childId: widget.childId, childName: widget.childName),
      NoticesTab(childId: widget.childId, childName: widget.childName),
    ];
  }

  void _onMenuSelected(String value) {
    if (value == 'driver_info') {
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

    if (value == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChildSettingsPage(
            childId: widget.childId,
            childName: widget.childName,
          ),
        ),
      );
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _onMenuSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'driver_info',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: Color(0xFF001F3F)),
                    SizedBox(width: 10),
                    Text('Driver Info'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: Color(0xFF001F3F)),
                    SizedBox(width: 10),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
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
class NoticesTab extends StatelessWidget {
  final String childId;
  final String childName;
  const NoticesTab({super.key, required this.childId, required this.childName});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Notices", style: TextStyle(fontSize: 16)));
  }
}
