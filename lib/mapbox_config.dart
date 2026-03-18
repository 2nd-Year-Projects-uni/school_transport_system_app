class MapboxConfig {
  const MapboxConfig._();

  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static const String styleId = String.fromEnvironment(
    'MAPBOX_STYLE_ID',
    defaultValue: 'mapbox/light-v11',
  );

  static bool get isConfigured => accessToken.trim().isNotEmpty;

  static String get tileUrlTemplate {
    final token = accessToken.trim();
    if (token.isEmpty) {
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }

    return 'https://api.mapbox.com/styles/v1/$styleId/tiles/512/{z}/{x}/{y}@2x?access_token=$token';
  }
}
