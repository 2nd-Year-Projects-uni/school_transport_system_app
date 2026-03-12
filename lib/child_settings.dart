import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ChildSettingsPage extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildSettingsPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildSettingsPage> createState() => _ChildSettingsPageState();
}

class _ChildSettingsPageState extends State<ChildSettingsPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController schoolController = TextEditingController();

  bool loading = false;
  bool mapReady = false;
  bool dataLoaded = false;
  LatLng? selectedLocation;
  GoogleMapController? mapController;

  static const Color blue = Color(0xFF005792);

  @override
  void initState() {
    super.initState();
    _loadChildData();
  }

  @override
  void dispose() {
    nameController.dispose();
    schoolController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadChildData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        nameController.text = data['name'] ?? '';
        schoolController.text = data['school'] ?? '';

        if (data['pickupLocation'] != null) {
          final GeoPoint gp = data['pickupLocation'];
          setState(() {
            selectedLocation = LatLng(gp.latitude, gp.longitude);
            dataLoaded = true;
          });

          // Move camera to existing pickup location
          mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(selectedLocation!, 15),
          );
        } else {
          setState(() => dataLoaded = true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load child data")),
        );
      }
    }
  }

  Future<void> _updateChild() async {
    if (nameController.text.trim().isEmpty ||
        schoolController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a pickup location")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId)
          .update({
        'name': nameController.text.trim(),
        'school': schoolController.text.trim(),
        'pickupLocation': GeoPoint(
          selectedLocation!.latitude,
          selectedLocation!.longitude,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Child info updated successfully"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update child info")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          "Edit — ${widget.childName}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: !dataLoaded
          ? const Center(child: CircularProgressIndicator(color: blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Child Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.person_outline, color: blue),
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
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Map Section
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
                    "Tap on the map to update the pickup point",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 300,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: selectedLocation ??
                                  const LatLng(6.9271, 79.8612),
                              zoom: selectedLocation != null ? 15 : 13,
                            ),
                            onMapCreated: (controller) {
                              mapController = controller;
                              if (mounted) setState(() => mapReady = true);

                              // Fly to existing location once map is ready
                              if (selectedLocation != null) {
                                controller.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                      selectedLocation!, 15),
                                );
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
                          if (!mapReady)
                            Container(
                              color: Colors.white,
                              child: const Center(
                                child: CircularProgressIndicator(color: blue),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Selected coordinates display
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
                              style: const TextStyle(
                                  color: blue, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: loading ? null : _updateChild,
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
                              "Update",
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