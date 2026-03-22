import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'services/vehicle_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

final Color _navy = const Color(0xFF001F3F);
final Color _blue = const Color(0xFF005792);
final Color _teal = const Color(0xFF00B894);

class VehicleRegistrationPage extends StatefulWidget {
  const VehicleRegistrationPage({super.key});

  @override
  State<VehicleRegistrationPage> createState() =>
      _VehicleRegistrationPageState();
}

class _VehicleRegistrationPageState extends State<VehicleRegistrationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final VehicleService _vehicleService = VehicleService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _registerNumberController =
      TextEditingController();
  final TextEditingController _insuranceDateController =
      TextEditingController();
  final TextEditingController _startingLocationController =
      TextEditingController();

  // Route Points (optional, up to 2)
  final List<TextEditingController> _routePointControllers = [];
  final List<List<_PlaceSuggestion>> _routePointSuggestions = [[], []];
  final List<bool> _routePointConfirmed = [false, false];
  final Map<int, Timer> _routePointSearchTimers = {};

  final List<TextEditingController> _schoolControllers = [
    TextEditingController(),
  ];
  final List<List<_PlaceSuggestion>> _schoolSuggestions = [[]];
  final Map<int, Timer> _schoolSearchTimers = {};

  Timer? _startingLocationSearchTimer;
  List<_PlaceSuggestion> _startingLocationSuggestions = [];
  bool _startingLocationConfirmed = false;
  Map<String, double>? _startingLocationCoordinates;
  final List<Map<String, double>?> _routePointCoordinates = [];
  final List<bool> _schoolConfirmed = [false];
  final List<Map<String, double>?> _schoolCoordinates = [null];
  String? _selectedVehicleType;
  String? _airCondition;
  DateTime? _insuranceExpiryDate;
  XFile? _vehiclePhoto;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _registerNumberController.dispose();
    _insuranceDateController.dispose();
    _startingLocationController.dispose();
    for (final controller in _routePointControllers) {
      controller.dispose();
    }
    _startingLocationSearchTimer?.cancel();
    for (final controller in _schoolControllers) {
      controller.dispose();
    }
    for (final timer in _schoolSearchTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  bool get _canAddAnotherRoutePoint =>
      _routePointControllers.length < 2 &&
      (_routePointControllers.isEmpty ||
          _routePointControllers.last.text.trim().isNotEmpty);

  void _addRoutePointField() {
    setState(() {
      _routePointControllers.add(TextEditingController());
      _routePointSuggestions.add([]);
      _routePointConfirmed.add(false);
      _routePointCoordinates.add(null);
    });
  }

  void _removeRoutePointField(int index) {
    _routePointSearchTimers[index]?.cancel();
    _routePointSearchTimers.remove(index);
    setState(() {
      _routePointControllers[index].dispose();
      _routePointControllers.removeAt(index);
      _routePointSuggestions.removeAt(index);
      _routePointConfirmed.removeAt(index);
      _routePointCoordinates.removeAt(index);
    });
  }

  void _onRoutePointChanged(int index, String value) {
    if (index < _routePointConfirmed.length) {
      _routePointConfirmed[index] = false;
    }
    if (index < _routePointCoordinates.length) {
      _routePointCoordinates[index] = null;
    }
    _routePointSearchTimers[index]?.cancel();
    _routePointSearchTimers[index] = Timer(
      const Duration(milliseconds: 350),
      () async {
        final List<_PlaceSuggestion> suggestions = await _fetchPlaceSuggestions(
          value,
          schoolSearch: false,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          if (index < _routePointSuggestions.length) {
            _routePointSuggestions[index] = suggestions;
          }
        });
      },
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: _blue),
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: _blue),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _blue, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _blue.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _navy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );
  }

  bool get _canAddAnotherSchool =>
      _schoolControllers.isNotEmpty &&
      _schoolControllers.last.text.trim().isNotEmpty;

  Future<void> _pickVehiclePhoto() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile == null || !mounted) {
      return;
    }

    setState(() {
      _vehiclePhoto = pickedFile;
    });
  }

  Future<void> _pickInsuranceDate() async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _insuranceExpiryDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _navy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _navy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _insuranceExpiryDate = pickedDate;
      _insuranceDateController.text =
          '${pickedDate.day.toString().padLeft(2, '0')}/'
          '${pickedDate.month.toString().padLeft(2, '0')}/'
          '${pickedDate.year}';
    });
  }

  Future<List<_PlaceSuggestion>> _fetchPlaceSuggestions(
    String query, {
    required bool schoolSearch,
  }) async {
    final String trimmedQuery = query.trim();
    if (_googlePlacesApiKey.isEmpty || trimmedQuery.length < 2) {
      return [];
    }

    // Try Places API (New) first because many keys are now restricted for v1 only.
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
      if (schoolSearch) {
        payload['includedPrimaryTypes'] = <String>['school'];
      }

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
                // place path looks like "places/ChIJ..."; keep only the id part.
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
    } catch (_) {
      // Fall back to legacy endpoint below.
    }

    // Fallback to Places API (Legacy) autocomplete endpoint.
    final Uri legacyUri =
        Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
          'input': trimmedQuery,
          'key': _googlePlacesApiKey,
          'types': schoolSearch ? 'establishment' : 'geocode',
          'components': 'country:lk',
          'region': 'lk',
        });

    final http.Response legacyResponse = await http.get(legacyUri);
    if (legacyResponse.statusCode != 200) {
      return [];
    }

    final Map<String, dynamic> decodedLegacy =
        jsonDecode(legacyResponse.body) as Map<String, dynamic>;
    final String status = decodedLegacy['status'] as String? ?? 'UNKNOWN_ERROR';
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

  Future<Map<String, double>?> _fetchPlaceCoordinates(String placeId) async {
    final String trimmedPlaceId = placeId.trim();
    if (_googlePlacesApiKey.isEmpty || trimmedPlaceId.isEmpty) {
      return null;
    }

    try {
      final Uri newApiUri = Uri.https(
        'places.googleapis.com',
        '/v1/places/$trimmedPlaceId',
      );
      final http.Response newApiResponse = await http.get(
        newApiUri,
        headers: <String, String>{
          'X-Goog-Api-Key': _googlePlacesApiKey,
          'X-Goog-FieldMask': 'location',
        },
      );
      if (newApiResponse.statusCode == 200) {
        final Map<String, dynamic> decoded =
            jsonDecode(newApiResponse.body) as Map<String, dynamic>;
        final Map<String, dynamic> location =
            decoded['location'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final double? latitude = (location['latitude'] as num?)?.toDouble();
        final double? longitude = (location['longitude'] as num?)?.toDouble();
        if (latitude != null && longitude != null) {
          return <String, double>{'latitude': latitude, 'longitude': longitude};
        }
      }
    } catch (_) {
      // Fall back to legacy endpoint below.
    }

    try {
      final Uri legacyUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        <String, String>{
          'place_id': trimmedPlaceId,
          'fields': 'geometry/location',
          'key': _googlePlacesApiKey,
        },
      );
      final http.Response legacyResponse = await http.get(legacyUri);
      if (legacyResponse.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic> decodedLegacy =
          jsonDecode(legacyResponse.body) as Map<String, dynamic>;
      final String status =
          decodedLegacy['status'] as String? ?? 'UNKNOWN_ERROR';
      if (status != 'OK') {
        return null;
      }
      final Map<String, dynamic> result =
          decodedLegacy['result'] as Map<String, dynamic>? ??
          <String, dynamic>{};
      final Map<String, dynamic> geometry =
          result['geometry'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final Map<String, dynamic> location =
          geometry['location'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final double? latitude = (location['lat'] as num?)?.toDouble();
      final double? longitude = (location['lng'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return null;
      }
      return <String, double>{'latitude': latitude, 'longitude': longitude};
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _toPlaceData(
    String name,
    Map<String, double>? coordinates,
  ) {
    return <String, dynamic>{
      'name': name.trim(),
      'latitude': coordinates?['latitude'],
      'longitude': coordinates?['longitude'],
    };
  }

  void _onStartingLocationChanged(String value) {
    _startingLocationConfirmed = false;
    _startingLocationCoordinates = null;
    _startingLocationSearchTimer?.cancel();
    _startingLocationSearchTimer = Timer(
      const Duration(milliseconds: 350),
      () async {
        final List<_PlaceSuggestion> suggestions = await _fetchPlaceSuggestions(
          value,
          schoolSearch: false,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _startingLocationSuggestions = suggestions;
        });
      },
    );
  }

  void _onSchoolChanged(int index, String value) {
    if (index < _schoolConfirmed.length) {
      _schoolConfirmed[index] = false;
    }
    if (index < _schoolCoordinates.length) {
      _schoolCoordinates[index] = null;
    }
    _schoolSearchTimers[index]?.cancel();
    _schoolSearchTimers[index] = Timer(
      const Duration(milliseconds: 350),
      () async {
        final List<_PlaceSuggestion> suggestions = await _fetchPlaceSuggestions(
          value,
          schoolSearch: true,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          if (index < _schoolSuggestions.length) {
            _schoolSuggestions[index] = suggestions;
          }
        });
      },
    );
  }

  void _addSchoolField() {
    setState(() {
      _schoolControllers.add(TextEditingController());
      _schoolSuggestions.add([]);
      _schoolConfirmed.add(false);
      _schoolCoordinates.add(null);
    });
  }

  void _removeSchoolField(int index) {
    if (_schoolControllers.length == 1) {
      return;
    }

    _schoolSearchTimers[index]?.cancel();
    _schoolSearchTimers.remove(index);
    setState(() {
      _schoolControllers[index].dispose();
      _schoolControllers.removeAt(index);
      _schoolSuggestions.removeAt(index);
      _schoolConfirmed.removeAt(index);
      _schoolCoordinates.removeAt(index);
    });
  }

  Future<void> _submitVehicle() async {
    final List<Map<String, dynamic>> schools = <Map<String, dynamic>>[];
    for (int i = 0; i < _schoolControllers.length; i++) {
      final String schoolName = _schoolControllers[i].text.trim();
      if (schoolName.isEmpty) {
        continue;
      }
      final Map<String, double>? coordinates = i < _schoolCoordinates.length
          ? _schoolCoordinates[i]
          : null;
      schools.add(_toPlaceData(schoolName, coordinates));
    }

    final List<Map<String, dynamic>> routePoints = <Map<String, dynamic>>[];
    for (int i = 0; i < _routePointControllers.length; i++) {
      final String placeName = _routePointControllers[i].text.trim();
      if (placeName.isEmpty) {
        continue;
      }
      final Map<String, double>? coordinates = i < _routePointCoordinates.length
          ? _routePointCoordinates[i]
          : null;
      routePoints.add(_toPlaceData(placeName, coordinates));
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_airCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select AC or Non-AC.')),
      );
      return;
    }

    if (_insuranceExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose insurance expiry date.')),
      );
      return;
    }

    if (schools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one school.')),
      );
      return;
    }

    if (_vehiclePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a vehicle photo.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String vehicleId = await _vehicleService.registerVehicle(
        registerNumber: _registerNumberController.text,
        vehicleType: _selectedVehicleType!,
        condition: _airCondition!,
        insuranceExpiryDate: _insuranceExpiryDate!,
        startingLocation: _toPlaceData(
          _startingLocationController.text,
          _startingLocationCoordinates,
        ),
        schools: schools,
        routePoints: routePoints,
        vehiclePhoto: _vehiclePhoto!,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(vehicleId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vehicle registration failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSuggestionBox(
    List<_PlaceSuggestion> suggestions, {
    required ValueChanged<_PlaceSuggestion> onSelected,
  }) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withOpacity(0.18)),
      ),
      child: Column(
        children: suggestions.map((suggestion) {
          return ListTile(
            dense: true,
            leading: Icon(Icons.place_outlined, color: _blue),
            title: Text(suggestion.description),
            onTap: () => onSelected(suggestion),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSchoolField(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _schoolControllers[index],
                onChanged: (value) => _onSchoolChanged(index, value),
                autovalidateMode: AutovalidateMode.onUnfocus,
                decoration: _inputDecoration(
                  index == 0 ? 'School' : 'School ${index + 1}',
                  Icons.school_outlined,
                  hint: 'Search school name',
                ),
                validator: (value) {
                  if (index == 0 && (value == null || value.trim().isEmpty)) {
                    return 'Enter at least one school.';
                  }
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      index < _schoolConfirmed.length &&
                      !_schoolConfirmed[index]) {
                    return 'Select a school from the suggestions.';
                  }
                  return null;
                },
              ),
            ),
            if (index > 0) ...[
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _removeSchoolField(index),
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red.shade400,
                ),
                tooltip: 'Remove school',
              ),
            ],
          ],
        ),
        _buildSuggestionBox(
          _schoolSuggestions[index],
          onSelected: (suggestion) async {
            final Map<String, double>? coordinates =
                await _fetchPlaceCoordinates(suggestion.placeId);
            if (!mounted) {
              return;
            }
            setState(() {
              _schoolConfirmed[index] = true;
              _schoolControllers[index].text = suggestion.description;
              if (index < _schoolCoordinates.length) {
                _schoolCoordinates[index] = coordinates;
              }
              _schoolSuggestions[index] = [];
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        title: const Text('Vehicle Registration'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_navy, _blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Register your vehicle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add the vehicle details, service areas, schools, and a clear vehicle photo.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _registerNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(
                    'Vehicle register number',
                    Icons.confirmation_number_outlined,
                    hint: 'e.g. WP CAB 1234',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter vehicle register number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  dropdownColor: Colors.white,
                  iconEnabledColor: _blue,
                  focusColor: Colors.white,
                  style: TextStyle(color: _navy),
                  decoration: _inputDecoration(
                    'Vehicle type',
                    Icons.directions_bus_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Van', child: Text('Van')),
                    DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                    DropdownMenuItem(
                      value: 'Mini Bus',
                      child: Text('Mini Bus'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedVehicleType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select vehicle type.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Condition',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        value: _airCondition == 'AC',
                        onChanged: (checked) {
                          setState(() {
                            _airCondition = checked == true ? 'AC' : null;
                          });
                        },
                        title: const Text('AC'),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: _teal,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CheckboxListTile(
                        value: _airCondition == 'Non-AC',
                        onChanged: (checked) {
                          setState(() {
                            _airCondition = checked == true ? 'Non-AC' : null;
                          });
                        },
                        title: const Text('Non-AC'),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: _teal,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _insuranceDateController,
                  readOnly: true,
                  onTap: _pickInsuranceDate,
                  decoration: _inputDecoration(
                    'Insurance expiry date',
                    Icons.calendar_month_outlined,
                    hint: 'DD/MM/YYYY',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Choose insurance expiry date.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _startingLocationController,
                  onChanged: _onStartingLocationChanged,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  decoration: _inputDecoration(
                    'Starting location',
                    Icons.location_on_outlined,
                    hint: 'Search starting location',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter starting location.';
                    }
                    if (!_startingLocationConfirmed) {
                      return 'Select a location from the suggestions.';
                    }
                    return null;
                  },
                ),
                _buildSuggestionBox(
                  _startingLocationSuggestions,
                  onSelected: (suggestion) async {
                    final Map<String, double>? coordinates =
                        await _fetchPlaceCoordinates(suggestion.placeId);
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _startingLocationConfirmed = true;
                      _startingLocationController.text = suggestion.description;
                      _startingLocationCoordinates = coordinates;
                      _startingLocationSuggestions = [];
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Route Points (optional)',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...List<Widget>.generate(_routePointControllers.length, (
                  index,
                ) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _routePointControllers[index],
                                onChanged: (value) =>
                                    _onRoutePointChanged(index, value),
                                autovalidateMode: AutovalidateMode.onUnfocus,
                                decoration: _inputDecoration(
                                  'Route point ${index + 1}',
                                  Icons.alt_route_outlined,
                                  hint: 'Search place, town, or landmark',
                                ),
                                validator: (value) {
                                  if (value != null &&
                                      value.trim().isNotEmpty &&
                                      index < _routePointConfirmed.length &&
                                      !_routePointConfirmed[index]) {
                                    return 'Select a location from the suggestions.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (index > 0) ...[
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () => _removeRoutePointField(index),
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red.shade400,
                                ),
                                tooltip: 'Remove route point',
                              ),
                            ],
                          ],
                        ),
                        _buildSuggestionBox(
                          _routePointSuggestions[index],
                          onSelected: (suggestion) async {
                            final Map<String, double>? coordinates =
                                await _fetchPlaceCoordinates(
                                  suggestion.placeId,
                                );
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _routePointConfirmed[index] = true;
                              _routePointControllers[index].text =
                                  suggestion.description;
                              if (index < _routePointCoordinates.length) {
                                _routePointCoordinates[index] = coordinates;
                              }
                              _routePointSuggestions[index] = [];
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
                if (_canAddAnotherRoutePoint)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addRoutePointField,
                      icon: Icon(Icons.add_circle_outline, color: _teal),
                      label: Text(
                        'Add route point',
                        style: TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                const SizedBox(height: 16),
                Text(
                  'Schools',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...List<Widget>.generate(_schoolControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildSchoolField(index),
                  );
                }),
                if (_canAddAnotherSchool)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addSchoolField,
                      icon: Icon(Icons.add_circle_outline, color: _teal),
                      label: Text(
                        'Add another school',
                        style: TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Upload vehicle photo',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _vehiclePhoto == null ? _blue : _teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _pickVehiclePhoto,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _vehiclePhoto == null
                        ? 'Upload vehicle image'
                        : 'Vehicle image selected',
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload a clear image of the vehicle that visibly shows the vehicle register number. If the register number is not clear, admin approval may be delayed or the vehicle may not be allowed into the system.',
                          style: TextStyle(fontSize: 14, color: _navy),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_vehiclePhoto != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _teal.withOpacity(0.28)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: _teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _vehiclePhoto!.name,
                            style: TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submitVehicle,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text('Register Vehicle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({required this.description, required this.placeId});

  final String description;
  final String placeId;
}
