import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 13,
  );

  @override
  void dispose() {
    nameController.dispose();
    schoolController.dispose();
    mapController?.dispose();
    super.dispose();
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
        const SnackBar(content: Text("Please select a pickup location on the map")),
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

            // School Field
            TextField(
              controller: schoolController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.school_outlined, color: blue),
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
              ),
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
                                setState(() => selectedLocation = position);
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
                                infoWindow:
                                    const InfoWindow(title: "Pickup Point"),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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