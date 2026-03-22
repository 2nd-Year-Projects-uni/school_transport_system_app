import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class AddChildPage extends StatefulWidget {
  const AddChildPage({super.key});

  @override
  State<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends State<AddChildPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController schoolController = TextEditingController();

  bool loading = false;
  bool mapReady = false;
  LatLng? selectedLocation;
  GoogleMapController? mapController;

  final String parentId = FirebaseAuth.instance.currentUser!.uid;

  static const String _googlePlacesApiKey = 'AIzaSyB14ebeB-oksOegVg0m4qQ81olRxuPRlxc';
  List<_PlaceSuggestion> _schoolSuggestions = [];
  bool _schoolConfirmed = false;
  Timer? _schoolSearchTimer;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 13,
  );

  @override
  void dispose() {
    nameController.dispose();
    schoolController.dispose();
    mapController?.dispose();
    _schoolSearchTimer?.cancel();
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
        final decoded =
            jsonDecode(newApiResponse.body) as Map<String, dynamic>;
        final suggestions = decoded['suggestions'] as List<dynamic>? ?? [];
        final mapped = suggestions.map((item) {
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
        }).where((s) => s.description.isNotEmpty).take(5).toList();

        if (mapped.isNotEmpty) return mapped;
      }
    } catch (_) {}

    // Fallback to legacy endpoint
    final Uri legacyUri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': trimmedQuery,
        'key': _googlePlacesApiKey,
        'types': 'establishment',
        'components': 'country:lk',
        'region': 'lk',
      },
    );

    final legacyResponse = await http.get(legacyUri);
    if (legacyResponse.statusCode != 200) return [];

    final decodedLegacy =
        jsonDecode(legacyResponse.body) as Map<String, dynamic>;
    final status = decodedLegacy['status'] as String? ?? 'UNKNOWN_ERROR';
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];

    final predictions =
        decodedLegacy['predictions'] as List<dynamic>? ?? [];
    return predictions.map((item) {
      final p = item as Map<String, dynamic>;
      return _PlaceSuggestion(
        description: p['description'] as String? ?? '',
        placeId: p['place_id'] as String? ?? '',
      );
    }).take(5).toList();
  }

  void _onSchoolChanged(String value) {
    _schoolConfirmed = false;
    _schoolSearchTimer?.cancel();
    _schoolSearchTimer =
        Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _fetchSchoolSuggestions(value);
      if (!mounted) return;
      setState(() => _schoolSuggestions = suggestions);
    });
  }

  Future<void> saveStudent() async {
    if (nameController.text.isEmpty || schoolController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select a pickup location on the map")),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add child")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color blue = Color(0xFF005792);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: blue,
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Child Name Field
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline, color: blue),
                labelText: 'Child Name',
                labelStyle: const TextStyle(color: blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // School Field with Places Autocomplete
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: schoolController,
                  decoration: InputDecoration(
                    prefixIcon:
                        const Icon(Icons.school_outlined, color: blue),
                    labelText: 'School',
                    labelStyle: const TextStyle(color: blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: blue),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: blue, width: 2),
                    ),
                    suffixIcon: _schoolConfirmed
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF00B894))
                        : null,
                  ),
                  onChanged: _onSchoolChanged,
                ),
                if (_schoolSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: blue.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
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
                          leading: const Icon(Icons.school_outlined,
                              color: Color(0xFF005792), size: 20),
                          title: Text(
                            suggestion.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () {
                            setState(() {
                              schoolController.text =
                                  suggestion.description;
                              _schoolSuggestions = [];
                              _schoolConfirmed = true;
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
                color: blue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Tap on the map to set the pickup point",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // Google Map with loading overlay
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
                                setState(
                                    () => selectedLocation = position);
                              }
                            }
                          : null,
                      markers: selectedLocation != null
                          ? {
                              Marker(
                                markerId: const MarkerId('pickup'),
                                position: selectedLocation!,
                                icon:
                                    BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueBlue,
                                ),
                                infoWindow: const InfoWindow(
                                    title: "Pickup Point"),
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
            if (selectedLocation != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Lat: ${selectedLocation!.latitude.toStringAsFixed(5)}, "
                        "Lng: ${selectedLocation!.longitude.toStringAsFixed(5)}",
                        style: const TextStyle(color: blue, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : saveStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                          fontSize: 16,
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
  const _PlaceSuggestion(
      {required this.description, required this.placeId});
}