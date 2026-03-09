import 'package:flutter/material.dart';
import 'attendance_tab.dart';
import 'd_info_child.dart';
import 'child_settings.dart';

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
  int _currentIndex = 0;

  late final List<Widget> _pages;

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

  @override
  Widget build(BuildContext context) {
    const Color teal = Color(0xFF00B894);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal,
        centerTitle: true,
        title: Text(
          widget.childName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) {
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
        } else if (value == 'settings') {
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
      },
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
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: teal,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed, // needed for 4+ items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Notices',
          ),
        ],
      ),
    );
  }
}

// ── HOME TAB ──────────────────────────────────────────────
class HomeTab extends StatelessWidget {
  final String childId;
  final String childName;
  const HomeTab({super.key, required this.childId, required this.childName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Home\n$childName",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16)),
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
    return const Center(child: Text("Map", style: TextStyle(fontSize: 16)));
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