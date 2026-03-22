import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapboxConfig {
  const MapboxConfig._();

  static String get accessToken => dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  static String get styleId =>
      dotenv.env['MAPBOX_STYLE_ID'] ?? 'mapbox/light-v11';

  static bool get isConfigured => accessToken.trim().isNotEmpty;

  static String get tileUrlTemplate {
    final token = accessToken.trim();
    if (token.isEmpty) {
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }

    return 'https://api.mapbox.com/styles/v1/$styleId/tiles/512/{z}/{x}/{y}@2x?access_token=$token';
  }
}
