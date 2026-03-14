import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

final Color _detailsNavy = const Color(0xFF001F3F);
final Color _detailsBlue = const Color(0xFF005792);
final Color _detailsTeal = const Color(0xFF00B894);

class VehicleOwnerVehicleDetailsPage extends StatelessWidget {
  void _showEditDialog(BuildContext context) {
    final vehicleId = vehicle['id'] ?? (vehicle['docId'] ?? null);
    if (vehicleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vehicle ID not found.')));
      return;
    }

    final List<String> initialRoutePoints =
        (vehicle['routePoints'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList();
    final List<TextEditingController> routePointControllers = List.generate(
      initialRoutePoints.length,
      (i) => TextEditingController(text: initialRoutePoints[i]),
    );
    while (routePointControllers.length < 2) {
      routePointControllers.add(TextEditingController());
    }
    final List<List<_PlaceSuggestion>> routePointSuggestions = [[], []];
    final List<bool> routePointConfirmed = [true, true];
    final Map<int, Timer> routePointSearchTimers = {};

    Future<List<_PlaceSuggestion>> _fetchPlaceSuggestions(String query) async {
      const String _googlePlacesApiKey = String.fromEnvironment(
        'GOOGLE_PLACES_API_KEY',
        defaultValue: '***REMOVED***',
      );
      final String trimmedQuery = query.trim();
      if (_googlePlacesApiKey.isEmpty || trimmedQuery.length < 2) {
        return [];
      }
      try {
        final Uri newApiUri = Uri.https(
          'places.googleapis.com',
          '/v1/places:autocomplete',
        );
        final Map<String, dynamic> payload = <String, dynamic>{
          'input': trimmedQuery,
          'languageCode': 'en',
          'regionCode': 'lk',
          'includedRegionCodes': <String>['lk'],
        };
        final http.Response newApiResponse = await http.post(
          newApiUri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _googlePlacesApiKey,
            'X-Goog-FieldMask':
                'suggestions.placePrediction.place,suggestions.placePrediction.text.text',
          },
          body: jsonEncode(payload),
        );
        if (newApiResponse.statusCode == 200) {
          final Map<String, dynamic> decoded =
              jsonDecode(newApiResponse.body) as Map<String, dynamic>;
          final List<dynamic> suggestions =
              decoded['suggestions'] as List<dynamic>? ?? [];
          final List<_PlaceSuggestion> mapped = suggestions
              .map((dynamic item) {
                final Map<String, dynamic> suggestion =
                    item as Map<String, dynamic>;
                final Map<String, dynamic> placePrediction =
                    suggestion['placePrediction'] as Map<String, dynamic>? ??
                    <String, dynamic>{};
                final Map<String, dynamic> text =
                    placePrediction['text'] as Map<String, dynamic>? ??
                    <String, dynamic>{};
                final String placePath =
                    placePrediction['place'] as String? ?? '';
                return _PlaceSuggestion(
                  description: text['text'] as String? ?? '',
                  placeId: placePath.startsWith('places/')
                      ? placePath.substring('places/'.length)
                      : placePath,
                );
              })
              .where((suggestion) => suggestion.description.isNotEmpty)
              .take(5)
              .toList();
          if (mapped.isNotEmpty) {
            return mapped;
          }
        }
      } catch (_) {}
      final Uri legacyUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': trimmedQuery,
          'key': _googlePlacesApiKey,
          'types': 'geocode',
          'components': 'country:lk',
          'region': 'lk',
        },
      );
      final http.Response legacyResponse = await http.get(legacyUri);
      if (legacyResponse.statusCode != 200) {
        return [];
      }
      final Map<String, dynamic> decodedLegacy =
          jsonDecode(legacyResponse.body) as Map<String, dynamic>;
      final String status =
          decodedLegacy['status'] as String? ?? 'UNKNOWN_ERROR';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        return [];
      }
      final List<dynamic> predictions =
          decodedLegacy['predictions'] as List<dynamic>? ?? [];
      final Iterable<_PlaceSuggestion> mappedLegacy = predictions.map((
        dynamic item,
      ) {
        final Map<String, dynamic> prediction = item as Map<String, dynamic>;
        return _PlaceSuggestion(
          description: prediction['description'] as String? ?? '',
          placeId: prediction['place_id'] as String? ?? '',
        );
      });
      return mappedLegacy.take(5).toList();
    }

    void _onRoutePointChanged(int index, String value, StateSetter setState) {
      if (index < routePointConfirmed.length) {
        routePointConfirmed[index] = false;
      }
      routePointSearchTimers[index]?.cancel();
      routePointSearchTimers[index] = Timer(
        const Duration(milliseconds: 350),
        () async {
          final List<_PlaceSuggestion> suggestions =
              await _fetchPlaceSuggestions(value);
          setState(() {
            if (index < routePointSuggestions.length) {
              routePointSuggestions[index] = suggestions;
            }
          });
        },
      );
    }

    String airCondition = vehicle['condition'] as String? ?? '';
    DateTime? insuranceExpiryDate;
    final rawDate = vehicle['insuranceExpiryDate'];
    if (rawDate is Timestamp) {
      insuranceExpiryDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      insuranceExpiryDate = rawDate;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _detailsNavy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _detailsNavy,
              secondary: _detailsBlue,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _detailsBlue),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: _detailsBlue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Edit Vehicle Details'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Route Points',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      ...List.generate(
                        2,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: routePointControllers[i],
                                onChanged: (value) =>
                                    _onRoutePointChanged(i, value, setState),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: InputDecoration(
                                  labelText: 'Route point ${i + 1}',
                                  hintText: 'Search place, town, or landmark',
                                  prefixIcon: const Icon(
                                    Icons.alt_route_outlined,
                                  ),
                                ),
                                validator: (value) {
                                  if (value != null &&
                                      value.trim().isNotEmpty &&
                                      i < routePointConfirmed.length &&
                                      !routePointConfirmed[i]) {
                                    return 'Select a location from the suggestions.';
                                  }
                                  return null;
                                },
                              ),
                              if (routePointSuggestions[i].isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _detailsBlue.withOpacity(0.18),
                                    ),
                                  ),
                                  child: Column(
                                    children: routePointSuggestions[i].map((
                                      suggestion,
                                    ) {
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.place_outlined,
                                          color: _detailsBlue,
                                        ),
                                        title: Text(suggestion.description),
                                        onTap: () {
                                          setState(() {
                                            routePointConfirmed[i] = true;
                                            routePointControllers[i].text =
                                                suggestion.description;
                                            routePointSuggestions[i] = [];
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Air Conditioning',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'AC',
                              groupValue: airCondition,
                              onChanged: (v) =>
                                  setState(() => airCondition = v ?? ''),
                              title: const Text('AC'),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'Non-AC',
                              groupValue: airCondition,
                              onChanged: (v) =>
                                  setState(() => airCondition = v ?? ''),
                              title: const Text('Non-AC'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Insurance Expiry Date',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              insuranceExpiryDate == null
                                  ? 'Not set'
                                  : '${insuranceExpiryDate?.day.toString().padLeft(2, '0')}/${insuranceExpiryDate?.month.toString().padLeft(2, '0')}/${insuranceExpiryDate?.year}',
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: insuranceExpiryDate ?? now,
                                firstDate: now,
                                lastDate: DateTime(now.year + 10),
                              );
                              if (picked != null)
                                setState(() => insuranceExpiryDate = picked);
                            },
                            child: const Text('Pick Date'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final List<String> updatedRoutePoints =
                          routePointControllers
                              .map((c) => c.text.trim())
                              .where((v) => v.isNotEmpty)
                              .toList();
                      if (airCondition.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select air conditioning.'),
                          ),
                        );
                        return;
                      }
                      if (insuranceExpiryDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pick insurance expiry date.'),
                          ),
                        );
                        return;
                      }
                      try {
                        final updateData = {
                          'routePoints': updatedRoutePoints,
                          'condition': airCondition,
                        };
                        if (insuranceExpiryDate != null) {
                          updateData['insuranceExpiryDate'] =
                              Timestamp.fromDate(insuranceExpiryDate!);
                        }
                        await FirebaseFirestore.instance
                            .collection('vehicles')
                            .doc(vehicleId)
                            .update(updateData);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vehicle updated successfully.'),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Update failed: $e')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  const VehicleOwnerVehicleDetailsPage({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    final String vehicleType = vehicle['vehicleType'] as String? ?? 'Vehicle';
    final String registerNumber =
        vehicle['registerNumber'] as String? ?? 'Not available';
    final String startingLocation =
        vehicle['startingLocation'] as String? ?? 'Not available';
    final String condition = vehicle['condition'] as String? ?? 'Not available';
    final String photoUrl = vehicle['vehiclePhotoUrl'] as String? ?? '';
    final bool isApproved = vehicle['status'] as bool? ?? false;
    final List<String> schools = (vehicle['schools'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final List<String> routePoints =
        (vehicle['routePoints'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList();
    final String insuranceExpiryDate = _formatDate(
      vehicle['insuranceExpiryDate'],
    );
    final String createdAt = _formatDate(vehicle['createdAt']);
    final Color statusColor = isApproved
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        backgroundColor: _detailsNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () => _showEditDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Vehicle',
            onPressed: () async {
              final vehicleId = vehicle['id'] ?? (vehicle['docId'] ?? null);
              if (vehicleId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vehicle ID not found.')),
                );
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: _detailsNavy,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: _detailsNavy,
                        secondary: _detailsBlue,
                      ),
                      dialogBackgroundColor: Colors.white,
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: _detailsBlue,
                        ),
                      ),
                      elevatedButtonTheme: ElevatedButtonThemeData(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _detailsBlue,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    child: AlertDialog(
                      title: const Text('Delete Vehicle'),
                      content: const Text(
                        'Are you sure you want to delete this vehicle? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Yes, Delete'),
                        ),
                      ],
                    ),
                  );
                },
              );
              if (confirmed == true) {
                try {
                  await FirebaseFirestore.instance
                      .collection('vehicles')
                      .doc(vehicleId)
                      .delete();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vehicle deleted successfully.'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: photoUrl.isEmpty
                          ? Container(
                              color: _detailsBlue.withOpacity(0.08),
                              alignment: Alignment.center,
                              child: Icon(
                                _vehicleIconForType(vehicleType),
                                size: 80,
                                color: _detailsBlue,
                              ),
                            )
                          : Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: _detailsBlue.withOpacity(0.08),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    _vehicleIconForType(vehicleType),
                                    size: 80,
                                    color: _detailsBlue,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    registerNumber,
                                    style: TextStyle(
                                      color: _detailsNavy,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    vehicleType,
                                    style: TextStyle(
                                      color: _detailsBlue,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Builder(
                                    builder: (context) {
                                      final code = vehicle['code'] as String?;
                                      if (code == null || code.isEmpty)
                                        return SizedBox.shrink();
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Code: $code',
                                            style: TextStyle(
                                              color: _detailsNavy,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.copy,
                                              size: 20,
                                              color: _detailsBlue,
                                            ),
                                            tooltip: 'Copy code',
                                            onPressed: () {
                                              Clipboard.setData(
                                                ClipboardData(text: code),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Code copied to clipboard',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isApproved ? 'Approved' : 'Pending Approval',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (vehicle['code'] != null &&
                            (vehicle['code'] as String).isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'For your security, only share this code with your designated vehicle driver. This code allows the driver to connect to your vehicle in the app. Do not share it with anyone else.',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        // Assigned drivers section (now outside the notice, but inside the main section)
                        Builder(
                          builder: (context) {
                            final List<dynamic> drivers =
                                vehicle['drivers'] as List<dynamic>? ?? [];
                            return Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Assigned Drivers:',
                                    style: TextStyle(
                                      color: _detailsBlue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...List.generate(2, (i) {
                                    if (i < drivers.length &&
                                        drivers[i] is Map &&
                                        drivers[i]['name'] != null) {
                                      return Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 18,
                                            color: _detailsBlue,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            drivers[i]['name'],
                                            style: TextStyle(
                                              color: _detailsNavy,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 18,
                                            color: Colors.blueGrey.shade400,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Driver slot available',
                                            style: TextStyle(
                                              color: Colors.blueGrey.shade400,
                                              fontStyle: FontStyle.italic,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Registration Information',
              children: [
                _InfoRow(
                  icon: Icons.directions_bus_rounded,
                  label: 'Vehicle Type',
                  value: vehicleType,
                ),
                _InfoRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Register Number',
                  value: registerNumber,
                ),
                _InfoRow(
                  icon: Icons.ac_unit_outlined,
                  label: 'Air Conditioning',
                  value: condition,
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Starting Location',
                  value: startingLocation,
                ),
                _InfoRow(
                  icon: Icons.shield_outlined,
                  label: 'Insurance Expiry',
                  value: insuranceExpiryDate,
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Submitted On',
                  value: createdAt,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Schools',
              children: [
                if (schools.isEmpty)
                  Text(
                    'No schools added.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: schools
                        .map(
                          (school) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _detailsTeal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              school,
                              style: TextStyle(
                                color: _detailsTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (routePoints.isNotEmpty)
              _SectionCard(
                title: 'Route Points',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: routePoints
                        .map(
                          (point) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _detailsBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              point,
                              style: TextStyle(
                                color: _detailsBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  IconData _vehicleIconForType(String vehicleType) {
    final String normalized = vehicleType.toLowerCase();
    if (normalized.contains('van')) {
      return Icons.airport_shuttle_outlined;
    }
    return Icons.directions_bus_filled;
  }

  String _formatDate(dynamic value) {
    DateTime? dateTime;
    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    }

    if (dateTime == null) {
      return 'Not available';
    }

    final String day = dateTime.day.toString().padLeft(2, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String year = dateTime.year.toString();
    return '$day/$month/$year';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _detailsNavy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _detailsBlue.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _detailsBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: _detailsNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Suggestion model for Google Places API ---
class _PlaceSuggestion {
  const _PlaceSuggestion({required this.description, required this.placeId});

  final String description;
  final String placeId;
}
