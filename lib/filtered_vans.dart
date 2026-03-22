import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'van_details.dart';

class FilteredVansPage extends StatefulWidget {
  final String childId;
  final String childName;

  const FilteredVansPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<FilteredVansPage> createState() => _FilteredVansPageState();
}

class _FilteredVansPageState extends State<FilteredVansPage> {
  static const Color teal = Color(0xFF00B894);
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _filteredVans = [];

  // Child data
  String? _childSchool;
  double? _childLat;
  double? _childLng;

  static const double _proximityKm = 2.0;

  @override
  void initState() {
    super.initState();
    _loadAndFilter();
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371;
    final double dLat = _toRad(lat2 - lat1);
    final double dLng = _toRad(lng2 - lng1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  bool _isNearRoute(Map<String, dynamic> van) {
    if (_childLat == null || _childLng == null) return false;

    // Check starting location
    final start = van['startingLocation'] as Map<String, dynamic>?;
    if (start != null) {
      final lat = (start['latitude'] as num?)?.toDouble();
      final lng = (start['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        if (_haversineKm(_childLat!, _childLng!, lat, lng) <= _proximityKm) {
          return true;
        }
      }
    }

    // Check route points
    final routePoints = van['routePoints'] as List<dynamic>? ?? [];
    for (final point in routePoints) {
      final p = point as Map<String, dynamic>;
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        if (_haversineKm(_childLat!, _childLng!, lat, lng) <= _proximityKm) {
          return true;
        }
      }
    }
    return false;
  }

  bool _schoolMatches(Map<String, dynamic> van) {
    if (_childSchool == null || _childSchool!.isEmpty) return false;
    final schools = van['schools'] as List<dynamic>? ?? [];
    final childSchoolLower = _childSchool!.toLowerCase();
    for (final s in schools) {
      final schoolMap = s as Map<String, dynamic>;
      final name = (schoolMap['name'] as String? ?? '').toLowerCase();
      if (name.contains(childSchoolLower) ||
          childSchoolLower.contains(name)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadAndFilter() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load child data
      final childDoc = await FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId)
          .get();

      final childData = childDoc.data();
      if (childData == null) {
        setState(() {
          _error = 'Child data not found.';
          _loading = false;
        });
        return;
      }

      _childSchool = childData['school'] as String?;
      final pickup = childData['pickupLocation'] as GeoPoint?;
      _childLat = pickup?.latitude;
      _childLng = pickup?.longitude;

      // Load approved vehicles
      final vansSnap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('status', isEqualTo: true)
          .get();

      final filtered = vansSnap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((van) => _schoolMatches(van) && _isNearRoute(van))
          .toList();

      setState(() {
        _filteredVans = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: teal,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Vans for ${widget.childName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAndFilter,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: teal),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _filteredVans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_bus_outlined,
                              size: 72,
                              color: blue.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No vans found nearby',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: blue.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No approved vans match your\nschool and pickup location.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: blue.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _filteredVans.length,
                      itemBuilder: (context, index) {
                        final van = _filteredVans[index];
                        final startingLocation =
                            van['startingLocation'] as Map<String, dynamic>?;
                        final locationName =
                            startingLocation?['name'] as String? ?? '';
                        final vehicleType =
                            van['vehicleType'] as String? ?? '';
                        final condition =
                            van['condition'] as String? ?? '';
                        final code = van['code'] as String? ?? '';
                        final registerNumber =
                            van['registerNumber'] as String? ?? '';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VanDetailsPage(
                                    vanId: van['id'] as String,
                                    vanData: van,
                                    childId: widget.childId,
                                    childName: widget.childName,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: navy,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: navy.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: teal.withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.directions_bus,
                                      color: teal,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              registerNumber,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: teal.withValues(
                                                    alpha: 0.25),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                code,
                                                style: const TextStyle(
                                                  color: teal,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$vehicleType • $condition',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (locationName.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on_outlined,
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                size: 13,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  locationName,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white54,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}