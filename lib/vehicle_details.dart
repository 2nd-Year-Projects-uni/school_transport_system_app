import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';

class VehicleDetailsPage extends StatefulWidget {
  final String vanId;
  final Map<String, dynamic> vanData;
  final String childId;
  final String childName;

  const VehicleDetailsPage({
    super.key,
    required this.vanId,
    required this.vanData,
    required this.childId,
    required this.childName,
  });

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

// Backward-compatible alias for existing call sites.
typedef VanDetailsPage = VehicleDetailsPage;

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  static const Color teal = Color(0xFF00B894);
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);

  bool _linking = false;
  Map<String, String> _driverPhonesByUid = {};
  Map<String, String> _driverPhonesByName = {};

  @override
  void initState() {
    super.initState();
    _loadDriverPhones();
  }

  Future<void> _loadDriverPhones() async {
    final snapshotDrivers = (widget.vanData['drivers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((d) => Map<String, dynamic>.from(d))
        .toList();

    List<Map<String, dynamic>> drivers = snapshotDrivers;
    try {
      final liveVehicleDoc = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vanId)
          .get();
      final liveData = liveVehicleDoc.data();
      final liveDrivers = (liveData?['drivers'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
      if (liveDrivers.isNotEmpty) {
        drivers = liveDrivers;
      }
    } catch (_) {
      // Keep using snapshot drivers if live fetch fails.
    }

    final driverUids = drivers
        .map((d) => (d['uid'] ?? '').toString().trim())
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList();

    try {
      final resolvedByUid = <String, String>{};
      final resolvedByName = <String, String>{};

      if (driverUids.isNotEmpty) {
        final uidSnapshots = await Future.wait(
          driverUids.map(
            (uid) =>
                FirebaseFirestore.instance.collection('users').doc(uid).get(),
          ),
        );
        for (final doc in uidSnapshots) {
          final data = doc.data();
          final phone = (data?['phone'] ?? '').toString().trim();
          final name = (data?['name'] ?? '').toString().trim().toLowerCase();
          if (doc.id.isNotEmpty && phone.isNotEmpty) {
            resolvedByUid[doc.id] = phone;
          }
          if (name.isNotEmpty && phone.isNotEmpty) {
            resolvedByName[name] = phone;
          }
        }
      }

      // Fallback path when cached driver entries don't contain uid.
      final byVehicleSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('vehicleId', isEqualTo: widget.vanId)
          .get();

      for (final doc in byVehicleSnap.docs) {
        final data = doc.data();
        final phone = (data['phone'] ?? '').toString().trim();
        final name = (data['name'] ?? '').toString().trim().toLowerCase();
        if (doc.id.isNotEmpty && phone.isNotEmpty) {
          resolvedByUid.putIfAbsent(doc.id, () => phone);
        }
        if (name.isNotEmpty && phone.isNotEmpty) {
          resolvedByName.putIfAbsent(name, () => phone);
        }
      }

      if (!mounted) return;
      setState(() {
        _driverPhonesByUid = resolvedByUid;
        _driverPhonesByName = resolvedByName;
      });
    } catch (_) {
      // Fallback to any phone values included in vehicle data.
    }
  }

  String? _extractDriverPhone(Map<String, dynamic> driver) {
    const phoneKeys = [
      'phone',
      'phoneNumber',
      'mobile',
      'contactNumber',
      'contact',
    ];

    for (final key in phoneKeys) {
      final raw = driver[key]?.toString().trim() ?? '';
      if (raw.isNotEmpty) return raw;
    }
    return null;
  }

  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';
    final startsWithPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';
    return startsWithPlus ? '+$digitsOnly' : digitsOnly;
  }

  Future<void> _callDriver({
    required String uid,
    required String name,
    String? rawPhone,
  }) async {
    String normalized = _normalizePhone(rawPhone ?? '');

    // On-demand refresh in case contact data was not ready during initial build.
    if (normalized.isEmpty) {
      await _loadDriverPhones();
      normalized = _normalizePhone(
        _driverPhonesByUid[uid] ??
            _driverPhonesByName[name.toLowerCase()] ??
            rawPhone ??
            '',
      );
    }

    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone number is not available.')),
      );
      return;
    }

    try {
      final uri = Uri(scheme: 'tel', path: normalized);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  Future<void> _linkVehicle() async {
    setState(() => _linking = true);
    try {
      final code = widget.vanData['code'] as String? ?? '';
      final batch = FirebaseFirestore.instance.batch();

      // Write vehicle reference to child document.
      final childRef = FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId);
      batch.update(childRef, {'vanId': widget.vanId, 'code': code});

      // Add childId to vehicle linkedChildren array.
      final vanRef = FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vanId);
      batch.update(vanRef, {
        'linkedChildren': FieldValue.arrayUnion([widget.childId]),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle linked successfully!')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SelectChildPage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to link vehicle. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAFDFF), Color(0xFFEDF5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: blue.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.72),
            blurRadius: 10,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _detailChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: blue.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: blue.withValues(alpha: 0.86), size: 15),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: blue.withValues(alpha: 0.74),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<String> items,
    required Color accent,
    required String emptyText,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.30)),
                ),
                child: Icon(icon, color: accent, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    color: blue.withValues(alpha: 0.90),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                color: navy.withValues(alpha: 0.66),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _driverSlotCard({
    required int slot,
    required String name,
    required String uid,
    required String? phone,
  }) {
    final hasDriver = name.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: blue.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: teal.withValues(alpha: 0.28)),
            ),
            child: const Icon(Icons.person_outline, color: teal, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver $slot',
                  style: TextStyle(
                    color: blue.withValues(alpha: 0.76),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasDriver ? name : 'Not assigned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasDriver ? navy : navy.withValues(alpha: 0.60),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              if (!hasDriver) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No driver assigned yet.')),
                );
                return;
              }
              await _callDriver(uid: uid, name: name, rawPhone: phone);
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasDriver
                      ? [const Color(0xFFE7FBF5), const Color(0xFFD6F6EC)]
                      : [
                          Colors.grey.withValues(alpha: 0.15),
                          Colors.grey.withValues(alpha: 0.08),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasDriver
                      ? teal.withValues(alpha: 0.35)
                      : Colors.grey.withValues(alpha: 0.30),
                ),
              ),
              child: Icon(
                Icons.call_outlined,
                color: hasDriver
                    ? const Color(0xFF009A7A)
                    : Colors.grey.withValues(alpha: 0.75),
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.vanData;
    final registerNumber = data['registerNumber'] as String? ?? 'No number';
    final vehicleType = data['vehicleType'] as String? ?? 'Not specified';
    final condition = data['condition'] as String? ?? 'Not specified';
    final photoUrl = data['vehiclePhotoUrl'] as String?;

    final startingLocation = data['startingLocation'] as Map<String, dynamic>?;
    final startName = startingLocation?['name'] as String? ?? 'Not provided';

    final routePoints = (data['routePoints'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((point) => (point['name'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final schools = (data['schools'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((school) => (school['name'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final drivers = (data['drivers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((d) => Map<String, dynamic>.from(d))
        .toList();
    final assignedDriverSlots = drivers
        .map((driver) {
          final uid = (driver['uid'] ?? '').toString().trim();
          final name = (driver['name'] as String? ?? '').trim();
          if (name.isEmpty) return null;
          final phone =
              _driverPhonesByUid[uid] ??
              _driverPhonesByName[name.toLowerCase()] ??
              _extractDriverPhone(driver) ??
              '';
          return {'uid': uid, 'name': name, 'phone': phone};
        })
        .whereType<Map<String, String>>()
        .take(2)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF4FA),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: navy),
        title: Text(
          'Vehicle Details',
          style: TextStyle(
            color: navy.withValues(alpha: 0.96),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _glassCard(
              padding: const EdgeInsets.all(0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 210,
                      child: photoUrl != null
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: blue.withValues(alpha: 0.08),
                                child: Icon(
                                  Icons.directions_bus,
                                  size: 68,
                                  color: blue.withValues(alpha: 0.50),
                                ),
                              ),
                            )
                          : Container(
                              color: blue.withValues(alpha: 0.08),
                              child: Icon(
                                Icons.directions_bus,
                                size: 68,
                                color: blue.withValues(alpha: 0.50),
                              ),
                            ),
                    ),
                    Container(
                      height: 210,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            navy.withValues(alpha: 0.36),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Text(
                        registerNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            _glassCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _detailChip(
                    icon: Icons.directions_bus_outlined,
                    label: 'Type',
                    value: vehicleType,
                  ),
                  _detailChip(
                    icon: Icons.ac_unit_outlined,
                    label: 'Condition',
                    value: condition,
                  ),
                  _detailChip(
                    icon: Icons.location_on_outlined,
                    label: 'Starting',
                    value: startName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _sectionCard(
              icon: Icons.alt_route_rounded,
              title: 'Route Points',
              items: routePoints,
              accent: teal,
              emptyText: 'No route points added yet.',
            ),
            const SizedBox(height: 14),

            _sectionCard(
              icon: Icons.school_outlined,
              title: 'Schools',
              items: schools,
              accent: blue,
              emptyText: 'No schools added yet.',
            ),
            const SizedBox(height: 16),

            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: teal.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: teal.withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          color: teal,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Assigned Drivers',
                          style: TextStyle(
                            color: navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (assignedDriverSlots.isEmpty)
                    Text(
                      'No drivers assigned yet.',
                      style: TextStyle(
                        color: navy.withValues(alpha: 0.66),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    ...List.generate(assignedDriverSlots.length, (index) {
                      final driver = assignedDriverSlots[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == assignedDriverSlots.length - 1
                              ? 0
                              : 8,
                        ),
                        child: _driverSlotCard(
                          slot: index + 1,
                          name: driver['name']!,
                          uid: driver['uid']!,
                          phone: driver['phone'],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00355F), Color(0xFF005792)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _linking ? null : _linkVehicle,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _linking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                  label: Text(
                    _linking ? 'Linking Vehicle...' : 'Select This Vehicle',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
