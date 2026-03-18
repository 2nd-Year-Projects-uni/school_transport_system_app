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

  static const List<String> _weekdayNames = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  // Recurring absent slots: e.g. {'1': {'morning': true, 'afternoon': false}}
  // true = absent
  Map<String, Map<String, bool>> _absentSlots = <String, Map<String, bool>>{};

  // Overrides: e.g. {'2026-03-13': {'morning': false, 'afternoon': true}}
  // true = attending
  Map<String, Map<String, bool>> _overrides = <String, Map<String, bool>>{};

  bool _loading = true;

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

    // Load overrides and clean invalid keys to avoid conflicts.
    final rawOverrides = Map<String, dynamic>.from(
      data['attendanceOverrides'] ?? {},
    );
    final cleanedOverrides = <String, Map<String, bool>>{};
    var removedInvalidOverride = false;
    rawOverrides.forEach((key, value) {
      final parsedDate = _tryParseDateKey(key);
      if (parsedDate == null || value is! Map) {
        removedInvalidOverride = true;
        return;
      }

      final map = Map<String, dynamic>.from(value);
      cleanedOverrides[_dateKey(parsedDate)] = {
        'morning': map['morning'] as bool? ?? true,
        'afternoon': map['afternoon'] as bool? ?? true,
      };
    });

    setState(() {
      _absentSlots = loadedAbsent;
      _overrides = cleanedOverrides;
      _loading = false;
    });

    if (removedInvalidOverride) {
      await FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId)
          .update({'attendanceOverrides': cleanedOverrides});
    }
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

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _dateKey(DateTime date) {
    final normalized = _dateOnly(date);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }

  DateTime? _tryParseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  bool _isToday(DateTime date) {
    final now = _dateOnly(DateTime.now());
    final normalized = _dateOnly(date);
    return normalized.year == now.year &&
        normalized.month == now.month &&
        normalized.day == now.day;
  }

  bool _defaultAttending(DateTime date, String slot) {
    final weekdayKey = _dateOnly(date).weekday.toString();
    final isAbsent = _absentSlots[weekdayKey]?[slot] ?? false;
    return !isAbsent;
  }

  bool _hasOverride(DateTime date) {
    return _overrides.containsKey(_dateKey(date));
  }

  Map<String, bool> _effectiveSlotsForDate(DateTime date) {
    return {
      'morning': _isAttendingSlot(date, 'morning'),
      'afternoon': _isAttendingSlot(date, 'afternoon'),
    };
  }

  String _statusLabel(bool morning, bool afternoon) {
    if (morning && afternoon) return 'Coming';
    if (!morning && !afternoon) return 'Not coming';
    return 'Partial';
  }

  Color _statusColor(bool morning, bool afternoon) {
    if (morning && afternoon) return teal;
    if (!morning && !afternoon) return Colors.red;
    return Colors.orange;
  }

  String _formatDate(DateTime date) {
    final normalized = _dateOnly(date);
    return '${normalized.day} ${_monthNames[normalized.month - 1]}';
  }

  DateTime _weekStartMonday(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  Future<void> _setSlotAttendance(
    DateTime date,
    String slot,
    bool isAttending,
  ) async {
    final key = _dateKey(date);
    final baseMorning = _defaultAttending(date, 'morning');
    final baseAfternoon = _defaultAttending(date, 'afternoon');

    final current = _overrides[key] ?? _effectiveSlotsForDate(date);
    final updated = {
      'morning': current['morning'] ?? true,
      'afternoon': current['afternoon'] ?? true,
      slot: isAttending,
    };

    final matchesBase =
        updated['morning'] == baseMorning &&
        updated['afternoon'] == baseAfternoon;

    setState(() {
      if (matchesBase) {
        _overrides.remove(key);
      } else {
        _overrides[key] = {
          'morning': updated['morning'] ?? true,
          'afternoon': updated['afternoon'] ?? true,
        };
      }
    });

    await _saveToFirestore();
  }

  Future<void> _clearDateOverride(DateTime date) async {
    final key = _dateKey(date);
    if (!_overrides.containsKey(key)) return;
    setState(() {
      _overrides.remove(key);
    });
    await _saveToFirestore();
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: navy.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineSlotPill({
    required String label,
    required bool attending,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final activeColor = attending
        ? const Color(0xFF0A8E72)
        : const Color(0xFF8A4D53);
    final background = attending
        ? const Color(0x0D00B894)
        : const Color(0x0DE67D89);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? background : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? activeColor.withValues(alpha: 0.22)
                : const Color(0x22001F3F),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              attending ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 13,
              color: enabled ? activeColor : const Color(0xFF9BA7B5),
            ),
            const SizedBox(width: 6),
            Text(
              '$label · ${attending ? 'On' : 'Off'}',
              style: TextStyle(
                color: enabled ? activeColor : const Color(0xFF9BA7B5),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekTab() {
    final today = _dateOnly(DateTime.now());
    final monday = _weekStartMonday(today);
    final weekDates = List.generate(5, (i) => monday.add(Duration(days: i)));

    var fullDays = 0;
    var absentDays = 0;
    var partialDays = 0;
    for (final date in weekDates) {
      final slots = _effectiveSlotsForDate(date);
      final morning = slots['morning'] ?? true;
      final afternoon = slots['afternoon'] ?? true;
      if (morning && afternoon) {
        fullDays++;
      } else if (!morning && !afternoon) {
        absentDays++;
      } else {
        partialDays++;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7FBFF), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x29005792)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x14001F3F),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Attendance Planner',
                  style: TextStyle(
                    color: navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.childName} • Mon to Fri',
                  style: TextStyle(
                    color: navy.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryChip(
                        label: 'Coming',
                        value: '$fullDays',
                        color: teal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryChip(
                        label: 'Partial',
                        value: '$partialDays',
                        color: blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryChip(
                        label: 'Absent',
                        value: '$absentDays',
                        color: navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x16001F3F)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x14001F3F),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: List.generate(weekDates.length, (index) {
                final date = weekDates[index];
                final isPastDay = date.isBefore(today);
                final slots = _effectiveSlotsForDate(date);
                final morning = slots['morning'] ?? true;
                final afternoon = slots['afternoon'] ?? true;
                final color = _statusColor(morning, afternoon);
                final hasOverride = _hasOverride(date);

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      color: isPastDay
                          ? const Color(0xFFF5F6F8)
                          : (_isToday(date)
                                ? const Color(0xFFF8FBFF)
                                : Colors.transparent),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_weekdayNames[date.weekday]} • ${_formatDate(date)}',
                                  style: TextStyle(
                                    color: isPastDay
                                        ? const Color(0xFF93A0AF)
                                        : navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (isPastDay)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x12001F3F),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Closed',
                                    style: TextStyle(
                                      color: Color(0xFF8E9AA8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              if (_isToday(date))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x0F005792),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Today',
                                    style: TextStyle(
                                      color: blue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isPastDay
                                      ? const Color(0x14001F3F)
                                      : color.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _statusLabel(morning, afternoon),
                                  style: TextStyle(
                                    color: isPastDay
                                        ? const Color(0xFF8E9AA8)
                                        : color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (hasOverride) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x0F005792),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Manual',
                                    style: TextStyle(
                                      color: blue.withValues(alpha: 0.88),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (hasOverride)
                                TextButton.icon(
                                  onPressed: isPastDay
                                      ? null
                                      : () => _clearDateOverride(date),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: navy.withValues(
                                      alpha: 0.58,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 13,
                                  ),
                                  label: const Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildInlineSlotPill(
                                label: 'Morning',
                                attending: morning,
                                enabled: !isPastDay,
                                onTap: () => _setSlotAttendance(
                                  date,
                                  'morning',
                                  !morning,
                                ),
                              ),
                              const SizedBox(width: 22),
                              _buildInlineSlotPill(
                                label: 'Afternoon',
                                attending: afternoon,
                                enabled: !isPastDay,
                                onTap: () => _setSlotAttendance(
                                  date,
                                  'afternoon',
                                  !afternoon,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (index != weekDates.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: navy.withValues(alpha: 0.08),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Is attending for a specific slot today
  bool _isAttendingSlot(DateTime date, String slot) {
    final key = _dateKey(date);
    if (_overrides.containsKey(key)) {
      return _overrides[key]![slot] ?? true;
    }
    return _defaultAttending(date, slot);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: teal));
    }

    return _buildWeekTab();
  }
}
