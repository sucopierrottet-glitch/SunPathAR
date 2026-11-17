import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WeatherSolarData {
  final double temperatureC;
  final int cloudCoverPercent;
  final double liveUvIndex;
  final double maxUvIndexToday;
  final double directRadiationWm2;
  final double windSpeedKmh;
  final String cityName;
  final DateTime fetchedAt;

  const WeatherSolarData({
    required this.temperatureC,
    required this.cloudCoverPercent,
    required this.liveUvIndex,
    required this.maxUvIndexToday,
    required this.directRadiationWm2,
    required this.windSpeedKmh,
    required this.cityName,
    required this.fetchedAt,
  });

  int get goldenHourQualityScore {
    // Sweet spot for dramatic golden hour sunsets is 10%-45% clouds, clear sky is 85%+, overcast reduces score
    if (cloudCoverPercent <= 15) return 92;
    if (cloudCoverPercent <= 45) return 96; // Dramatic warm sky!
    if (cloudCoverPercent <= 70) return 68;
    return 35;
  }

  String get goldenHourQualityLabel {
    if (cloudCoverPercent <= 15) return 'Cielo Despejado • Luz Nítida y Pura';
    if (cloudCoverPercent <= 45) return 'Nubes Ligeras • Atardecer Espectacular';
    if (cloudCoverPercent <= 70) return 'Parcialmente Nublado • Luz Suave Difusa';
    return 'Muy Nublado • Luz Tenue / Sin Sombras Duras';
  }
}

class WeatherSolarService extends ChangeNotifier {
  static final WeatherSolarService instance = WeatherSolarService._();
  WeatherSolarService._();

  WeatherSolarData? _data;
  bool _isLoading = false;
  String? _lastError;

  WeatherSolarData? get data => _data;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> refresh({
    required double latitude,
    required double longitude,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final weatherFuture = _fetchOpenMeteo(client, latitude, longitude);
      final cityFuture = _fetchCityName(client, latitude, longitude);

      final weatherMap = await weatherFuture;
      final city = await cityFuture;

      if (weatherMap != null) {
        final current = weatherMap['current'] as Map<String, dynamic>? ?? {};
        final daily = weatherMap['daily'] as Map<String, dynamic>? ?? {};
        final dailyUv = daily['uv_index_max'] as List<dynamic>?;

        _data = WeatherSolarData(
          temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 22.0,
          cloudCoverPercent: (current['cloud_cover'] as num?)?.toInt() ?? 20,
          liveUvIndex: (current['uv_index'] as num?)?.toDouble() ?? 3.0,
          maxUvIndexToday: (dailyUv != null && dailyUv.isNotEmpty)
              ? ((dailyUv.first as num?)?.toDouble() ?? 6.0)
              : 6.0,
          directRadiationWm2:
              (current['direct_radiation'] as num?)?.toDouble() ?? 0.0,
          windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 8.0,
          cityName: city ?? '${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}',
          fetchedAt: DateTime.now(),
        );
      }
    } catch (e) {
      _lastError = 'Modo Offline';
    } finally {
      client.close(force: true);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _fetchOpenMeteo(
      HttpClient client, double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${lat.toStringAsFixed(4)}'
        '&longitude=${lon.toStringAsFixed(4)}'
        '&current=temperature_2m,cloud_cover,uv_index,is_day,direct_radiation,wind_speed_10m'
        '&daily=uv_index_max&timezone=auto&forecast_days=1',
      );
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _fetchCityName(
      HttpClient client, double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=${lat.toStringAsFixed(4)}'
        '&longitude=${lon.toStringAsFixed(4)}'
        '&localityLanguage=es',
      );
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final city = (json['city'] as String?)?.trim();
        final locality = (json['locality'] as String?)?.trim();
        final country = (json['countryCode'] as String?)?.trim();
        final place = (city != null && city.isNotEmpty) ? city : locality;
        if (place != null && place.isNotEmpty) {
          return country != null && country.isNotEmpty ? '$place, $country' : place;
        }
      }
    } catch (_) {}
    return null;
  }
}
