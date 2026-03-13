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

  static const List<String> _weekdayNames = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  // Recurring absent slots: e.g. {'1': {'morning': true, 'afternoon': false}}
  // true = absent
  Map<String, Map<String, bool>> _absentSlots = {};

  // Overrides: e.g. {'2026-03-13': {'morning': false, 'afternoon': true}}
  // true = attending
  Map<String, Map<String, bool>> _overrides = {};

  bool _loading = true;

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

    // Load absent slots
    final rawAbsent = Map<String, dynamic>.from(data['absentSlots'] ?? {});
    final loadedAbsent = <String, Map<String, bool>>{};
    rawAbsent.forEach((key, value) {
      final map = Map<String, dynamic>.from(value);
      loadedAbsent[key] = {
        'morning': map['morning'] as bool? ?? false,
        'afternoon': map['afternoon'] as bool? ?? false,
      };
    });

    // Load overrides and clean up old ones
    final rawOverrides = Map<String, dynamic>.from(data['attendanceOverrides'] ?? {});
    final cleanedOverrides = <String, Map<String, bool>>{};
    rawOverrides.forEach((key, value) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        if (!date.isBefore(DateTime(_today.year, _today.month, _today.day))) {
          final map = Map<String, dynamic>.from(value);
          cleanedOverrides[key] = {
            'morning': map['morning'] as bool? ?? true,
            'afternoon': map['afternoon'] as bool? ?? true,
          };
        }
      }
    });

    setState(() {
      _absentSlots = loadedAbsent;
      _overrides = cleanedOverrides;
      _loading = false;
    });
  }

  Future<void> _saveToFirestore() async {
    await FirebaseFirestore.instance
        .collection('Children')
        .doc(widget.childId)
        .update({
      'absentSlots': _absentSlots,
      'attendanceOverrides': _overrides,
    });
  }

  // Is attending for a specific slot today
  bool _isAttendingSlot(DateTime date, String slot) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (_overrides.containsKey(key)) {
      return _overrides[key]![slot] ?? true;
    }
    final weekdayKey = date.weekday.toString();
    if (_absentSlots.containsKey(weekdayKey)) {
      return !(_absentSlots[weekdayKey]![slot] ?? false);
    }
    return true;
  }

  // Toggle today's slot manually
  Future<void> _toggleTodaySlot(String slot) async {
    final current = _isAttendingSlot(_today, slot);
    setState(() {
      _overrides[_todayKey] ??= {
        'morning': _isAttendingSlot(_today, 'morning'),
        'afternoon': _isAttendingSlot(_today, 'afternoon'),
      };
      _overrides[_todayKey]![slot] = !current;
    });
    await _saveToFirestore();
  }

  // Clear today's override for a slot
  Future<void> _clearTodayOverride() async {
    setState(() {
      _overrides.remove(_todayKey);
    });
    await _saveToFirestore();
  }

  // Toggle a recurring absent slot
  Future<void> _toggleRecurringSlot(int weekday, String slot) async {
    final key = weekday.toString();
    setState(() {
      _absentSlots[key] ??= {'morning': false, 'afternoon': false};
      _absentSlots[key]![slot] = !(_absentSlots[key]![slot] ?? false);

      // If both are false, remove the entry entirely
      if (_absentSlots[key]!['morning'] == false &&
          _absentSlots[key]!['afternoon'] == false) {
        _absentSlots.remove(key);
      }
    });
    await _saveToFirestore();
  }

  Widget _slotToggle({
    required String label,
    required bool value,
    required VoidCallback onToggle,
    bool compact = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: value ? teal : Colors.red,
          ),
        ),
        const SizedBox(width: 4),
        Transform.scale(
          scale: compact ? 0.8 : 0.9,
          child: Switch(
            value: value,
            onChanged: (_) => onToggle(),
            activeColor: teal,
            inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: teal));
    }

    final morningToday = _isAttendingSlot(_today, 'morning');
    final afternoonToday = _isAttendingSlot(_today, 'afternoon');
    final hasOverrideToday = _overrides.containsKey(_todayKey);
    final dayName = _weekdayNames[_today.weekday];

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
              color: (morningToday && afternoonToday)
                  ? teal.withValues(alpha: 0.08)
                  : (!morningToday && !afternoonToday)
                      ? Colors.red.withValues(alpha: 0.07)
                      : Colors.orange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (morningToday && afternoonToday)
                    ? teal
                    : (!morningToday && !afternoonToday)
                        ? Colors.red
                        : Colors.orange,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      (!morningToday && !afternoonToday)
                          ? Icons.do_not_disturb_alt
                          : Icons.directions_bus,
                      color: (morningToday && afternoonToday)
                          ? teal
                          : (!morningToday && !afternoonToday)
                              ? Colors.red
                              : Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      (!morningToday && !afternoonToday)
                          ? 'Not coming today'
                          : (morningToday && afternoonToday)
                              ? 'Coming today'
                              : 'Partial attendance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: (morningToday && afternoonToday)
                            ? teal
                            : (!morningToday && !afternoonToday)
                                ? Colors.red
                                : Colors.orange,
                      ),
                    ),
                  ],
                ),
                if (hasOverrideToday)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Manually set for today',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _slotToggle(
                      label: ' Morning',
                      value: morningToday,
                      onToggle: () => _toggleTodaySlot('morning'),
                    ),
                    _slotToggle(
                      label: 'Afternoon',
                      value: afternoonToday,
                      onToggle: () => _toggleTodaySlot('afternoon'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (hasOverrideToday) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearTodayOverride,
                child: Text(
                  'Revert to default for $dayName',
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
            'Child will not come on these slots every week by default.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          ...List.generate(5, (i) {
            final weekday = i + 1;
            final key = weekday.toString();
            final morningAbsent = _absentSlots[key]?['morning'] ?? false;
            final afternoonAbsent = _absentSlots[key]?['afternoon'] ?? false;
            final anyAbsent = morningAbsent || afternoonAbsent;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: anyAbsent
                      ? Colors.red.withValues(alpha: 0.06)
                      : Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: anyAbsent
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        _weekdayNames[weekday],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: anyAbsent ? Colors.red : navy,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _slotToggle(
                      label: 'morning',
                      value: !morningAbsent,
                      onToggle: () => _toggleRecurringSlot(weekday, 'morning'),
                      compact: true,
                    ),
                    const SizedBox(width: 12),
                    _slotToggle(
                      label: 'afternoon',
                      value: !afternoonAbsent,
                      onToggle: () => _toggleRecurringSlot(weekday, 'afternoon'),
                      compact: true,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}