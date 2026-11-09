import 'dart:math' as math;

class SolarPositionResult {
  final double elevationDeg;
  final double azimuthDeg;
  final double declinationDeg;
  final String sunriseTime;
  final String solarNoonTime;
  final String sunsetTime;
  final String goldenHourEvening;
  final double dayLengthHours;
  final double moonIlluminationPercent;
  final double shadowLengthMeters;
  final double optimalPvTiltDeg;
  final double minPvRowSpacingMeters;

  const SolarPositionResult({
    required this.elevationDeg,
    required this.azimuthDeg,
    required this.declinationDeg,
    required this.sunriseTime,
    required this.solarNoonTime,
    required this.sunsetTime,
    required this.goldenHourEvening,
    required this.dayLengthHours,
    required this.moonIlluminationPercent,
    required this.shadowLengthMeters,
    required this.optimalPvTiltDeg,
    required this.minPvRowSpacingMeters,
  });
}

class CityLocationPreset {
  final String name;
  final double latitude;
  final double longitude;

  const CityLocationPreset(this.name, this.latitude, this.longitude);

  static const List<CityLocationPreset> presets = [
    CityLocationPreset('Madrid, ES', 40.4168, -3.7038),
    CityLocationPreset('CDMX, MX', 19.4326, -99.1332),
    CityLocationPreset('Bogotá, CO', 4.7110, -74.0721),
    CityLocationPreset('Santiago, CL', -33.4489, -70.6693),
    CityLocationPreset('Buenos Aires, AR', -34.6037, -58.3816),
    CityLocationPreset('São Paulo, BR', -23.5505, -46.6333),
    CityLocationPreset('Miami, US', 25.7617, -80.1918),
    CityLocationPreset('Lima, PE', -12.0464, -77.0428),
  ];
}

class SolarCalculator {
  static double _degToRad(double deg) => deg * math.pi / 180.0;
  static double _radToDeg(double rad) => rad * 180.0 / math.pi;

  /// Computes exact solar geometry for given latitude, dayOfYear (1..365),
  /// solarHour (0.0..24.0), and obstacle height in meters.
  static SolarPositionResult calculate({
    required double latitude,
    required double longitude,
    required int dayOfYear,
    required double solarHour,
    double objectHeightMeters = 3.0,
  }) {
    final clampedLat = latitude.clamp(-66.0, 66.0);
    final latRad = _degToRad(clampedLat);

    // Cooper's solar declination equation
    final declinationDeg =
        23.45 * math.sin(_degToRad((360.0 / 365.0) * (284 + dayOfYear)));
    final decRad = _degToRad(declinationDeg);

    // Hour angle (degrees, 0 at solar noon 12:00, 15 deg per hour)
    final hourAngleDeg = (solarHour - 12.0) * 15.0;
    final hourAngleRad = _degToRad(hourAngleDeg);

    // Solar elevation angle
    final sinEl = math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(hourAngleRad);
    final elevationRad = math.asin(sinEl.clamp(-1.0, 1.0));
    final elevationDeg = _radToDeg(elevationRad);

    // Solar azimuth angle (0 = North, 90 = East, 180 = South, 270 = West)
    final cosEl = math.cos(elevationRad);
    double azimuthDeg = 180.0;
    if (cosEl.abs() > 1e-5) {
      final cosAz = ((math.sin(decRad) - math.sin(latRad) * sinEl) /
              (math.cos(latRad) * cosEl))
          .clamp(-1.0, 1.0);
      final baseAz = _radToDeg(math.acos(cosAz));
      azimuthDeg = solarHour <= 12.0 ? baseAz : (360.0 - baseAz);
    }

    // Sunrise & Sunset hour angle
    final cosOmega0 = (-math.tan(latRad) * math.tan(decRad)).clamp(-0.99, 0.99);
    final omega0Deg = _radToDeg(math.acos(cosOmega0));
    final halfDayHours = omega0Deg / 15.0;
    final dayLengthHours = halfDayHours * 2.0;

    final sunriseH = (12.0 - halfDayHours).clamp(0.0, 23.99);
    final sunsetH = (12.0 + halfDayHours).clamp(0.0, 23.99);
    final goldenH = (sunsetH - 0.85).clamp(0.0, 23.99);

    // Shadow length calculation
    double shadowLength = 0.0;
    if (elevationDeg > 1.0) {
      shadowLength = objectHeightMeters / math.tan(_degToRad(elevationDeg));
    } else if (elevationDeg > 0.0) {
      shadowLength = objectHeightMeters * 57.3;
    }

    // Optimal fixed PV tilt angle (approx |Lat| * 0.87 + 3.1 deg)
    final optimalTilt = (clampedLat.abs() * 0.87 + 3.1).clamp(10.0, 60.0);

    // Minimum inter-row PV spacing for winter solstice at 10:00 AM
    final winterSolsticeSunEl = (90.0 - clampedLat.abs() - 23.45).clamp(12.0, 85.0);
    final panelProjectionHeight =
        objectHeightMeters * math.sin(_degToRad(optimalTilt));
    final minRowSpacing = panelProjectionHeight /
        math.tan(_degToRad(winterSolsticeSunEl));

    // Synodic lunar illumination approximation (29.53 day cycle)
    final lunarCyclePhase = ((dayOfYear % 29.53) / 29.53) * 2 * math.pi;
    final moonIllum = ((1.0 - math.cos(lunarCyclePhase)) / 2.0) * 100.0;

    return SolarPositionResult(
      elevationDeg: elevationDeg,
      azimuthDeg: azimuthDeg,
      declinationDeg: declinationDeg,
      sunriseTime: _formatHour(sunriseH),
      solarNoonTime: '12:00',
      sunsetTime: _formatHour(sunsetH),
      goldenHourEvening: '${_formatHour(goldenH)} - ${_formatHour(sunsetH)}',
      dayLengthHours: dayLengthHours,
      moonIlluminationPercent: moonIllum,
      shadowLengthMeters: shadowLength,
      optimalPvTiltDeg: optimalTilt,
      minPvRowSpacingMeters: minRowSpacing,
    );
  }

  /// Generates hourly trajectory points (azimuth, elevation) from 5:00 to 20:00
  static List<SolarPositionResult> calculateDailyArc({
    required double latitude,
    required double longitude,
    required int dayOfYear,
  }) {
    final List<SolarPositionResult> pts = [];
    for (double h = 5.0; h <= 20.0; h += 0.5) {
      pts.add(calculate(
        latitude: latitude,
        longitude: longitude,
        dayOfYear: dayOfYear,
        solarHour: h,
      ));
    }
    return pts;
  }

  static String _formatHour(double h) {
    final hrs = h.floor();
    final mins = ((h - hrs) * 60).round().clamp(0, 59);
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }
}
