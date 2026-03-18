import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mapbox_config.dart';

class DriverTrackingMapPage extends StatefulWidget {
  final String childId;
  final String childName;

  const DriverTrackingMapPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<DriverTrackingMapPage> createState() => _DriverTrackingMapPageState();
}

class _DriverTrackingMapPageState extends State<DriverTrackingMapPage> {
  static const String _databaseUrl =
      'https://school-transport-system-6eb9f-default-rtdb.asia-southeast1.firebasedatabase.app';

  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);

  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612);

  final MapController _mapController = MapController();
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  DateTime? _lastCameraMoveAt;
  LatLng? _lastCameraTarget;
  LatLng? _pendingCameraTarget;
  bool _isMapReady = false;
  bool _hasCenteredOnLivePoint = false;

  LatLng? _displayDriverLocation;
  LatLng? _targetDriverLocation;
  Timer? _smoothingTimer;

  static const Duration _smoothingTick = Duration(milliseconds: 120);
  static const double _smoothingFactor = 0.28;
  static const double _snapThreshold = 0.00002;

  static const double _cameraFollowDistanceMeters = 14;
  static const Duration _cameraFollowInterval = Duration(seconds: 3);

  static const double _headingMovementThreshold = 0.00001;
  static const double _headingSmoothingFactor = 0.22;
  static const double _headingSnapThreshold = 1.5;

  static const Duration _minRouteRefreshInterval = Duration(seconds: 30);
  static const double _offRouteThresholdMeters = 70;
  static const double _offRouteCheckMovementMeters = 20;
  static const double _stopArrivalRadiusMeters = 120;
  static const int _maxRenderedRoutePoints = 220;

  double _driverHeading = 0;
  double _targetDriverHeading = 0;

  bool _isRouteLoading = false;
  int _routeRequestId = 0;
  DateTime? _lastRouteFetchAt;
  String _lastRouteSignature = '';
  LatLng? _lastOffRouteCheckPoint;
  List<LatLng> _activeRoutePolyline = const <LatLng>[];
  int? _etaMinutes;
  final Set<int> _completedStopIndexes = <int>{};
  String _journeyProgressKey = '';
  bool _showStopsExpanded = false;
  bool _showLegend = false;
  bool _showInfoPanelExpanded = false;
  final Map<String, String> _driverPhoneCache = <String, String>{};
  final Set<String> _driverPhoneLookupsInFlight = <String>{};

  @override
  void dispose() {
    _smoothingTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    final result = <String, dynamic>{};
    value.forEach((key, val) {
      result[key.toString()] = val;
    });
    return result;
  }

  LatLng? _toLatLng(dynamic value) {
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final map = _asMap(value);
      final lat =
          (map['latitude'] as num?)?.toDouble() ??
          (map['lat'] as num?)?.toDouble();
      final lng =
          (map['longitude'] as num?)?.toDouble() ??
          (map['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  List<_JourneyStop> _extractJourneyStops(dynamic rawRouteSnapshot) {
    final route = rawRouteSnapshot as List<dynamic>? ?? const <dynamic>[];
    final points = <_JourneyStop>[];

    for (final point in route) {
      if (point is! Map) continue;
      final map = _asMap(point);
      final lat = (map['latitude'] as num?)?.toDouble();
      final lng = (map['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      points.add(
        _JourneyStop(
          point: LatLng(lat, lng),
          label: (map['label'] as String?)?.trim() ?? '',
          type: (map['type'] as String?)?.trim() ?? 'waypoint',
        ),
      );
    }

    return points;
  }

  List<_JourneyStop> _stopsForJourneyMode(
    List<_JourneyStop> rawStops,
    String? rawMode,
    String? rawRouteOrderVersion,
  ) {
    final orderVersion = rawRouteOrderVersion?.trim().toLowerCase() ?? '';
    if (orderVersion == 'mode_ordered_v1') {
      return rawStops;
    }

    final mode = rawMode?.trim().toLowerCase();
    if (mode != 'afternoon' || rawStops.isEmpty) {
      return rawStops;
    }

    final alreadyModeAware = rawStops.any((s) => s.type == 'home_stop');
    if (alreadyModeAware) {
      return rawStops;
    }

    final reversed = rawStops.reversed.toList(growable: false);
    return List<_JourneyStop>.generate(reversed.length, (index) {
      final stop = reversed[index];
      var mappedType = stop.type;

      if (mappedType == 'school_stop') {
        mappedType = 'home_stop';
      }
      if (mappedType == 'destination' && index == 0) {
        mappedType = 'school_stop';
      }
      if (index == reversed.length - 1) {
        mappedType = 'destination';
      }

      return _JourneyStop(
        point: stop.point,
        label: stop.label,
        type: mappedType,
      );
    });
  }

  String _routeSignatureFor(LatLng currentLocation, List<_JourneyStop> stops) {
    String normalize(double value) => value.toStringAsFixed(5);
    final segments = <String>[
      '${normalize(currentLocation.latitude)},${normalize(currentLocation.longitude)}',
      ...stops.map(
        (stop) =>
            '${normalize(stop.point.latitude)},${normalize(stop.point.longitude)}:${stop.type}',
      ),
    ];
    return segments.join('|');
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;

    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final h =
        sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  double _distanceAbs(LatLng a, LatLng b) {
    final latDiff = (a.latitude - b.latitude).abs();
    final lngDiff = (a.longitude - b.longitude).abs();
    return latDiff + lngDiff;
  }

  double _nearestRouteDistanceMeters(LatLng point, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return double.infinity;
    var minDistance = double.infinity;
    for (final routePoint in routePoints) {
      final distance = _distanceMeters(point, routePoint);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  bool _needsReroute({
    required LatLng currentLocation,
    required List<_JourneyStop> stops,
    required String signature,
  }) {
    if (stops.isEmpty || !MapboxConfig.isConfigured) {
      return false;
    }

    if (_activeRoutePolyline.length < 2 || signature != _lastRouteSignature) {
      return true;
    }

    if (_lastRouteFetchAt == null) {
      return true;
    }

    final movedSinceCheck =
        _lastOffRouteCheckPoint == null ||
        _distanceMeters(_lastOffRouteCheckPoint!, currentLocation) >=
            _offRouteCheckMovementMeters;

    if (!movedSinceCheck) {
      return false;
    }

    _lastOffRouteCheckPoint = currentLocation;

    final awayFromRoute =
        _nearestRouteDistanceMeters(currentLocation, _activeRoutePolyline) >=
        _offRouteThresholdMeters;

    if (!awayFromRoute) {
      return false;
    }

    return DateTime.now().difference(_lastRouteFetchAt!) >=
        _minRouteRefreshInterval;
  }

  void _scheduleRouteRefresh(LatLng currentLocation, List<_JourneyStop> stops) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshRouteFromMapbox(currentLocation, stops);
    });
  }

  Future<void> _refreshRouteFromMapbox(
    LatLng currentLocation,
    List<_JourneyStop> stops,
  ) async {
    if (_isRouteLoading || stops.isEmpty || !MapboxConfig.isConfigured) return;

    final signature = _routeSignatureFor(currentLocation, stops);
    if (!_needsReroute(
      currentLocation: currentLocation,
      stops: stops,
      signature: signature,
    )) {
      return;
    }

    final token = MapboxConfig.accessToken.trim();
    if (token.isEmpty) return;

    setState(() {
      _isRouteLoading = true;
    });

    final requestId = ++_routeRequestId;

    try {
      final coordinates = <LatLng>[
        currentLocation,
        ...stops.map((s) => s.point),
      ];
      final coordinatesParam = coordinates
          .map(
            (p) =>
                '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
          )
          .join(';');

      final uri =
          Uri.parse(
            'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/$coordinatesParam',
          ).replace(
            queryParameters: {
              'alternatives': 'false',
              'geometries': 'geojson',
              'overview': 'full',
              'steps': 'false',
              'access_token': token,
            },
          );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return;

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = payload['routes'] as List<dynamic>? ?? const <dynamic>[];
      if (routes.isEmpty) return;

      final firstRoute = routes.first as Map<String, dynamic>;
      final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
      final rawCoords =
          geometry?['coordinates'] as List<dynamic>? ?? const <dynamic>[];

      final points = <LatLng>[];
      for (final item in rawCoords) {
        if (item is! List || item.length < 2) continue;
        final lng = (item[0] as num?)?.toDouble();
        final lat = (item[1] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        points.add(LatLng(lat, lng));
      }

      final durationSecs = (firstRoute['duration'] as num?)?.toDouble();
      final eta = durationSecs == null ? null : (durationSecs / 60).ceil();

      if (!mounted || requestId != _routeRequestId || points.length < 2) return;

      setState(() {
        _activeRoutePolyline = _downsampleRoute(points);
        _lastRouteFetchAt = DateTime.now();
        _lastRouteSignature = signature;
        _etaMinutes = eta;
      });
    } catch (_) {
      // Keep current route when API call fails.
    } finally {
      if (mounted && requestId == _routeRequestId) {
        setState(() {
          _isRouteLoading = false;
        });
      }
    }
  }

  List<LatLng> _downsampleRoute(List<LatLng> points) {
    if (points.length <= _maxRenderedRoutePoints) return points;

    final step = ((points.length - 1) / (_maxRenderedRoutePoints - 1))
        .ceil()
        .clamp(1, points.length);

    final reduced = <LatLng>[];
    for (var i = 0; i < points.length; i += step) {
      reduced.add(points[i]);
    }

    final last = points.last;
    if (reduced.isEmpty ||
        reduced.last.latitude != last.latitude ||
        reduced.last.longitude != last.longitude) {
      reduced.add(last);
    }

    return reduced;
  }

  double _normalizeHeading(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearingDeg = math.atan2(y, x) * 180 / math.pi;
    return _normalizeHeading(bearingDeg);
  }

  double _shortestHeadingDelta(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  double _lerpHeading(double from, double to, double t) {
    final delta = _shortestHeadingDelta(from, to);
    return _normalizeHeading(from + (delta * t));
  }

  LatLng _lerpLatLng(LatLng from, LatLng to, double t) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  LatLng _consumeIncomingDriverLocation(LatLng incoming, {double? heading}) {
    final explicitHeading = heading == null ? null : _normalizeHeading(heading);

    if (_displayDriverLocation == null) {
      _displayDriverLocation = incoming;
      _targetDriverLocation = incoming;
      if (explicitHeading != null) {
        _driverHeading = explicitHeading;
        _targetDriverHeading = explicitHeading;
      }
      return incoming;
    }

    final previous = _targetDriverLocation ?? _displayDriverLocation!;
    if (explicitHeading != null) {
      _targetDriverHeading = explicitHeading;
    } else if (_distanceAbs(previous, incoming) >= _headingMovementThreshold) {
      _targetDriverHeading = _bearingBetween(previous, incoming);
    }

    _targetDriverLocation = incoming;
    _ensureSmoothingTimer();
    return _displayDriverLocation!;
  }

  void _ensureSmoothingTimer() {
    if (_smoothingTimer != null) return;
    _smoothingTimer = Timer.periodic(_smoothingTick, (_) {
      final current = _displayDriverLocation;
      final target = _targetDriverLocation;
      if (!mounted || current == null || target == null) {
        _smoothingTimer?.cancel();
        _smoothingTimer = null;
        return;
      }

      final distance = _distanceAbs(current, target);
      final headingDelta = _shortestHeadingDelta(
        _driverHeading,
        _targetDriverHeading,
      ).abs();

      if (distance <= _snapThreshold && headingDelta <= _headingSnapThreshold) {
        setState(() {
          _displayDriverLocation = target;
          _driverHeading = _targetDriverHeading;
        });
        _smoothingTimer?.cancel();
        _smoothingTimer = null;
        return;
      }

      setState(() {
        if (distance <= _snapThreshold) {
          _displayDriverLocation = target;
        } else {
          _displayDriverLocation = _lerpLatLng(
            current,
            target,
            _smoothingFactor,
          );
        }

        if (headingDelta <= _headingSnapThreshold) {
          _driverHeading = _targetDriverHeading;
        } else {
          _driverHeading = _lerpHeading(
            _driverHeading,
            _targetDriverHeading,
            _headingSmoothingFactor,
          );
        }
      });
    });
  }

  void _moveCameraIfNeeded(LatLng location) {
    if (!_isMapReady) {
      _pendingCameraTarget = location;
      return;
    }

    final now = DateTime.now();
    final movedFarEnough =
        _lastCameraTarget == null ||
        _distanceMeters(_lastCameraTarget!, location) >=
            _cameraFollowDistanceMeters;
    final waitedEnough =
        _lastCameraMoveAt == null ||
        now.difference(_lastCameraMoveAt!) >= _cameraFollowInterval;
    final shouldMove =
        !_hasCenteredOnLivePoint || (movedFarEnough && waitedEnough);

    if (!shouldMove) return;

    _mapController.move(location, 16);
    _lastCameraMoveAt = now;
    _lastCameraTarget = location;
    _hasCenteredOnLivePoint = true;
  }

  void _scheduleCameraFollow(LatLng location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _moveCameraIfNeeded(location);
    });
  }

  String _statusLabel(String rawStatus, bool isStale) {
    final normalized = rawStatus.trim().toLowerCase();
    if (isStale && normalized == 'in_progress') {
      return 'Live update delayed';
    }
    switch (normalized) {
      case 'in_progress':
        return 'On route';
      case 'paused':
        return 'Paused';
      case 'ended':
        return 'Journey ended';
      default:
        return 'Waiting';
    }
  }

  Color _statusColor(String rawStatus, bool isStale) {
    if (isStale) return const Color(0xFFE67E22);
    switch (rawStatus.trim().toLowerCase()) {
      case 'in_progress':
        return teal;
      case 'paused':
        return const Color(0xFFFF8F00);
      case 'ended':
        return const Color(0xFF6C757D);
      default:
        return blue;
    }
  }

  String _formatLastUpdated(int? updatedAtMs) {
    if (updatedAtMs == null || updatedAtMs <= 0) return 'No updates yet';
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
    final seconds = DateTime.now().difference(updatedAt).inSeconds;
    if (seconds < 5) return 'Updated just now';
    if (seconds < 60) return 'Updated ${seconds}s ago';
    final minutes = DateTime.now().difference(updatedAt).inMinutes;
    return 'Updated ${minutes}m ago';
  }

  bool _isConnectionStale(int? updatedAtMs) {
    if (updatedAtMs == null || updatedAtMs <= 0) return true;
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
    return DateTime.now().difference(updatedAt).inSeconds > 20;
  }

  String _formatEtaText() {
    final eta = _etaMinutes;
    if (eta == null) return 'Calculating ETA...';
    if (eta <= 1) return 'Arriving shortly';
    if (eta < 60) return 'Arriving in $eta min';
    final hours = eta ~/ 60;
    final mins = eta % 60;
    return mins == 0
        ? 'Arriving in ${hours}h'
        : 'Arriving in ${hours}h ${mins}m';
  }

  String _journeyModeLabel(String? rawMode, List<_JourneyStop> stops) {
    final normalized = rawMode?.trim().toLowerCase();
    if (normalized == 'morning') return 'Morning Journey';
    if (normalized == 'afternoon') return 'Afternoon Journey';

    final hasHomeStops = stops.any((stop) => stop.type == 'home_stop');
    if (hasHomeStops) return 'Afternoon Journey';

    return 'Morning Journey';
  }

  bool _isAfternoonJourney(String? rawMode, List<_JourneyStop> stops) {
    final normalized = rawMode?.trim().toLowerCase();
    if (normalized == 'afternoon') return true;
    if (normalized == 'morning') return false;
    return stops.any((stop) => stop.type == 'home_stop');
  }

  String _journeySessionKey(
    String? rawMode,
    int? startedAtMs,
    List<_JourneyStop> stops,
  ) {
    final mode = rawMode?.trim().toLowerCase() ?? '';
    final started = startedAtMs?.toString() ?? '';
    final stopSig = stops
        .map(
          (s) =>
              '${s.point.latitude.toStringAsFixed(5)},${s.point.longitude.toStringAsFixed(5)}:${s.type}',
        )
        .join('|');
    return '$mode|$started|$stopSig';
  }

  void _syncJourneyProgressState({
    required String? rawMode,
    required int? startedAtMs,
    required List<_JourneyStop> stops,
  }) {
    final key = _journeySessionKey(rawMode, startedAtMs, stops);
    if (key == _journeyProgressKey) return;

    _journeyProgressKey = key;
    _completedStopIndexes.clear();
    _showStopsExpanded = false;
    _activeRoutePolyline = const <LatLng>[];
    _etaMinutes = null;
    _lastRouteSignature = '';
    _lastRouteFetchAt = null;
    _lastOffRouteCheckPoint = null;
  }

  String _formatStopLabel(_JourneyStop stop, int index) {
    if (stop.label.trim().isNotEmpty) return stop.label.trim();
    switch (stop.type) {
      case 'destination':
        return 'Destination';
      case 'home_stop':
        return 'Home stop ${index + 1}';
      case 'school_stop':
        return 'School stop ${index + 1}';
      case 'checkpoint':
        return 'Via ${index + 1}';
      default:
        return 'Stop ${index + 1}';
    }
  }

  void _updateCompletedStops(LatLng currentLocation, List<_JourneyStop> stops) {
    if (stops.isEmpty) {
      _completedStopIndexes.clear();
      return;
    }

    _completedStopIndexes.removeWhere((index) => index >= stops.length);

    // Advance progress strictly in route order to avoid incorrectly
    // completing future stops (for example, depot destination in afternoon).
    var nextIndex = _nextStopIndex(stops);
    while (nextIndex >= 0 && nextIndex < stops.length) {
      final distance = _distanceMeters(currentLocation, stops[nextIndex].point);
      if (distance > _stopArrivalRadiusMeters) break;
      _completedStopIndexes.add(nextIndex);
      nextIndex = _nextStopIndex(stops);
    }
  }

  int _nextStopIndex(List<_JourneyStop> stops) {
    for (var i = 0; i < stops.length; i++) {
      if (!_completedStopIndexes.contains(i)) {
        return i;
      }
    }
    return -1;
  }

  List<_JourneyStop> _remainingStopsFrom(
    List<_JourneyStop> stops,
    int nextStopIndex,
  ) {
    if (stops.isEmpty || nextStopIndex < 0 || nextStopIndex >= stops.length) {
      return const <_JourneyStop>[];
    }
    return stops.sublist(nextStopIndex);
  }

  double _progressRatio(List<_JourneyStop> stops, int nextStopIndex) {
    if (stops.isEmpty) return 0;
    final completed = _completedStopIndexes.length;
    final current = nextStopIndex >= 0 ? 0.4 : 1.0;
    return ((completed + current) / stops.length).clamp(0.0, 1.0);
  }

  Widget _buildJourneyProgressHeader(
    List<_JourneyStop> stops,
    int nextStopIndex,
  ) {
    final progress = _progressRatio(stops, nextStopIndex);
    final completed = _completedStopIndexes.length;
    final total = stops.length;
    final canToggle = total > 0;
    final toggleIcon = _showStopsExpanded
        ? Icons.keyboard_arrow_down_rounded
        : Icons.keyboard_arrow_up_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              total == 0
                  ? 'No route stops'
                  : 'Route progress $completed/$total',
              style: TextStyle(
                color: navy.withOpacity(0.76),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: canToggle
                  ? () =>
                        setState(() => _showStopsExpanded = !_showStopsExpanded)
                  : null,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: canToggle
                      ? const Color(0x10005792)
                      : const Color(0x08001F3F),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: canToggle
                        ? const Color(0x22005792)
                        : const Color(0x12001F3F),
                  ),
                ),
                child: Icon(
                  toggleIcon,
                  size: 20,
                  color: canToggle
                      ? const Color(0xFF005792)
                      : const Color(0x55001F3F),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0x14001F3F),
            valueColor: const AlwaysStoppedAnimation<Color>(teal),
          ),
        ),
      ],
    );
  }

  Widget _buildStopsExpandedView(List<_JourneyStop> stops, int nextStopIndex) {
    if (!_showStopsExpanded || stops.isEmpty) {
      return const SizedBox.shrink();
    }

    IconData stopIconFor(_JourneyStop stop, bool isCompleted) {
      if (isCompleted) return Icons.check_circle_rounded;
      switch (stop.type) {
        case 'destination':
          return Icons.flag_rounded;
        case 'home_stop':
          return Icons.home_rounded;
        case 'school_stop':
          return Icons.school_rounded;
        case 'checkpoint':
          return Icons.alt_route_rounded;
        default:
          return Icons.place_rounded;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A005792)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(stops.length, (i) {
                final stop = stops[i];
                final isCompleted = _completedStopIndexes.contains(i);
                final isCurrent = i == nextStopIndex;
                final label = _formatStopLabel(stop, i);

                final markerColor = isCompleted
                    ? const Color(0xFF12A17E)
                    : const Color(0xFF93A2B3);
                final textColor = isCompleted
                    ? const Color(0xFF0D765D)
                    : const Color(0xFF5E6F81);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.only(
                    bottom: i == stops.length - 1 ? 0 : 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0x15005792)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0x2412A17E)
                                  : const Color(0x1693A2B3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              stopIconFor(stop, isCompleted),
                              size: 13,
                              color: markerColor,
                            ),
                          ),
                          if (i != stops.length - 1)
                            Container(
                              width: 2,
                              height: 20,
                              margin: const EdgeInsets.only(top: 2),
                              color: isCompleted
                                  ? const Color(0x6612A17E)
                                  : const Color(0x4493A2B3),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005792),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  String _routeBubbleText() {
    final eta = _etaMinutes;
    if (eta == null) return '';
    if (eta < 60) return '$eta min';
    final hours = eta ~/ 60;
    final mins = eta % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  LatLng? _routeMidpoint() {
    if (_activeRoutePolyline.length < 2) return null;
    return _activeRoutePolyline[_activeRoutePolyline.length ~/ 2];
  }

  Widget _buildMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: navy,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteLoadingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: blue),
          ),
          SizedBox(width: 8),
          Text(
            'Updating route',
            style: TextStyle(
              color: navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(icon, size: 11, color: color),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: navy.withOpacity(0.82),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLegend() {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1A001F3F)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLegendItem(
            icon: Icons.directions_car_filled_rounded,
            color: const Color(0xFF121212),
            label: 'Vehicle',
          ),
          _buildLegendItem(
            icon: Icons.location_on,
            color: const Color(0xFF2EAD5B),
            label: 'Pickup',
          ),
          _buildLegendItem(
            icon: Icons.school,
            color: const Color(0xFFFF8F00),
            label: 'School stop',
          ),
          _buildLegendItem(
            icon: Icons.flag,
            color: const Color(0xFFD62828),
            label: 'Destination',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendToggle() {
    return InkWell(
      onTap: () => setState(() => _showLegend = !_showLegend),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x1A001F3F)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          _showLegend ? Icons.close_rounded : Icons.legend_toggle_rounded,
          color: navy.withOpacity(0.85),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildBottomPanel({
    required String driverName,
    required String? driverPhone,
    required String vehicleLabel,
    required String journeyModeLabel,
    required bool isAfternoonJourney,
    required String status,
    required Color statusColor,
    required String speedLabel,
    required String updateLabel,
    required List<_JourneyStop> stops,
    required int nextStopIndex,
  }) {
    final hasNextStop = nextStopIndex >= 0 && nextStopIndex < stops.length;
    final nextStop = hasNextStop ? stops[nextStopIndex] : null;
    final shouldShowDepotReturn =
        isAfternoonJourney && nextStop?.type == 'destination';
    final nextStopLabel = hasNextStop
        ? (shouldShowDepotReturn
              ? 'Return to depot'
              : _formatStopLabel(stops[nextStopIndex], nextStopIndex))
        : 'Final destination reached';
    final compact = !_showInfoPanelExpanded;
    final compactSpeed = speedLabel.replaceFirst('Speed: ', '');

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        compact ? 10 : 12,
        14,
        compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
        border: Border.all(color: const Color(0x16005792)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x22001F3F),
            blurRadius: compact ? 14 : 20,
            offset: Offset(0, compact ? 6 : 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatEtaText(),
                    style: const TextStyle(
                      color: navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _showInfoPanelExpanded = true),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0x10005792),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x22005792)),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 19,
                      color: Color(0xFF005792),
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
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    compactSpeed,
                    style: TextStyle(
                      color: navy.withOpacity(0.80),
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '$driverName • $vehicleLabel',
                    style: TextStyle(
                      color: navy.withOpacity(0.86),
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _callDriver(driverPhone),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1A00B894),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x33008C73)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.call_rounded,
                        size: 20,
                        color: Color(0xFF008C73),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              updateLabel,
              style: TextStyle(
                color: navy.withOpacity(0.68),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Mode: $journeyModeLabel',
              style: TextStyle(
                color: navy.withOpacity(0.68),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatEtaText(),
                    style: const TextStyle(
                      color: navy,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    _showInfoPanelExpanded = false;
                    _showStopsExpanded = false;
                  }),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0x10005792),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x22005792)),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 19,
                      color: Color(0xFF005792),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildJourneyProgressHeader(stops, nextStopIndex),
            _buildStopsExpandedView(stops, nextStopIndex),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$status • $journeyModeLabel',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              speedLabel,
              style: TextStyle(
                color: navy.withOpacity(0.80),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x22005792)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place_rounded, color: blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next: $nextStopLabel',
                      style: TextStyle(
                        color: navy.withOpacity(0.92),
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '$driverName • $vehicleLabel',
                    style: TextStyle(
                      color: navy.withOpacity(0.86),
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () => _callDriver(driverPhone),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0x1A00B894),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x33008C73)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x2200B894),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.call_rounded,
                          size: 24,
                          color: Color(0xFF008C73),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              updateLabel,
              style: TextStyle(
                color: navy.withOpacity(0.68),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Mode: $journeyModeLabel',
              style: TextStyle(
                color: navy.withOpacity(0.68),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Marker> _buildMarkers({
    required LatLng driverLocation,
    required double driverHeading,
    required List<_JourneyStop> journeyStops,
    required LatLng? pickupLocation,
  }) {
    final busRotation = driverHeading * math.pi / 180;
    final routeMidpoint = _routeMidpoint();
    final bubbleText = _routeBubbleText();

    return [
      Marker(
        point: driverLocation,
        width: 40,
        height: 40,
        child: Transform.rotate(
          angle: busRotation,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
      if (routeMidpoint != null && bubbleText.isNotEmpty)
        Marker(
          point: routeMidpoint,
          width: 64,
          height: 28,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              bubbleText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      if (pickupLocation != null)
        Marker(
          point: pickupLocation,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2EAD5B), width: 1.8),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFF2EAD5B),
              size: 20,
            ),
          ),
        ),
      ...journeyStops.map((stop) {
        final isDestination = stop.type == 'destination';
        final isHomeStop = stop.type == 'home_stop';
        final isSchoolStop = stop.type == 'school_stop';
        final markerColor = isDestination
            ? const Color(0xFFD62828)
            : (isHomeStop
                  ? const Color(0xFF005792)
                  : (isSchoolStop ? const Color(0xFFFF8F00) : blue));
        final icon = isDestination
            ? Icons.flag
            : (isHomeStop
                  ? Icons.home_rounded
                  : (isSchoolStop ? Icons.school : Icons.location_on));

        return Marker(
          point: stop.point,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: markerColor, width: 1.8),
            ),
            child: Icon(icon, color: markerColor, size: 20),
          ),
        );
      }),
    ];
  }

  List<Polyline> _buildRoutePolylines(
    LatLng currentLocation,
    List<_JourneyStop> stops,
  ) {
    if (_activeRoutePolyline.length >= 2) {
      return [
        Polyline(
          points: _activeRoutePolyline,
          strokeWidth: 4.8,
          color: const Color(0xFF121212),
        ),
      ];
    }

    // Fallback while route is loading: connect current location to stops.
    final fallback = <LatLng>[currentLocation, ...stops.map((s) => s.point)];
    if (fallback.length < 2) return const <Polyline>[];

    return [
      Polyline(
        points: fallback,
        strokeWidth: 4,
        color: const Color(0x88005792),
      ),
    ];
  }

  String? _normalizedPhone(dynamic rawPhone) {
    if (rawPhone == null) return null;
    final raw = rawPhone.toString().trim();
    if (raw.isEmpty) return null;
    return raw;
  }

  void _fetchDriverPhoneFor(String driverId) {
    if (driverId.isEmpty) return;
    if (_driverPhoneCache.containsKey(driverId)) return;
    if (_driverPhoneLookupsInFlight.contains(driverId)) return;

    _driverPhoneLookupsInFlight.add(driverId);
    FirebaseFirestore.instance
        .collection('users')
        .doc(driverId)
        .get()
        .then((doc) {
          final phone = _normalizedPhone(doc.data()?['phone']);
          if (!mounted || phone == null) return;
          setState(() {
            _driverPhoneCache[driverId] = phone;
          });
        })
        .whenComplete(() {
          _driverPhoneLookupsInFlight.remove(driverId);
        });
  }

  String? _resolveDriverPhone(Map<String, dynamic> trackingData) {
    final inlinePhone = _normalizedPhone(
      trackingData['driverPhone'] ?? trackingData['phone'],
    );
    final driverId = (trackingData['driverId'] as String?)?.trim() ?? '';

    if (inlinePhone != null) {
      if (driverId.isNotEmpty) {
        _driverPhoneCache[driverId] = inlinePhone;
      }
      return inlinePhone;
    }

    if (driverId.isEmpty) return null;

    final cached = _driverPhoneCache[driverId];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    _fetchDriverPhoneFor(driverId);
    return null;
  }

  Future<void> _callDriver(String? phone) async {
    final normalized = _normalizedPhone(phone);
    if (normalized == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver phone number is not available yet.'),
        ),
      );
      return;
    }

    final dialPhone = normalized.replaceAll(' ', '');
    final dialUri = Uri(scheme: 'tel', path: dialPhone);
    final launched = await launchUrl(dialUri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open phone app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Children')
            .doc(widget.childId)
            .snapshots(),
        builder: (context, childSnapshot) {
          if (childSnapshot.hasError) {
            return _buildMessage('Unable to load child data.');
          }
          if (!childSnapshot.hasData || !childSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final childData = childSnapshot.data!.data();
          final vanId = (childData?['vanId'] as String?)?.trim();
          final pickupLocation = _toLatLng(childData?['pickupLocation']);

          if (vanId == null || vanId.isEmpty) {
            return _buildMessage('No vehicle assigned to this child yet.');
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('vehicles')
                .doc(vanId)
                .snapshots(),
            builder: (context, vehicleSnapshot) {
              if (vehicleSnapshot.hasError) {
                return _buildMessage('Unable to load vehicle details.');
              }
              if (!vehicleSnapshot.hasData || !vehicleSnapshot.data!.exists) {
                return _buildMessage('Vehicle data not found.');
              }

              final vehicleData = vehicleSnapshot.data!.data();
              final vehicleLabel =
                  (vehicleData?['registerNumber'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? (vehicleData!['registerNumber'] as String).trim()
                  : vanId;
              final startingLocation = _toLatLng(
                vehicleData?['startingLocation'],
              );

              return StreamBuilder<DatabaseEvent>(
                stream: _database.ref('liveTracking/$vanId').onValue,
                builder: (context, trackingSnapshot) {
                  final rawTracking = trackingSnapshot.data?.snapshot.value;
                  final trackingData = _asMap(rawTracking);

                  final liveLat = (trackingData['lat'] as num?)?.toDouble();
                  final liveLng = (trackingData['lng'] as num?)?.toDouble();
                  final rawDriverLocation = (liveLat != null && liveLng != null)
                      ? LatLng(liveLat, liveLng)
                      : (startingLocation ??
                            pickupLocation ??
                            _defaultLocation);

                  final headingRaw =
                      (trackingData['heading'] as num?)?.toDouble() ??
                      (trackingData['bearing'] as num?)?.toDouble() ??
                      (trackingData['course'] as num?)?.toDouble();

                  final driverLocation = _consumeIncomingDriverLocation(
                    rawDriverLocation,
                    heading: headingRaw,
                  );

                  final journeyModeRaw =
                      (trackingData['journeyMode'] as String?)?.trim();
                  final routeOrderVersionRaw =
                      (trackingData['routeOrderVersion'] as String?)?.trim();
                  final rawJourneyStops = _extractJourneyStops(
                    trackingData['routeSnapshot'],
                  );
                  final journeyStops = _stopsForJourneyMode(
                    rawJourneyStops,
                    journeyModeRaw,
                    routeOrderVersionRaw,
                  );
                  final startedAtMs = (trackingData['startedAt'] as num?)
                      ?.toInt();
                  _syncJourneyProgressState(
                    rawMode: journeyModeRaw,
                    startedAtMs: startedAtMs,
                    stops: journeyStops,
                  );
                  _updateCompletedStops(driverLocation, journeyStops);
                  final nextStopIndex = _nextStopIndex(journeyStops);
                  final remainingStops = _remainingStopsFrom(
                    journeyStops,
                    nextStopIndex,
                  );
                  _scheduleRouteRefresh(driverLocation, remainingStops);

                  final driverName =
                      (trackingData['driverName'] as String?)
                              ?.trim()
                              .isNotEmpty ==
                          true
                      ? (trackingData['driverName'] as String).trim()
                      : 'Driver';
                  final driverPhone = _resolveDriverPhone(trackingData);
                  final statusRaw =
                      (trackingData['journeyStatus'] as String?)?.trim() ??
                      'waiting';
                  final updatedAtMs = (trackingData['updatedAt'] as num?)
                      ?.toInt();
                  final isStale = _isConnectionStale(updatedAtMs);
                  final statusLabel = _statusLabel(statusRaw, isStale);
                  final statusColor = _statusColor(statusRaw, isStale);
                  final journeyModeLabel = _journeyModeLabel(
                    journeyModeRaw,
                    journeyStops,
                  );
                  final isAfternoonJourney = _isAfternoonJourney(
                    journeyModeRaw,
                    journeyStops,
                  );
                  final speed = (trackingData['speedKmph'] as num?)?.toDouble();
                  final speedLabel = speed == null
                      ? 'Speed: N/A'
                      : 'Speed: ${speed.toStringAsFixed(1)} km/h';
                  final updateLabel = _formatLastUpdated(updatedAtMs);

                  _scheduleCameraFollow(driverLocation);

                  return Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: driverLocation,
                          initialZoom: 14,
                          onMapReady: () {
                            _isMapReady = true;
                            final pending = _pendingCameraTarget;
                            if (pending != null) {
                              _pendingCameraTarget = null;
                              _moveCameraIfNeeded(pending);
                            }
                          },
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: MapboxConfig.tileUrlTemplate,
                            userAgentPackageName: 'com.school.van.app',
                          ),
                          PolylineLayer(
                            polylines: _buildRoutePolylines(
                              driverLocation,
                              remainingStops,
                            ),
                          ),
                          MarkerLayer(
                            markers: _buildMarkers(
                              driverLocation: driverLocation,
                              driverHeading: _driverHeading,
                              journeyStops: journeyStops,
                              pickupLocation: pickupLocation,
                            ),
                          ),
                        ],
                      ),
                      if (!MapboxConfig.isConfigured)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xE6FFF4E5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFB14A),
                              ),
                            ),
                            child: const Text(
                              'Mapbox token is not set. Add --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_TOKEN to use Mapbox tiles.',
                              style: TextStyle(
                                color: Color(0xFF6B3F00),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: MapboxConfig.isConfigured ? 14 : 74,
                        right: 16,
                        child: _isRouteLoading
                            ? _buildRouteLoadingPill()
                            : const SizedBox.shrink(),
                      ),
                      Positioned(
                        top: MapboxConfig.isConfigured ? 14 : 106,
                        left: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendToggle(),
                            if (_showLegend) ...[
                              const SizedBox(height: 8),
                              _buildMapLegend(),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: _buildBottomPanel(
                          driverName: driverName,
                          driverPhone: driverPhone,
                          vehicleLabel: vehicleLabel,
                          journeyModeLabel: journeyModeLabel,
                          isAfternoonJourney: isAfternoonJourney,
                          status: statusLabel,
                          statusColor: statusColor,
                          speedLabel: speedLabel,
                          updateLabel: updateLabel,
                          stops: journeyStops,
                          nextStopIndex: nextStopIndex,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _JourneyStop {
  final LatLng point;
  final String label;
  final String type;

  const _JourneyStop({
    required this.point,
    required this.label,
    required this.type,
  });
}
