import 'dart:math' as math;

class SolarPositionResult {
  final double elevationDeg;
  final double azimuthDeg;
  final double declinationDeg;
  final String sunriseTime;
  final String solarNoonTime;
  final String sunsetTime;
  final String goldenHourEvening;
  final String goldenHourMorning;
  final String blueHourEvening;
  final double dayLengthHours;
  final double moonIlluminationPercent;
  final double shadowLengthMeters;
  final double optimalPvTiltDeg;
  final double minPvRowSpacingMeters;

  // Cálculos de Estilo de Vida y Salud
  final int uvIndexEstimate;
  final int safeSunMinutes;
  final bool isVitaminDOptimal;
  final String sunStatusDescription;

  const SolarPositionResult({
    required this.elevationDeg,
    required this.azimuthDeg,
    required this.declinationDeg,
    required this.sunriseTime,
    required this.solarNoonTime,
    required this.sunsetTime,
    required this.goldenHourEvening,
    required this.goldenHourMorning,
    required this.blueHourEvening,
    required this.dayLengthHours,
    required this.moonIlluminationPercent,
    required this.shadowLengthMeters,
    required this.optimalPvTiltDeg,
    required this.minPvRowSpacingMeters,
    required this.uvIndexEstimate,
    required this.safeSunMinutes,
    required this.isVitaminDOptimal,
    required this.sunStatusDescription,
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

  /// Computes exact solar geometry and lifestyle metrics
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
    
    // Golden & Blue Hour intervals
    final goldenEveStart = (sunsetH - 1.0).clamp(0.0, 23.99);
    final goldenMornEnd = (sunriseH + 1.0).clamp(0.0, 23.99);
    final blueEveEnd = (sunsetH + 0.5).clamp(0.0, 23.99);

    // Shadow length calculation
    double shadowLength = 0.0;
    if (elevationDeg > 1.0) {
      shadowLength = objectHeightMeters / math.tan(_degToRad(elevationDeg));
    } else if (elevationDeg > 0.0) {
      shadowLength = objectHeightMeters * 57.3;
    }

    // Optimal fixed PV tilt angle
    final optimalTilt = (clampedLat.abs() * 0.87 + 3.1).clamp(10.0, 60.0);

    // Minimum inter-row PV spacing for winter solstice at 10:00 AM
    final winterSolsticeSunEl = (90.0 - clampedLat.abs() - 23.45).clamp(12.0, 85.0);
    final panelProjectionHeight =
        objectHeightMeters * math.sin(_degToRad(optimalTilt));
    final minRowSpacing = panelProjectionHeight /
        math.tan(_degToRad(winterSolsticeSunEl));

    // Synodic lunar illumination approximation
    final lunarCyclePhase = ((dayOfYear % 29.53) / 29.53) * 2 * math.pi;
    final moonIllum = ((1.0 - math.cos(lunarCyclePhase)) / 2.0) * 100.0;

    // UV Index estimation from elevation: UV ≈ 12 * sin(elevation)
    int uv = 0;
    if (elevationDeg > 0) {
      uv = (12.0 * math.sin(elevationRad)).round().clamp(0, 14);
    }

    // Safe sun exposure time based on UV
    int safeMinutes = 120;
    if (uv >= 11) {
      safeMinutes = 10;
    } else if (uv >= 8) {
      safeMinutes = 15;
    } else if (uv >= 6) {
      safeMinutes = 25;
    } else if (uv >= 3) {
      safeMinutes = 45;
    }

    // Vitamin D synthesis requires solar elevation > 35-40°
    final isVitD = elevationDeg >= 38.0;

    // Friendly Sun Status Description
    String statusDesc;
    if (elevationDeg < -6.0) {
      statusDesc = 'Noche profunda • Cielo estrellado';
    } else if (elevationDeg < 0.0) {
      statusDesc = 'Crepúsculo místico • Hora Azul para fotos';
    } else if (elevationDeg < 12.0) {
      statusDesc = 'Luz cálida mágica • Hora Dorada perfecta para retratos';
    } else if (elevationDeg < 38.0) {
      statusDesc = 'Luz suave de mañana/tarde • Ideal para pasear y plantas';
    } else if (elevationDeg < 65.0) {
      statusDesc = 'Sol radiante • Ventana óptima para sintetizar Vitamina D';
    } else {
      statusDesc = 'Sol en cenit pleno • Máxima intensidad y sombras cortas';
    }

    return SolarPositionResult(
      elevationDeg: elevationDeg,
      azimuthDeg: azimuthDeg,
      declinationDeg: declinationDeg,
      sunriseTime: _formatHour(sunriseH),
      solarNoonTime: '12:00',
      sunsetTime: _formatHour(sunsetH),
      goldenHourEvening: '${_formatHour(goldenEveStart)} - ${_formatHour(sunsetH)}',
      goldenHourMorning: '${_formatHour(sunriseH)} - ${_formatHour(goldenMornEnd)}',
      blueHourEvening: '${_formatHour(sunsetH)} - ${_formatHour(blueEveEnd)}',
      dayLengthHours: dayLengthHours,
      moonIlluminationPercent: moonIllum,
      shadowLengthMeters: shadowLength,
      optimalPvTiltDeg: optimalTilt,
      minPvRowSpacingMeters: minRowSpacing,
      uvIndexEstimate: uv,
      safeSunMinutes: safeMinutes,
      isVitaminDOptimal: isVitD,
      sunStatusDescription: statusDesc,
    );
  }

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

  /// Evaluates direct sunlight hours entering a window facing [windowAzimuth] (0-360 deg).
  static WindowSunlightResult calculateWindowSunlight({
    required double windowAzimuth,
    required List<SolarPositionResult> dailyArc,
  }) {
    double hours = 0.0;
    String? firstSun;
    String? lastSun;

    for (int i = 0; i < dailyArc.length; i++) {
      final pt = dailyArc[i];
      if (pt.elevationDeg > 5.0) {
        final diff = _angularDiff(pt.azimuthDeg, windowAzimuth).abs();
        if (diff <= 72.0) {
          hours += 0.5;
          final hourVal = 5.0 + i * 0.5;
          final formatted = _formatHour(hourVal);
          firstSun ??= formatted;
          lastSun = formatted;
        }
      }
    }

    String thermalVerdict;
    String bestRoomUse;
    if (windowAzimuth >= 45 && windowAzimuth <= 135) {
      thermalVerdict = 'Sol de Mañana • Habitación Fresca por la Tarde';
      bestRoomUse = 'Ideal para dormitorios, cocina y desayuno con luz suave.';
    } else if (windowAzimuth > 135 && windowAzimuth < 225) {
      thermalVerdict = 'Sol de Mediodía / Máxima Luminosidad';
      bestRoomUse = 'Excelente para sala, balcón, terraza o secado rápido.';
    } else if (windowAzimuth >= 225 && windowAzimuth <= 315) {
      thermalVerdict = 'Sol Intenso de Tarde • Ambiente Cálido';
      bestRoomUse = 'Perfecto para ver atardeceres; en verano conviene cortina térmica.';
    } else {
      thermalVerdict = 'Luz Natural Difusa Constante (Sin Sol Directo)';
      bestRoomUse = 'Ideal para oficina en casa, estudio o pintar sin reflejos.';
    }

    return WindowSunlightResult(
      windowAzimuth: windowAzimuth,
      directSunHours: hours,
      firstSunTime: firstSun ?? '--:--',
      lastSunTime: lastSun ?? '--:--',
      thermalVerdict: thermalVerdict,
      bestRoomUse: bestRoomUse,
    );
  }

  /// Calculates camera alignment against the sun for back/front cameras and 4 photography modes:
  /// 0 = Selfie / Retrato Luz Dorada (sun in front of person -> back cam faces away from sun, front cam faces sun)
  /// 1 = Contraluz / Halo Solar (sun behind person -> back cam faces sun, front cam faces away)
  /// 2 = Capturar el Sol / Atardecer (point active lens directly toward sun)
  /// 3 = Luz Cine 45° (45 deg side light for dramatic portrait)
  static CameraAlignmentResult calculateCameraAlignment({
    required double sunAzimuth,
    required double sunElevation,
    required double deviceAzimuth,
    required double cameraElevation,
    required bool isFrontCamera,
    required int photoMode,
  }) {
    // Desired sun azimuth relative to the active camera lens direction
    double targetDeviceAzimuth;
    double targetCamElevation;

    final effectiveSunEl = sunElevation.clamp(3.0, 75.0);

    switch (photoMode) {
      case 0: // Luz Dorada en el rostro (para retratos con luz cálida)
        // Si usas cámara trasera, el fotógrafo da la espalda al sol para iluminar al modelo
        // Si usas cámara frontal (selfie), tu rostro mira hacia la pantalla -> el sol debe quedar detrás de la pantalla (frente a tu rostro) = hacia deviceAzimuth
        targetDeviceAzimuth = isFrontCamera ? sunAzimuth : (sunAzimuth + 180.0) % 360.0;
        targetCamElevation = isFrontCamera ? (effectiveSunEl * 0.45).clamp(0.0, 30.0) : 5.0;
        break;
      case 1: // Contraluz / Halo en cabello
        targetDeviceAzimuth = isFrontCamera ? (sunAzimuth + 180.0) % 360.0 : sunAzimuth;
        targetCamElevation = (effectiveSunEl * 0.7).clamp(0.0, 45.0);
        break;
      case 2: // Capturar el Sol / Paisaje directo
        targetDeviceAzimuth = isFrontCamera ? (sunAzimuth + 180.0) % 360.0 : sunAzimuth;
        targetCamElevation = effectiveSunEl;
        break;
      default: // Luz Cine Lateral 45°
        final baseAz = isFrontCamera ? sunAzimuth : (sunAzimuth + 180.0) % 360.0;
        targetDeviceAzimuth = (baseAz + 45.0) % 360.0;
        targetCamElevation = 8.0;
        break;
    }

    // Signed difference: positive means turn right (clockwise), negative means turn left
    final deltaAz = _angularDiff(targetDeviceAzimuth, deviceAzimuth);
    final deltaEl = targetCamElevation - cameraElevation;

    final azPenalty = (deltaAz.abs() / 90.0).clamp(0.0, 1.0);
    final elPenalty = (deltaEl.abs() / 45.0).clamp(0.0, 1.0);
    final score = ((1.0 - (azPenalty * 0.7 + elPenalty * 0.3)) * 100.0).round().clamp(0, 100);
    final isAligned = deltaAz.abs() <= 12.0 && deltaEl.abs() <= 14.0;

    String instruction;
    if (isAligned) {
      instruction = '¡POSICIÓN PERFECTA! Toma la foto ahora';
    } else if (deltaAz.abs() > 12.0) {
      final dir = deltaAz > 0 ? 'a la derecha' : 'a la izquierda';
      instruction = 'Gira ${deltaAz.abs().round()}° $dir';
    } else {
      final pitchDir = deltaEl > 0 ? 'Sube' : 'Baja';
      instruction = '$pitchDir el teléfono ${deltaEl.abs().round()}°';
    }

    return CameraAlignmentResult(
      targetAzimuth: targetDeviceAzimuth,
      targetElevation: targetCamElevation,
      deltaAzimuth: deltaAz,
      deltaElevation: deltaEl,
      alignmentScore: score,
      isAligned: isAligned,
      instructionText: instruction,
    );
  }

  /// Shortest signed angle (target - current) in range [-180, 180]
  static double _angularDiff(double target, double current) {
    double diff = (target - current + 540.0) % 360.0 - 180.0;
    return diff;
  }

  static String _formatHour(double h) {
    final hrs = h.floor();
    final mins = ((h - hrs) * 60).round().clamp(0, 59);
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }
}

class WindowSunlightResult {
  final double windowAzimuth;
  final double directSunHours;
  final String firstSunTime;
  final String lastSunTime;
  final String thermalVerdict;
  final String bestRoomUse;

  const WindowSunlightResult({
    required this.windowAzimuth,
    required this.directSunHours,
    required this.firstSunTime,
    required this.lastSunTime,
    required this.thermalVerdict,
    required this.bestRoomUse,
  });
}

class CameraAlignmentResult {
  final double targetAzimuth;
  final double targetElevation;
  final double deltaAzimuth;
  final double deltaElevation;
  final int alignmentScore;
  final bool isAligned;
  final String instructionText;

  const CameraAlignmentResult({
    required this.targetAzimuth,
    required this.targetElevation,
    required this.deltaAzimuth,
    required this.deltaElevation,
    required this.alignmentScore,
    required this.isAligned,
    required this.instructionText,
  });
}
