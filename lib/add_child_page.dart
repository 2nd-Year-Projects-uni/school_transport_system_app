import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AddChildPage extends StatefulWidget {
  const AddChildPage({super.key});

  @override
  State<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends State<AddChildPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController schoolController = TextEditingController();
  final TextEditingController pickupSearchController = TextEditingController();

  bool loading = false;
  bool mapReady = false;
  bool _fetchingCurrentLocation = false;
  bool _resolvingPickupPlace = false;
  LatLng? selectedLocation;
  String? _selectedSchool;
  GoogleMapController? mapController;
  final String _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  final String parentId = FirebaseAuth.instance.currentUser!.uid;

  static String get _googlePlacesApiKey =>
      dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
  List<_PlaceSuggestion> _schoolSuggestions = [];
  List<_PlaceSuggestion> _pickupSuggestions = [];
  Timer? _schoolSearchTimer;
  Timer? _pickupSearchTimer;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 13,
  );

  @override
  void dispose() {
    nameController.dispose();
    schoolController.dispose();
    pickupSearchController.dispose();
    mapController?.dispose();
    _schoolSearchTimer?.cancel();
    _pickupSearchTimer?.cancel();
    super.dispose();
  }

  Future<List<_PlaceSuggestion>> _fetchSchoolSuggestions(String query) async {
    final String trimmedQuery = query.trim();
    if (_googlePlacesApiKey.isEmpty || trimmedQuery.length < 2) return [];

    try {
      final Uri newApiUri = Uri.https(
        'places.googleapis.com',
        '/v1/places:autocomplete',
      );
      final Map<String, dynamic> payload = {
        'input': trimmedQuery,
        'languageCode': 'en',
        'regionCode': 'lk',
        'includedRegionCodes': ['lk'],
        'includedPrimaryTypes': ['school'],
      };

      final http.Response newApiResponse = await http.post(
        newApiUri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googlePlacesApiKey,
          'X-Goog-FieldMask':
              'suggestions.placePrediction.place,suggestions.placePrediction.text.text',
        },
        body: jsonEncode(payload),
      );

      if (newApiResponse.statusCode == 200) {
        final decoded = jsonDecode(newApiResponse.body) as Map<String, dynamic>;
        final suggestions = decoded['suggestions'] as List<dynamic>? ?? [];
        final mapped = suggestions
            .map((item) {
              final placePrediction =
                  (item as Map<String, dynamic>)['placePrediction']
                      as Map<String, dynamic>? ??
                  {};
              final text =
                  placePrediction['text'] as Map<String, dynamic>? ?? {};
              final placePath = placePrediction['place'] as String? ?? '';
              return _PlaceSuggestion(
                description: text['text'] as String? ?? '',
                placeId: placePath.startsWith('places/')
                    ? placePath.substring('places/'.length)
                    : placePath,
              );
            })
            .where((s) => s.description.isNotEmpty)
            .take(5)
            .toList();

        if (mapped.isNotEmpty) return mapped;
      }
    } catch (_) {}

    // Fallback to legacy endpoint
    final Uri legacyUri =
        Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
          'input': trimmedQuery,
          'key': _googlePlacesApiKey,
          'types': 'establishment',
          'components': 'country:lk',
          'region': 'lk',
        });

    final legacyResponse = await http.get(legacyUri);
    if (legacyResponse.statusCode != 200) return [];

    final decodedLegacy =
        jsonDecode(legacyResponse.body) as Map<String, dynamic>;
    final status = decodedLegacy['status'] as String? ?? 'UNKNOWN_ERROR';
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];

    final predictions = decodedLegacy['predictions'] as List<dynamic>? ?? [];
    return predictions
        .map((item) {
          final p = item as Map<String, dynamic>;
          return _PlaceSuggestion(
            description: p['description'] as String? ?? '',
            placeId: p['place_id'] as String? ?? '',
          );
        })
        .take(5)
        .toList();
  }

  Future<List<_PlaceSuggestion>> _fetchPickupSuggestions(String query) async {
    final String trimmedQuery = query.trim();
    if (_googlePlacesApiKey.isEmpty || trimmedQuery.length < 2) return [];

    try {
      final Uri newApiUri = Uri.https(
        'places.googleapis.com',
        '/v1/places:autocomplete',
      );
      final Map<String, dynamic> payload = {
        'input': trimmedQuery,
        'languageCode': 'en',
        'regionCode': 'lk',
        'includedRegionCodes': ['lk'],
      };

      final http.Response newApiResponse = await http.post(
        newApiUri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googlePlacesApiKey,
          'X-Goog-FieldMask':
              'suggestions.placePrediction.place,suggestions.placePrediction.text.text',
        },
        body: jsonEncode(payload),
      );

      if (newApiResponse.statusCode == 200) {
        final decoded = jsonDecode(newApiResponse.body) as Map<String, dynamic>;
        final suggestions = decoded['suggestions'] as List<dynamic>? ?? [];
        final mapped = suggestions
            .map((item) {
              final placePrediction =
                  (item as Map<String, dynamic>)['placePrediction']
                      as Map<String, dynamic>? ??
                  {};
              final text =
                  placePrediction['text'] as Map<String, dynamic>? ?? {};
              final placePath = placePrediction['place'] as String? ?? '';
              return _PlaceSuggestion(
                description: text['text'] as String? ?? '',
                placeId: placePath.startsWith('places/')
                    ? placePath.substring('places/'.length)
                    : placePath,
              );
            })
            .where((s) => s.description.isNotEmpty)
            .take(5)
            .toList();

        if (mapped.isNotEmpty) return mapped;
      }
    } catch (_) {}

    final Uri legacyUri =
        Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
          'input': trimmedQuery,
          'key': _googlePlacesApiKey,
          'components': 'country:lk',
          'region': 'lk',
        });

    final legacyResponse = await http.get(legacyUri);
    if (legacyResponse.statusCode != 200) return [];

    final decodedLegacy =
        jsonDecode(legacyResponse.body) as Map<String, dynamic>;
    final status = decodedLegacy['status'] as String? ?? 'UNKNOWN_ERROR';
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];

    final predictions = decodedLegacy['predictions'] as List<dynamic>? ?? [];
    return predictions
        .map((item) {
          final p = item as Map<String, dynamic>;
          return _PlaceSuggestion(
            description: p['description'] as String? ?? '',
            placeId: p['place_id'] as String? ?? '',
          );
        })
        .take(5)
        .toList();
  }

  Future<LatLng?> _fetchPlaceCoordinates(String placeId) async {
    if (_googlePlacesApiKey.isEmpty || placeId.isEmpty) return null;

    try {
      final Uri newApiUri = Uri.https(
        'places.googleapis.com',
        '/v1/places/$placeId',
      );
      final http.Response newApiResponse = await http.get(
        newApiUri,
        headers: {
          'X-Goog-Api-Key': _googlePlacesApiKey,
          'X-Goog-FieldMask': 'location',
        },
      );

      if (newApiResponse.statusCode == 200) {
        final decoded = jsonDecode(newApiResponse.body) as Map<String, dynamic>;
        final location = decoded['location'] as Map<String, dynamic>?;
        final latitude = location?['latitude'];
        final longitude = location?['longitude'];
        if (latitude is num && longitude is num) {
          return LatLng(latitude.toDouble(), longitude.toDouble());
        }
      }
    } catch (_) {}

    final Uri legacyUri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry/location',
        'key': _googlePlacesApiKey,
      },
    );

    final legacyResponse = await http.get(legacyUri);
    if (legacyResponse.statusCode != 200) return null;

    final decodedLegacy =
        jsonDecode(legacyResponse.body) as Map<String, dynamic>;
    final status = decodedLegacy['status'] as String? ?? 'UNKNOWN_ERROR';
    if (status != 'OK') return null;

    final location =
        ((decodedLegacy['result'] as Map<String, dynamic>?)?['geometry']
                as Map<String, dynamic>?)?['location']
            as Map<String, dynamic>?;
    final lat = location?['lat'];
    final lng = location?['lng'];
    if (lat is num && lng is num) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }
    return null;
  }

  void _onSchoolChanged(String value) {
    if (mounted) {
      setState(() {
        _selectedSchool = null;
        if (value.trim().isEmpty) {
          _schoolSuggestions = [];
        }
      });
    }

    _schoolSearchTimer?.cancel();
    if (value.trim().isEmpty) return;

    _schoolSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _fetchSchoolSuggestions(value);
      if (!mounted) return;
      setState(() => _schoolSuggestions = suggestions);
    });
  }

  void _clearSchoolInput() {
    setState(() {
      schoolController.clear();
      _selectedSchool = null;
      _schoolSuggestions = [];
    });
  }

  void _onPickupSearchChanged(String value) {
    if (mounted) {
      setState(() {
        if (value.trim().isEmpty) {
          _pickupSuggestions = [];
        }
      });
    }

    _pickupSearchTimer?.cancel();
    if (value.trim().isEmpty) return;

    _pickupSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _fetchPickupSuggestions(value);
      if (!mounted) return;
      setState(() => _pickupSuggestions = suggestions);
    });
  }

  void _clearPickupSearchInput() {
    pickupSearchController.clear();
    _pickupSuggestions = [];
  }

  Future<void> _selectPickupSuggestion(_PlaceSuggestion suggestion) async {
    if (_resolvingPickupPlace) return;

    setState(() => _resolvingPickupPlace = true);
    try {
      final LatLng? coordinates = await _fetchPlaceCoordinates(
        suggestion.placeId,
      );
      if (!mounted) return;

      if (coordinates == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to resolve selected place")),
        );
        return;
      }

      setState(() {
        selectedLocation = coordinates;
        pickupSearchController.text = suggestion.description;
        _pickupSuggestions = [];
      });

      if (mapController != null) {
        unawaited(
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(coordinates, 16),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pickup location selected from search")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to select pickup place")),
      );
    } finally {
      if (mounted) setState(() => _resolvingPickupPlace = false);
    }
  }

  Future<void> _openFullScreenMapPicker() async {
    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenMapPicker(
          initialLocation: selectedLocation,
          fallbackCameraPosition: _initialPosition,
        ),
      ),
    );

    if (!mounted || pickedLocation == null) return;
    setState(() {
      selectedLocation = pickedLocation;
      _clearPickupSearchInput();
    });

    if (mapController != null) {
      unawaited(
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(pickedLocation, 16),
        ),
      );
    }
  }

  Future<void> _setCurrentLocation() async {
    if (_fetchingCurrentLocation) return;

    setState(() => _fetchingCurrentLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location services")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required")),
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        selectedLocation = LatLng(position.latitude, position.longitude);
        _clearPickupSearchInput();
      });

      if (mapController != null) {
        unawaited(
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(selectedLocation!, 16),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current location selected")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get current location")),
      );
    } finally {
      if (mounted) setState(() => _fetchingCurrentLocation = false);
    }
  }

  Future<void> saveStudent() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a child name")),
      );
      return;
    }

    if (_selectedSchool == null ||
        _selectedSchool != schoolController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select a valid school from the dropdown suggestions",
          ),
        ),
      );
      return;
    }

    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please set a pickup location by search, map selection, or current location",
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance.collection('Children').add({
        'name': nameController.text.trim(),
        'school': schoolController.text.trim(),
        'parentId': parentId,
        'pickupLocation': GeoPoint(
          selectedLocation!.latitude,
          selectedLocation!.longitude,
        ),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to add child")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    const Color navy = Color(0xFF001F3F);
    const Color blue = Color(0xFF005792);

    return InputDecoration(
      prefixIcon: Icon(icon, color: blue),
      labelText: label,
      labelStyle: const TextStyle(color: blue),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: blue, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: blue.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: navy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF001F3F);
    const Color blue = Color(0xFF005792);
    const Color teal = Color(0xFF00B894);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add Child",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Text(
              "Add Child Details",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: navy,
                letterSpacing: 0.2,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Set child info and pickup location",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: blue.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Child Name Field
            TextField(
              controller: nameController,
              decoration: _inputDecoration('Child Name', Icons.person_outline),
            ),
            const SizedBox(height: 16),

            // School Field with Places Autocomplete
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: schoolController,
                  decoration: _inputDecoration('School', Icons.school_outlined)
                      .copyWith(
                        suffixIcon: schoolController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.grey,
                                ),
                                onPressed: _clearSchoolInput,
                              )
                            : null,
                      ),
                  onChanged: _onSchoolChanged,
                ),
                if (_schoolSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: blue.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _schoolSuggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (context, index) {
                        final suggestion = _schoolSuggestions[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.school_outlined,
                            color: Color(0xFF005792),
                            size: 20,
                          ),
                          title: Text(
                            suggestion.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedSchool = suggestion.description;
                              schoolController.text = suggestion.description;
                              _schoolSuggestions = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),

            // Map Section Label
            const Text(
              "Pickup Location",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Search, select on map, or share current location",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: pickupSearchController,
              onChanged: _onPickupSearchChanged,
              decoration: _inputDecoration('Search pickup place', Icons.search)
                  .copyWith(
                    suffixIcon: _resolvingPickupPlace
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (pickupSearchController.text.trim().isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      pickupSearchController.clear();
                                      _pickupSuggestions = [];
                                    });
                                  },
                                )
                              : null),
                  ),
            ),
            if (_pickupSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: blue.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _pickupSuggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (context, index) {
                    final suggestion = _pickupSuggestions[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.place_outlined,
                        color: Color(0xFF005792),
                        size: 20,
                      ),
                      title: Text(
                        suggestion.description,
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () => _selectPickupSuggestion(suggestion),
                    );
                  },
                ),
              ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openFullScreenMapPicker,
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  side: BorderSide(color: teal, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.fullscreen),
                label: const Text('Open Full-Screen Map Picker'),
              ),
            ),
            const SizedBox(height: 10),

            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: _initialPosition,
                      onMapCreated: (controller) {
                        mapController = controller;
                        if (mounted) {
                          setState(() => mapReady = true);
                        }
                      },
                      onTap: mapReady
                          ? (LatLng position) {
                              if (mounted) {
                                setState(() {
                                  selectedLocation = position;
                                  _clearPickupSearchInput();
                                });
                              }
                            }
                          : null,
                      markers: selectedLocation != null
                          ? {
                              Marker(
                                markerId: const MarkerId('pickup'),
                                position: selectedLocation!,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueBlue,
                                ),
                                infoWindow: const InfoWindow(
                                  title: "Pickup Point",
                                ),
                              ),
                            }
                          : {},
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                    ),

                    // Loading overlay until map is ready
                    if (!mapReady)
                      Container(
                        color: Colors.white,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF005792),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Show selected coordinates
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: navy, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedLocation == null
                          ? "Lat: ---, Lng: ---"
                          : "Lat: ${selectedLocation!.latitude.toStringAsFixed(5)}, "
                                "Lng: ${selectedLocation!.longitude.toStringAsFixed(5)}",
                      style: const TextStyle(color: navy, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fetchingCurrentLocation
                    ? null
                    : _setCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: _fetchingCurrentLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  selectedLocation == null
                      ? "Share Current Location"
                      : "Refresh Current Location",
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: loading ? null : saveStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 6,
                  shadowColor: navy.withOpacity(0.18),
                ),
                child: loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : const Text(
                        "Save",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  final String description;
  final String placeId;
  const _PlaceSuggestion({required this.description, required this.placeId});
}

class _FullScreenMapPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final CameraPosition fallbackCameraPosition;

  const _FullScreenMapPicker({
    required this.initialLocation,
    required this.fallbackCameraPosition,
  });

  @override
  State<_FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<_FullScreenMapPicker> {
  LatLng? _pickedLocation;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF001F3F);
    final CameraPosition initialCamera = _pickedLocation != null
        ? CameraPosition(target: _pickedLocation!, zoom: 16)
        : widget.fallbackCameraPosition;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('Select Pickup Point'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCamera,
            onTap: (LatLng position) {
              setState(() => _pickedLocation = position);
            },
            markers: _pickedLocation == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('full_screen_pickup'),
                      position: _pickedLocation!,
                      infoWindow: const InfoWindow(title: 'Pickup Point'),
                    ),
                  },
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ElevatedButton.icon(
              onPressed: _pickedLocation == null
                  ? null
                  : () => Navigator.pop(context, _pickedLocation),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.check),
              label: const Text('Use This Location'),
            ),
          ),
        ],
      ),
    );
  }
}
