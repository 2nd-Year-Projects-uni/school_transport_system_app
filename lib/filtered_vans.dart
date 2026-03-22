import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vehicle_details.dart';
import 'child_settings.dart';

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

class _FilteredVansPageState extends State<FilteredVansPage>
    with SingleTickerProviderStateMixin {
  static const Color teal = Color(0xFF00B894);
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _filteredVans = [];
  Set<String> _favoriteVehicleIds = <String>{};
  Set<String> _favoriteUpdatingIds = <String>{};
  bool _loadedFromCache = false;
  late final AnimationController _goodMatchPulseController;
  late final Animation<double> _goodMatchPulse;
  final TextEditingController _driverSearchController = TextEditingController();

  String? _childSchool;
  double? _childLat;
  double? _childLng;

  String get _childSchoolLabel {
    final value = _childSchool?.trim() ?? '';
    return value.isEmpty ? 'School not set' : value;
  }

  @override
  void initState() {
    super.initState();
    _goodMatchPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _goodMatchPulse = CurvedAnimation(
      parent: _goodMatchPulseController,
      curve: Curves.easeInOut,
    );
    _bootstrapData();
  }

  @override
  void dispose() {
    _driverSearchController.dispose();
    _goodMatchPulseController.dispose();
    super.dispose();
  }

  String get _cacheKey => 'filtered_vehicles_cache_${widget.childId}';

  Future<void> _bootstrapData() async {
    await _loadCachedResults();
    await _loadAndFilter(showLoading: _filteredVans.isEmpty);
  }

  Future<void> _loadCachedResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cachedVehicles = (decoded['vehicles'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (cachedVehicles.isEmpty) return;

      final favorites = (decoded['favoriteVehicleIds'] as List<dynamic>? ?? [])
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      if (!mounted) return;
      setState(() {
        _childSchool = decoded['childSchool'] as String?;
        _childLat = (decoded['childLat'] as num?)?.toDouble();
        _childLng = (decoded['childLng'] as num?)?.toDouble();
        _favoriteVehicleIds = favorites;
        _filteredVans = cachedVehicles;
        _loading = false;
        _loadedFromCache = true;
      });
    } catch (_) {
      // Ignore cache parse failures and continue with online load.
    }
  }

  Map<String, dynamic> _toCacheSafeVan(Map<String, dynamic> van) {
    final start = van['startingLocation'] as Map<String, dynamic>?;
    final route = van['routePoints'] as List<dynamic>? ?? [];
    final drivers = van['drivers'] as List<dynamic>? ?? [];

    return {
      'id': van['id'],
      'registerNumber': van['registerNumber'],
      'vehicleType': van['vehicleType'],
      'condition': van['condition'],
      '_nearestDistanceKm': (van['_nearestDistanceKm'] as num?)?.toDouble(),
      'startingLocation': {
        'name': start?['name'],
        'latitude': (start?['latitude'] as num?)?.toDouble(),
        'longitude': (start?['longitude'] as num?)?.toDouble(),
      },
      'routePoints': route.whereType<Map>().map((p) {
        return {
          'name': p['name'],
          'latitude': (p['latitude'] as num?)?.toDouble(),
          'longitude': (p['longitude'] as num?)?.toDouble(),
        };
      }).toList(),
      'drivers': drivers.whereType<Map>().map((d) {
        return {'uid': d['uid'], 'name': d['name']};
      }).toList(),
      'insuranceExpiryDate': van['insuranceExpiryDate'] is Timestamp
          ? (van['insuranceExpiryDate'] as Timestamp).toDate().toIso8601String()
          : van['insuranceExpiryDate']?.toString(),
      'status': van['status'],
      'schools': (van['schools'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (s) => {
              'name': s['name'],
              'latitude': (s['latitude'] as num?)?.toDouble(),
              'longitude': (s['longitude'] as num?)?.toDouble(),
            },
          )
          .toList(),
    };
  }

  Future<void> _saveCachedResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'childSchool': _childSchool,
        'childLat': _childLat,
        'childLng': _childLng,
        'favoriteVehicleIds': _favoriteVehicleIds.toList(),
        'vehicles': _filteredVans.map(_toCacheSafeVan).toList(),
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {
      // Cache failures should not block page usage.
    }
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371;
    final double dLat = _toRad(lat2 - lat1);
    final double dLng = _toRad(lng2 - lng1);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  double? _nearestRouteDistanceKm(Map<String, dynamic> van) {
    if (_childLat == null || _childLng == null) return null;

    final List<double> distances = [];

    final start = van['startingLocation'] as Map<String, dynamic>?;
    if (start != null) {
      final lat = (start['latitude'] as num?)?.toDouble();
      final lng = (start['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        distances.add(_haversineKm(_childLat!, _childLng!, lat, lng));
      }
    }

    final routePoints = van['routePoints'] as List<dynamic>? ?? [];
    for (final point in routePoints) {
      if (point is! Map<String, dynamic>) continue;
      final lat = (point['latitude'] as num?)?.toDouble();
      final lng = (point['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        distances.add(_haversineKm(_childLat!, _childLng!, lat, lng));
      }
    }

    if (distances.isEmpty) return null;
    return distances.reduce(min);
  }

  bool _schoolMatches(Map<String, dynamic> van) {
    if (_childSchool == null || _childSchool!.trim().isEmpty) return false;
    final schools = van['schools'] as List<dynamic>? ?? [];
    final childSchoolLower = _childSchool!.toLowerCase();

    for (final s in schools) {
      if (s is! Map<String, dynamic>) continue;
      final name = (s['name'] as String? ?? '').toLowerCase();
      if (name.contains(childSchoolLower) || childSchoolLower.contains(name)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadAndFilter({bool showLoading = true}) async {
    setState(() {
      if (showLoading) {
        _loading = true;
      }
      _error = null;
    });

    try {
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
      final List<dynamic> favoritesRaw =
          childData['favoriteVehicleIds'] as List<dynamic>? ?? [];
      _favoriteVehicleIds = favoritesRaw
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      final vansSnap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('status', isEqualTo: true)
          .get();

      final filtered = vansSnap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where(_schoolMatches)
          .map(
            (van) => {
              ...van,
              '_nearestDistanceKm': _nearestRouteDistanceKm(van),
            },
          )
          .toList();

      filtered.sort((a, b) {
        final aId = (a['id'] as String? ?? '');
        final bId = (b['id'] as String? ?? '');
        final aFavorite = _favoriteVehicleIds.contains(aId);
        final bFavorite = _favoriteVehicleIds.contains(bId);
        if (aFavorite != bFavorite) return aFavorite ? -1 : 1;

        final aDistance = (a['_nearestDistanceKm'] as num?)?.toDouble();
        final bDistance = (b['_nearestDistanceKm'] as num?)?.toDouble();

        if (aDistance == null && bDistance == null) {
          return (a['registerNumber'] as String? ?? '').compareTo(
            b['registerNumber'] as String? ?? '',
          );
        }
        if (aDistance == null) return 1;
        if (bDistance == null) return -1;
        return aDistance.compareTo(bDistance);
      });

      setState(() {
        _filteredVans = filtered;
        _loading = false;
        _loadedFromCache = false;
      });
      await _saveCachedResults();
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavoriteVehicle(String vehicleId) async {
    if (vehicleId.isEmpty || _favoriteUpdatingIds.contains(vehicleId)) return;

    final bool currentlyFavorite = _favoriteVehicleIds.contains(vehicleId);

    setState(() {
      _favoriteUpdatingIds = {..._favoriteUpdatingIds, vehicleId};
      if (currentlyFavorite) {
        _favoriteVehicleIds = {..._favoriteVehicleIds}..remove(vehicleId);
      } else {
        _favoriteVehicleIds = {..._favoriteVehicleIds, vehicleId};
      }
    });

    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('Not signed in');
      }

      await FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId)
          .update({
            'favoriteVehicleIds': currentlyFavorite
                ? FieldValue.arrayRemove([vehicleId])
                : FieldValue.arrayUnion([vehicleId]),
          });

      if (!mounted) return;
      setState(() {
        _filteredVans.sort((a, b) {
          final aId = (a['id'] as String? ?? '');
          final bId = (b['id'] as String? ?? '');
          final aFavorite = _favoriteVehicleIds.contains(aId);
          final bFavorite = _favoriteVehicleIds.contains(bId);
          if (aFavorite != bFavorite) return aFavorite ? -1 : 1;

          final aDistance = (a['_nearestDistanceKm'] as num?)?.toDouble();
          final bDistance = (b['_nearestDistanceKm'] as num?)?.toDouble();
          if (aDistance == null && bDistance == null) {
            return (a['registerNumber'] as String? ?? '').compareTo(
              b['registerNumber'] as String? ?? '',
            );
          }
          if (aDistance == null) return 1;
          if (bDistance == null) return -1;
          return aDistance.compareTo(bDistance);
        });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (currentlyFavorite) {
          _favoriteVehicleIds = {..._favoriteVehicleIds, vehicleId};
        } else {
          _favoriteVehicleIds = {..._favoriteVehicleIds}..remove(vehicleId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update favorite. Please try again.'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _favoriteUpdatingIds = {..._favoriteUpdatingIds}..remove(vehicleId);
      });
    }
  }

  String _compatibilityLabel(double? distanceKm) {
    if (distanceKm == null) return 'Unknown match';
    if (distanceKm <= 2.0) return 'Good match';
    if (distanceKm <= 6.0) return 'Moderate match';
    return 'Far match';
  }

  Color _compatibilityColor(double? distanceKm) {
    if (distanceKm == null) return Colors.blueGrey;
    if (distanceKm <= 2.0) return teal;
    if (distanceKm <= 6.0) return const Color(0xFFFFB020);
    return const Color(0xFFFF6B35);
  }

  List<String> _driverNames(Map<String, dynamic> van) {
    final List<dynamic> drivers = van['drivers'] as List<dynamic>? ?? [];
    return drivers
        .whereType<Map>()
        .map((driver) => (driver['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  bool _matchesDriverSearch(Map<String, dynamic> van, String queryLower) {
    if (queryLower.isEmpty) return true;
    final names = _driverNames(van);
    if (names.isEmpty) return false;
    return names.any((name) => name.toLowerCase().contains(queryLower));
  }

  List<LatLng> _extractRouteLatLng(Map<String, dynamic> van) {
    final List<LatLng> points = [];
    final start = van['startingLocation'] as Map<String, dynamic>?;
    final startLat = (start?['latitude'] as num?)?.toDouble();
    final startLng = (start?['longitude'] as num?)?.toDouble();
    if (startLat != null && startLng != null) {
      points.add(LatLng(startLat, startLng));
    }

    final routePoints = van['routePoints'] as List<dynamic>? ?? [];
    for (final p in routePoints) {
      if (p is! Map<String, dynamic>) continue;
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }

    final schoolPoints = _extractSchoolLatLng(van);
    for (final school in schoolPoints) {
      if (points.isEmpty) {
        points.add(school);
        continue;
      }

      final last = points.last;
      final sameAsLast =
          (last.latitude - school.latitude).abs() < 0.000001 &&
          (last.longitude - school.longitude).abs() < 0.000001;
      if (!sameAsLast) {
        points.add(school);
      }
    }

    return points;
  }

  List<LatLng> _extractSchoolLatLng(Map<String, dynamic> van) {
    final List<LatLng> schools = [];
    final rawSchools = van['schools'] as List<dynamic>? ?? [];
    for (final school in rawSchools) {
      if (school is! Map<String, dynamic>) continue;
      final lat = (school['latitude'] as num?)?.toDouble();
      final lng = (school['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        schools.add(LatLng(lat, lng));
      }
    }
    return schools;
  }

  void _openMapPreview(Map<String, dynamic> van) {
    final points = _extractRouteLatLng(van);
    final schoolPoints = _extractSchoolLatLng(van);
    final rawSchools = van['schools'] as List<dynamic>? ?? [];
    final List<String> schoolNames = rawSchools
        .whereType<Map>()
        .map((school) => (school['name'] ?? '').toString().trim())
        .toList();
    final start = points.isNotEmpty
        ? points.first
        : (_childLat != null && _childLng != null)
        ? LatLng(_childLat!, _childLng!)
        : const LatLng(6.9271, 79.8612);
    final pickup = (_childLat != null && _childLng != null)
        ? LatLng(_childLat!, _childLng!)
        : null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 420,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Route Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),
              const SizedBox(height: 10),
              if (points.length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4DE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFC56D)),
                    ),
                    child: const Text(
                      'This vehicle has limited route points. Showing available location data.',
                      style: TextStyle(
                        color: Color(0xFF7A4A00),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (points.length < 2) const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: start,
                        zoom: 12,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('start'),
                          position: start,
                          infoWindow: const InfoWindow(
                            title: 'Starting location',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                        ),
                        if (pickup != null)
                          Marker(
                            markerId: const MarkerId('pickup'),
                            position: pickup,
                            infoWindow: const InfoWindow(title: 'Child pickup'),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            ),
                          ),
                        ...schoolPoints.asMap().entries.map(
                          (entry) => Marker(
                            markerId: MarkerId('school_${entry.key}'),
                            position: entry.value,
                            infoWindow: InfoWindow(
                              title:
                                  schoolNames.length > entry.key &&
                                      schoolNames[entry.key].isNotEmpty
                                  ? schoolNames[entry.key]
                                  : 'School ${entry.key + 1}',
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueViolet,
                            ),
                          ),
                        ),
                      },
                      polylines: points.length < 2
                          ? {}
                          : {
                              Polyline(
                                polylineId: const PolylineId('route'),
                                points: points,
                                color: teal,
                                width: 4,
                              ),
                            },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [navy.withValues(alpha: 0.98), blue.withValues(alpha: 0.94)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.childName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Showing approved vehicles for your child, nearest options first',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_loadedFromCache)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Showing cached results while refreshing...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(
                icon: Icons.school_outlined,
                label: _childSchoolLabel,
                maxWidth: MediaQuery.sizeOf(context).width * 0.64,
              ),
              _infoChip(
                icon: Icons.straighten,
                label: _childLat == null || _childLng == null
                    ? 'Pickup location not set'
                    : 'Sorted by closest route distance',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    double? maxWidth,
  }) {
    return Container(
      constraints: maxWidth == null ? null : BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 170,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFF4F9FF), const Color(0xFFE8F2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: blue.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: teal.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBar(widthFactor: 0.58),
              const SizedBox(height: 10),
              _skeletonBar(widthFactor: 0.36),
              const SizedBox(height: 14),
              Row(
                children: [
                  _skeletonChip(),
                  const SizedBox(width: 8),
                  _skeletonChip(),
                ],
              ),
              const SizedBox(height: 14),
              _skeletonBar(widthFactor: 0.74),
              const SizedBox(height: 10),
              _skeletonBar(widthFactor: 0.90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonBar({required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: blue.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _skeletonChip() {
    return Container(
      width: 76,
      height: 24,
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not load vehicles',
              style: TextStyle(
                color: navy,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: blue.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAndFilter,
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.56,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: teal.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.directions_bus_outlined,
                    size: 48,
                    color: teal,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No vehicles found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No approved vehicles match this school yet.\nPull down to refresh after new vehicles are added.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: blue.withValues(alpha: 0.75),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7FBFF), Color(0xFFEAF3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blue.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_search_rounded,
            color: blue.withValues(alpha: 0.80),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _driverSearchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Search by driver name',
                hintStyle: TextStyle(
                  color: blue.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(
                color: navy,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_driverSearchController.text.trim().isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                _driverSearchController.clear();
                setState(() {});
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: navy.withValues(alpha: 0.72),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverSearchEmptyState(String query) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blue.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: blue.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          Text(
            'No drivers match "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another name or clear search to view all vehicles.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: blue.withValues(alpha: 0.70),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVanCard(Map<String, dynamic> van) {
    final vehicleId = van['id'] as String? ?? '';
    final isFavorite = _favoriteVehicleIds.contains(vehicleId);
    final isFavoriteUpdating = _favoriteUpdatingIds.contains(vehicleId);
    final startingLocation = van['startingLocation'] as Map<String, dynamic>?;
    final locationName = startingLocation?['name'] as String? ?? '';
    final vehicleType = van['vehicleType'] as String? ?? 'Vehicle';
    final vehicleTypeLower = vehicleType.toLowerCase();
    final vehicleIcon = vehicleTypeLower.contains('van')
        ? Icons.airport_shuttle
        : Icons.directions_bus;
    final condition = van['condition'] as String? ?? 'Unknown';
    final registerNumber = van['registerNumber'] as String? ?? 'No Number';
    final distanceKm = (van['_nearestDistanceKm'] as num?)?.toDouble();
    final matchLabel = _compatibilityLabel(distanceKm);
    final matchColor = _compatibilityColor(distanceKm);
    final drivers = _driverNames(van);
    final isGoodMatch = distanceKm != null && distanceKm <= 2.0;

    return AnimatedBuilder(
      animation: _goodMatchPulse,
      builder: (context, _) {
        final pulse = isGoodMatch ? _goodMatchPulse.value : 0.0;
        final badgeBgAlpha = isGoodMatch ? 0.08 + (0.05 * pulse) : 0.16;
        final badgeBorderAlpha = isGoodMatch ? 0.38 + (0.12 * pulse) : 0.45;
        final badgeScale = 1.0 + (0.03 * pulse);
        final cardBorderWidth = isGoodMatch ? 1.0 + (0.18 * pulse) : 1.0;
        final cardBorderColor = isGoodMatch
            ? Color.lerp(
                blue.withValues(alpha: 0.28),
                teal.withValues(alpha: 0.34),
                pulse,
              )!
            : blue.withValues(alpha: 0.28);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VehicleDetailsPage(
                      vanId: van['id'] as String,
                      vanData: van,
                      childId: widget.childId,
                      childName: widget.childName,
                    ),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFAFDFF), const Color(0xFFEDF5FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cardBorderColor,
                    width: cardBorderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.70),
                      blurRadius: 12,
                      offset: const Offset(-2, -2),
                    ),
                    BoxShadow(
                      color: teal.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.96),
                            const Color(0xFFE9F4FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: teal.withValues(alpha: 0.34),
                          width: 1.1,
                        ),
                      ),
                      child: Icon(
                        vehicleIcon,
                        color: teal.withValues(alpha: 0.98),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  registerNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: matchColor.withValues(
                                    alpha: badgeBgAlpha,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: matchColor.withValues(
                                      alpha: badgeBorderAlpha,
                                    ),
                                  ),
                                  boxShadow: isGoodMatch
                                      ? [
                                          BoxShadow(
                                            color: matchColor.withValues(
                                              alpha: 0.08 + (0.10 * pulse),
                                            ),
                                            blurRadius: 5 + (5 * pulse),
                                            spreadRadius: 0.05 + (0.35 * pulse),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Transform.scale(
                                  scale: isGoodMatch ? badgeScale : 1,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isGoodMatch)
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 11 + (1.3 * pulse),
                                          color: matchColor.withValues(
                                            alpha: 0.76 + (0.16 * pulse),
                                          ),
                                        ),
                                      if (isGoodMatch) const SizedBox(width: 4),
                                      Text(
                                        matchLabel,
                                        style: TextStyle(
                                          color: matchColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: blue.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  vehicleType,
                                  style: TextStyle(
                                    color: navy.withValues(alpha: 0.92),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: teal.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: teal.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  condition,
                                  style: const TextStyle(
                                    color: teal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: blue.withValues(alpha: 0.78),
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  drivers.isEmpty
                                      ? 'Driver: Not assigned yet'
                                      : 'Driver: ${drivers.join(', ')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: navy.withValues(alpha: 0.84),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (distanceKm != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  color: teal,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Closest to pickup: ${distanceKm.toStringAsFixed(1)} km',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: navy.withValues(alpha: 0.90),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: blue.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: blue.withValues(alpha: 0.78),
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    locationName.isEmpty
                                        ? 'Starting location: Not provided'
                                        : 'Starting location: $locationName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: navy.withValues(alpha: 0.84),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: isFavoriteUpdating
                              ? null
                              : () => _toggleFavoriteVehicle(vehicleId),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isFavorite
                                      ? const Color(0xFFE7FBF5)
                                      : Colors.white.withValues(alpha: 0.98),
                                  isFavorite
                                      ? const Color(0xFFD5F4EB)
                                      : const Color(0xFFE6F2FF),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isFavorite
                                    ? teal.withValues(alpha: 0.42)
                                    : blue.withValues(alpha: 0.25),
                              ),
                            ),
                            child: isFavoriteUpdating
                                ? Padding(
                                    padding: const EdgeInsets.all(7),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: navy,
                                    ),
                                  )
                                : Icon(
                                    isFavorite
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    color: isFavorite
                                        ? const Color(0xFF009A7A)
                                        : navy.withValues(alpha: 0.88),
                                    size: 16,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => _openMapPreview(van),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.98),
                                  const Color(0xFFE6F2FF),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: blue.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              color: navy.withValues(alpha: 0.90),
                              size: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.98),
                                const Color(0xFFE6F2FF),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: blue.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: navy.withValues(alpha: 0.85),
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final driverQuery = _driverSearchController.text.trim();
    final driverQueryLower = driverQuery.toLowerCase();
    final visibleVans = _filteredVans
        .where((van) => _matchesDriverSearch(van, driverQueryLower))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FA),
      appBar: AppBar(
        backgroundColor: navy,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Filtered Vehicles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChildSettingsPage(
                    childId: widget.childId,
                    childName: widget.childName,
                  ),
                ),
              ).then((_) => _loadAndFilter());
            },
            tooltip: 'Child Settings',
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: teal,
        onRefresh: _loadAndFilter,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 14),
            if (!_loading && _error == null && _filteredVans.isNotEmpty) ...[
              _buildDriverSearchBar(),
              const SizedBox(height: 12),
            ],
            if (_loading)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: _buildLoadingState(),
              )
            else if (_error != null)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: _buildErrorState(),
              )
            else if (_filteredVans.isEmpty)
              _buildEmptyState()
            else if (visibleVans.isEmpty)
              _buildDriverSearchEmptyState(driverQuery)
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 2),
                child: Text(
                  '${visibleVans.length} matching vehicles • ${_favoriteVehicleIds.length} saved',
                  style: TextStyle(
                    color: blue.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...visibleVans.map(_buildVanCard),
            ],
          ],
        ),
      ),
    );
  }
}
