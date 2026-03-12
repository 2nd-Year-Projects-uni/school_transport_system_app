import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceTab extends StatefulWidget {
  final String childId;
  final String childName;

  const AttendanceTab({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  static const Color teal = Color(0xFF00B894);
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);

  // weekday numbers: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
  static const List<String> _weekdayNames = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  List<int> _absentDays = [];        // recurring absent weekdays
  Map<String, bool> _overrides = {}; // date string -> isAttending
  bool _loading = true;

  // Today's info
  final DateTime _today = DateTime.now();

  String get _todayKey =>
      '${_today.year}-${_today.month.toString().padLeft(2, '0')}-${_today.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('Children')
        .doc(widget.childId)
        .get();

    if (!mounted) return;

    final data = doc.data() ?? {};
    final List<dynamic> absent = data['absentWeekdays'] ?? [];
    final Map<String, dynamic> overrides =
        Map<String, dynamic>.from(data['attendanceOverrides'] ?? {});

    // Clean up overrides older than today
    final cleanedOverrides = <String, bool>{};
    overrides.forEach((key, value) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        if (!date.isBefore(DateTime(_today.year, _today.month, _today.day))) {
          cleanedOverrides[key] = value as bool;
        }
      }
    });

    setState(() {
      _absentDays = absent.map<int>((e) => e as int).toList();
      _overrides = cleanedOverrides;
      _loading = false;
    });
  }

  Future<void> _saveToFirestore() async {
    await FirebaseFirestore.instance
        .collection('Children')
        .doc(widget.childId)
        .update({
      'absentWeekdays': _absentDays,
      'attendanceOverrides': _overrides,
    });
  }

  // Is the child attending on a given date?
  bool _isAttending(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (_overrides.containsKey(key)) return _overrides[key]!;
    return !_absentDays.contains(date.weekday);
  }

  // Toggle today's attendance manually
  Future<void> _toggleToday() async {
    final current = _isAttending(_today);
    setState(() {
      _overrides[_todayKey] = !current;
    });
    await _saveToFirestore();
  }

  // Toggle a recurring absent weekday
  Future<void> _toggleRecurringDay(int weekday) async {
    setState(() {
      if (_absentDays.contains(weekday)) {
        _absentDays.remove(weekday);
      } else {
        _absentDays.add(weekday);
      }
    });
    await _saveToFirestore();
  }

  // Remove today's manual override (revert to default)
  Future<void> _clearTodayOverride() async {
    setState(() {
      _overrides.remove(_todayKey);
    });
    await _saveToFirestore();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: teal));
    }

    final todayAttending = _isAttending(_today);
    final hasOverrideToday = _overrides.containsKey(_todayKey);
    final dayName = _weekdayNames[_today.weekday];
    final isRecurringAbsent = _absentDays.contains(_today.weekday);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── TODAY'S ATTENDANCE ──────────────────────────
          const Text(
            "Today's Attendance",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: todayAttending
                  ? teal.withValues(alpha: 0.08)
                  : Colors.red.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: todayAttending ? teal : Colors.red,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  todayAttending
                      ? Icons.directions_bus
                      : Icons.do_not_disturb_alt,
                  color: todayAttending ? teal : Colors.red,
                  size: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todayAttending ? 'Coming today' : 'Not coming today',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: todayAttending ? teal : Colors.red,
                        ),
                      ),
                      if (isRecurringAbsent && !hasOverrideToday)
                        const Text(
                          'Recurring absent day',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (hasOverrideToday)
                        const Text(
                          'Manually set for today',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: todayAttending,
                  onChanged: (_) => _toggleToday(),
                  activeColor: teal,
                  inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),

          // Show "revert to default" only if there's a manual override today
          if (hasOverrideToday) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearTodayOverride,
                child: Text(
                  'Revert to default ($dayName is ${isRecurringAbsent ? "off" : "on"})',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── RECURRING ABSENT DAYS ───────────────────────
          const Text(
            'Recurring Absent Days',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Child will be marked absent on these days every week by default.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Mon–Sun toggles
          ...List.generate(5, (i) {
            final weekday = i + 1; // 1=Mon ... 7=Sun
            final isAbsent = _absentDays.contains(weekday);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: isAbsent
                      ? Colors.red.withValues(alpha: 0.06)
                      : Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAbsent
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    _weekdayNames[weekday],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isAbsent ? Colors.red : navy,
                    ),
                  ),
                  subtitle: Text(
                    isAbsent ? 'Absent every week' : 'Attending',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAbsent ? Colors.red : Colors.grey,
                    ),
                  ),
                  value: !isAbsent, // true = attending
                  onChanged: (_) => _toggleRecurringDay(weekday),
                  activeColor: teal,
                  inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                  dense: true,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}