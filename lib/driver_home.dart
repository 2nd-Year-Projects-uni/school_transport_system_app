import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/location_service.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({Key? key}) : super(key: key);

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final LocationService _locationService = LocationService();

  String? _currentVehicleId;
  Map<String, dynamic>? _currentVehicleData;
  bool _isAssignedVehicleExpanded = false;
  bool _isJoinVehicleExpanded = false;
  bool _isLeaving = false;
  bool _isOpeningJourney = false;

  String _placeName(dynamic place) {
    if (place is String) {
      return place.trim();
    }
    if (place is Map) {
      final dynamic name = place['name'];
      if (name is String) {
        return name.trim();
      }
    }
    return '';
  }

  List<String> _placeNameList(dynamic places) {
    final List<dynamic> list = places as List<dynamic>? ?? const <dynamic>[];
    return list.map(_placeName).where((name) => name.isNotEmpty).toList();
  }

  List<_JourneyPoint> _extractJourneyPoints(
    dynamic source,
    String fallbackLabel,
  ) {
    final list = source as List<dynamic>? ?? const <dynamic>[];
    final points = <_JourneyPoint>[];

    for (final item in list) {
      if (item is! Map) continue;
      final lat = (item['latitude'] as num?)?.toDouble();
      final lng = (item['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final name = _placeName(item);
      points.add(
        _JourneyPoint(
          latitude: lat,
          longitude: lng,
          label: name.isNotEmpty ? name : fallbackLabel,
        ),
      );
    }

    return points;
  }

  _JourneyPlan? _resolveJourneyPlan() {
    final data = _currentVehicleData;
    if (data == null) return null;

    final schools = _extractJourneyPoints(data['schools'], 'School');
    final routePoints = _extractJourneyPoints(
      data['routePoints'],
      'Checkpoint',
    );

    if (schools.isNotEmpty) {
      final destination = schools.last;
      final schoolStops = schools.take(schools.length - 1).toList();

      final checkpointWaypoints = routePoints
          .map((point) => _JourneyWaypoint(point: point, isCheckpoint: true))
          .toList();

      final schoolWaypoints = schoolStops
          .map((point) => _JourneyWaypoint(point: point, isCheckpoint: false))
          .toList();

      final waypoints = [...checkpointWaypoints, ...schoolWaypoints];

      return _JourneyPlan(destination: destination, waypoints: waypoints);
    }

    if (routePoints.isNotEmpty) {
      return _JourneyPlan(destination: routePoints.first, waypoints: const []);
    }

    final startingLocation = data['startingLocation'];
    if (startingLocation is Map) {
      final lat = (startingLocation['latitude'] as num?)?.toDouble();
      final lng = (startingLocation['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final name = _placeName(startingLocation);
        return _JourneyPlan(
          destination: _JourneyPoint(
            latitude: lat,
            longitude: lng,
            label: name.isNotEmpty ? name : 'Starting location',
          ),
          waypoints: const [],
        );
      }
    }

    return null;
  }

  Future<void> _startJourneyInGoogleMaps() async {
    if (_isOpeningJourney) return;

    final plan = _resolveJourneyPlan();
    if (plan == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No destination found for this vehicle yet.'),
        ),
      );
      return;
    }

    setState(() => _isOpeningJourney = true);
    try {
      final destinationLat = plan.destination.latitude.toStringAsFixed(6);
      final destinationLng = plan.destination.longitude.toStringAsFixed(6);

      final waypointParam = plan.waypoints
          .map((waypoint) {
            final lat = waypoint.point.latitude.toStringAsFixed(6);
            final lng = waypoint.point.longitude.toStringAsFixed(6);
            return '$lat,$lng';
          })
          .join('|');

      final query = <String, String>{
        'api': '1',
        'destination': '$destinationLat,$destinationLng',
        'travelmode': 'driving',
      };
      if (waypointParam.isNotEmpty) {
        query['waypoints'] = waypointParam;
      }

      final directionsUri = Uri.https('www.google.com', '/maps/dir/', query);
      final launched = await launchUrl(
        directionsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start journey navigation.')),
      );
    } finally {
      if (mounted) setState(() => _isOpeningJourney = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentVehicle();
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startTracking();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  Future<void> _loadCurrentVehicle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final vehicleId = userDoc.data()?['vehicleId'] as String?;
    if (vehicleId != null && vehicleId.isNotEmpty) {
      final vehicleDoc = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vehicleId)
          .get();
      if (vehicleDoc.exists) {
        setState(() {
          _currentVehicleId = vehicleId;
          _currentVehicleData = vehicleDoc.data();
          _isAssignedVehicleExpanded = false;
          _isJoinVehicleExpanded = false;
        });
      } else {
        setState(() {
          _currentVehicleId = null;
          _currentVehicleData = null;
          _isAssignedVehicleExpanded = false;
          _isJoinVehicleExpanded = false;
        });
      }
    } else {
      setState(() {
        _currentVehicleId = null;
        _currentVehicleData = null;
        _isAssignedVehicleExpanded = false;
        _isJoinVehicleExpanded = false;
      });
    }
  }

  Future<void> _leaveVehicle() async {
    setState(() => _isLeaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _currentVehicleId == null)
        throw Exception('Not logged in or no vehicle assigned');
      final uid = user.uid;
      final vehicleRef = FirebaseFirestore.instance
          .collection('vehicles')
          .doc(_currentVehicleId);
      final vehicleSnap = await vehicleRef.get();
      final vehicleData = vehicleSnap.data() ?? <String, dynamic>{};
      final existingDrivers = (vehicleData['drivers'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final filteredDrivers = existingDrivers
          .where((driver) => driver['uid'] != uid)
          .toList();

      // Keep vehicle and user assignment updates in sync.
      final batch = FirebaseFirestore.instance.batch();
      batch.update(vehicleRef, {'drivers': filteredDrivers});
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'vehicleId': null,
      });
      await batch.commit();

      setState(() {
        _currentVehicleId = null;
        _currentVehicleData = null;
        _isAssignedVehicleExpanded = false;
        _isJoinVehicleExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left the vehicle.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLeaving = false);
    }
  }

  final TextEditingController _vehicleCodeController = TextEditingController();
  bool _isLoading = false;

  final Color navy = const Color(0xFF001F3F);
  final Color blue = const Color(0xFF005792);
  final Color teal = const Color(0xFF00B894);

  @override
  void dispose() {
    _locationService.stopTracking();
    _vehicleCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinVehicle() async {
    final code = _vehicleCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vehicle code.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final uid = user.uid;
      // Fetch driver's name from user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final String? name = userDoc.data()?['name'] as String?;
      if (name == null || name.isEmpty)
        throw Exception('Driver name not found.');
      final vehicleSnap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (vehicleSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle code not found.')),
        );
        setState(() => _isLoading = false);
        return;
      }
      final vehicleDoc = vehicleSnap.docs.first;
      final vehicleId = vehicleDoc.id;
      final vehicleData = vehicleDoc.data();
      final List<dynamic> drivers =
          (vehicleData['drivers'] as List<dynamic>?) ?? [];
      // Check if already joined (by uid)
      final alreadyJoined = drivers.any((d) => d is Map && d['uid'] == uid);
      if (alreadyJoined) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are already assigned to this vehicle.'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      if (drivers.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This vehicle already has 2 drivers assigned.'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      // Add driver (as map) to vehicle's drivers array
      await vehicleDoc.reference.update({
        'drivers': FieldValue.arrayUnion([
          {'uid': uid, 'name': name},
        ]),
      });
      // Update driver's user document with assigned vehicle
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'vehicleId': vehicleId,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the vehicle!')),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactPhone = screenWidth < 380;
    final isLargePhone = screenWidth >= 480;
    final horizontalPagePadding = isCompactPhone ? 14.0 : 20.0;
    final topPagePadding = isCompactPhone ? 18.0 : 24.0;
    final cardInnerPadding = isCompactPhone ? 14.0 : 16.0;
    final cardBottomPadding = isCompactPhone ? 16.0 : 18.0;
    final cardRadius = isCompactPhone ? 18.0 : 20.0;
    final sectionRadius = isCompactPhone ? 12.0 : 14.0;
    final vehicleImageHeight = isLargePhone
        ? 190.0
        : (isCompactPhone ? 152.0 : 170.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Driver Portal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPagePadding,
                topPagePadding,
                horizontalPagePadding,
                0,
              ),
              child: _currentVehicleId != null && _currentVehicleData != null
                  ? Container(
                      padding: EdgeInsets.fromLTRB(
                        cardInnerPadding,
                        cardInnerPadding,
                        cardInnerPadding,
                        cardBottomPadding,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(color: blue.withOpacity(0.22)),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _isAssignedVehicleExpanded =
                                    !_isAssignedVehicleExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [navy, blue],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.directions_bus_filled_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Assigned Vehicle',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: teal.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      color: teal,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                AnimatedRotation(
                                  turns: _isAssignedVehicleExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 220),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 22,
                                    color: navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Vehicle photo
                          Builder(
                            builder: (context) {
                              final String photoUrl =
                                  _currentVehicleData!['vehiclePhotoUrl']
                                      as String? ??
                                  '';
                              if (photoUrl.isNotEmpty)
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    photoUrl,
                                    height: vehicleImageHeight,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: vehicleImageHeight,
                                      color: blue.withOpacity(0.08),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.directions_bus,
                                        size: 64,
                                        color: blue,
                                      ),
                                    ),
                                  ),
                                );
                              return Container(
                                height: vehicleImageHeight,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      blue.withOpacity(0.14),
                                      teal.withOpacity(0.12),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.directions_bus,
                                  size: 64,
                                  color: blue,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isCompactPhone ? 12 : 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                sectionRadius,
                              ),
                              border: Border.all(color: blue.withOpacity(0.16)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentVehicleData!['registerNumber']
                                          ?.toString() ??
                                      'N/A',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: navy,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: blue.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Type: ${_currentVehicleData!['vehicleType'] ?? 'N/A'}',
                                        style: TextStyle(
                                          color: blue,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (_currentVehicleData!['code'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: teal.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'Code: ${_currentVehicleData!['code']}',
                                          style: TextStyle(
                                            color: teal,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isAssignedVehicleExpanded
                                ? 'Tap header to collapse details'
                                : 'Tap header to view route and schools',
                            style: TextStyle(
                              color: blue.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 240),
                            crossFadeState: _isAssignedVehicleExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Builder(
                                builder: (context) {
                                  final String
                                  parsedStartingLocation = _placeName(
                                    _currentVehicleData!['startingLocation'],
                                  );
                                  final String startingLocation =
                                      parsedStartingLocation.isNotEmpty
                                      ? parsedStartingLocation
                                      : 'Not available';

                                  final List<String> schools = _placeNameList(
                                    _currentVehicleData!['schools'],
                                  );

                                  final List<String> routePoints =
                                      _placeNameList(
                                        _currentVehicleData!['routePoints'],
                                      );

                                  return Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(
                                          isCompactPhone ? 12 : 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            sectionRadius,
                                          ),
                                          border: Border.all(
                                            color: teal.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Route & Coverage',
                                              style: TextStyle(
                                                color: navy,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined,
                                                  size: 18,
                                                  color: blue,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Starting Location: $startingLocation',
                                                    style: TextStyle(
                                                      color: navy,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Mid Points',
                                              style: TextStyle(
                                                color: blue,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            if (routePoints.isEmpty)
                                              Text(
                                                'No mid points added.',
                                                style: TextStyle(
                                                  color:
                                                      Colors.blueGrey.shade500,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              )
                                            else
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: routePoints
                                                    .map(
                                                      (point) => Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 9,
                                                              vertical: 5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: blue
                                                              .withOpacity(
                                                                0.16,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          point,
                                                          style: TextStyle(
                                                            color: blue,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Schools',
                                              style: TextStyle(
                                                color: blue,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            if (schools.isEmpty)
                                              Text(
                                                'No schools added.',
                                                style: TextStyle(
                                                  color:
                                                      Colors.blueGrey.shade500,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              )
                                            else
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: schools
                                                    .map(
                                                      (school) => Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 9,
                                                              vertical: 5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: teal
                                                              .withOpacity(
                                                                0.18,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          school,
                                                          style: TextStyle(
                                                            color: teal,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _isLeaving
                                              ? null
                                              : () async {
                                                  final shouldResign = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) {
                                                      return Theme(
                                                        data: Theme.of(context).copyWith(
                                                          colorScheme:
                                                              ColorScheme.light(
                                                                primary: navy,
                                                                onPrimary:
                                                                    Colors
                                                                        .white,
                                                                surface: Colors
                                                                    .white,
                                                                onSurface: navy,
                                                              ),
                                                          dialogBackgroundColor:
                                                              Colors.white,
                                                        ),
                                                        child: AlertDialog(
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  18,
                                                                ),
                                                          ),
                                                          titlePadding:
                                                              const EdgeInsets.fromLTRB(
                                                                20,
                                                                18,
                                                                20,
                                                                8,
                                                              ),
                                                          contentPadding:
                                                              const EdgeInsets.fromLTRB(
                                                                20,
                                                                0,
                                                                20,
                                                                10,
                                                              ),
                                                          title: Row(
                                                            children: [
                                                              Container(
                                                                width: 30,
                                                                height: 30,
                                                                decoration: BoxDecoration(
                                                                  color: blue
                                                                      .withOpacity(
                                                                        0.14,
                                                                      ),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child: Icon(
                                                                  Icons
                                                                      .exit_to_app_rounded,
                                                                  color: blue,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              const Expanded(
                                                                child: Text(
                                                                  'Resign From Vehicle',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    fontSize:
                                                                        18,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          content: Text(
                                                            'Are you sure you want to resign from this vehicle?',
                                                            style: TextStyle(
                                                              color: navy
                                                                  .withOpacity(
                                                                    0.85,
                                                                  ),
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          actionsPadding:
                                                              const EdgeInsets.fromLTRB(
                                                                14,
                                                                0,
                                                                14,
                                                                14,
                                                              ),
                                                          actions: [
                                                            OutlinedButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(false),
                                                              style: OutlinedButton.styleFrom(
                                                                foregroundColor:
                                                                    blue,
                                                                side: BorderSide(
                                                                  color: blue
                                                                      .withOpacity(
                                                                        0.45,
                                                                      ),
                                                                ),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(true),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    blue,
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: const Text(
                                                                'Resign',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  );

                                                  if (shouldResign == true) {
                                                    await _leaveVehicle();
                                                  }
                                                },
                                          icon: _isLeaving
                                              ? SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: blue,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.exit_to_app_rounded,
                                                  size: 16,
                                                  color: blue,
                                                ),
                                          label: Text(
                                            _isLeaving
                                                ? 'Resigning...'
                                                : 'Resign From Vehicle',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: blue,
                                            side: BorderSide(
                                              color: blue.withOpacity(0.55),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 11,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: EdgeInsets.fromLTRB(
                        cardInnerPadding,
                        cardInnerPadding,
                        cardInnerPadding,
                        cardBottomPadding,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(color: blue.withOpacity(0.22)),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _isJoinVehicleExpanded =
                                    !_isJoinVehicleExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [navy, blue],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.link_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Join Vehicle',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: blue.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'No Assignment',
                                    style: TextStyle(
                                      color: blue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                AnimatedRotation(
                                  turns: _isJoinVehicleExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 220),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 22,
                                    color: navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: vehicleImageHeight,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  blue.withOpacity(0.14),
                                  teal.withOpacity(0.12),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_bus_filled_rounded,
                                  size: 52,
                                  color: blue,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No vehicle assigned yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isCompactPhone ? 12 : 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                sectionRadius,
                              ),
                              border: Border.all(color: blue.withOpacity(0.16)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ready to connect to your assigned vehicle.',
                                  style: TextStyle(
                                    color: navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isJoinVehicleExpanded
                                      ? 'Use your code below to join now.'
                                      : 'Tap header to open the code entry section.',
                                  style: TextStyle(
                                    color: blue.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 240),
                            crossFadeState: _isJoinVehicleExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isCompactPhone ? 12 : 14,
                                      vertical: isCompactPhone ? 10 : 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        sectionRadius,
                                      ),
                                      border: Border.all(
                                        color: blue.withOpacity(0.16),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Enter Vehicle Code',
                                          style: TextStyle(
                                            color: navy,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5FAFF),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: teal.withOpacity(0.24),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.qr_code_rounded,
                                                size: 18,
                                                color: teal,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      _vehicleCodeController,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Paste vehicle code',
                                                    hintStyle: TextStyle(
                                                      color: blue.withOpacity(
                                                        0.7,
                                                      ),
                                                    ),
                                                    border: InputBorder.none,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: navy,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  enabled: !_isLoading,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : () async {
                                                    await _joinVehicle();
                                                    await _loadCurrentVehicle();
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: teal,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 11,
                                                  ),
                                              elevation: 1,
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.3,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  )
                                                : const Text(
                                                    'Join Assigned Vehicle',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(
                                      isCompactPhone ? 10 : 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        sectionRadius,
                                      ),
                                      border: Border.all(
                                        color: teal.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 17,
                                          color: blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Use the code shared by your vehicle owner to connect with your assigned vehicle.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: blue.withOpacity(0.88),
                                              fontWeight: FontWeight.w600,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 56,
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
                    color: navy.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isOpeningJourney ? null : _startJourneyInGoogleMaps,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isOpeningJourney
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.navigation_rounded, color: Colors.white),
                label: const Text(
                  'Start Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyPoint {
  final double latitude;
  final double longitude;
  final String label;

  const _JourneyPoint({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

class _JourneyWaypoint {
  final _JourneyPoint point;
  final bool isCheckpoint;

  const _JourneyWaypoint({required this.point, required this.isCheckpoint});
}

class _JourneyPlan {
  final _JourneyPoint destination;
  final List<_JourneyWaypoint> waypoints;

  const _JourneyPlan({required this.destination, required this.waypoints});
}
