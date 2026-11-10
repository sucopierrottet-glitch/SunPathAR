import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

class SolarStudyRecord {
  final String id;
  final String siteName;
  final double latitude;
  final double longitude;
  final int dayOfYear;
  final double solarHour;
  final double objectHeightMeters;
  final double elevationDeg;
  final double azimuthDeg;
  final double shadowLengthMeters;
  final double optimalTiltDeg;
  final double minRowSpacingMeters;
  final String createdAtIso;
  final String? signatureBase64;

  const SolarStudyRecord({
    required this.id,
    required this.siteName,
    required this.latitude,
    required this.longitude,
    required this.dayOfYear,
    required this.solarHour,
    required this.objectHeightMeters,
    required this.elevationDeg,
    required this.azimuthDeg,
    required this.shadowLengthMeters,
    required this.optimalTiltDeg,
    required this.minRowSpacingMeters,
    required this.createdAtIso,
    this.signatureBase64,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteName': siteName,
        'latitude': latitude,
        'longitude': longitude,
        'dayOfYear': dayOfYear,
        'solarHour': solarHour,
        'objectHeightMeters': objectHeightMeters,
        'elevationDeg': elevationDeg,
        'azimuthDeg': azimuthDeg,
        'shadowLengthMeters': shadowLengthMeters,
        'optimalTiltDeg': optimalTiltDeg,
        'minRowSpacingMeters': minRowSpacingMeters,
        'createdAtIso': createdAtIso,
        'signatureBase64': signatureBase64,
      };

  factory SolarStudyRecord.fromJson(Map<String, dynamic> json) =>
      SolarStudyRecord(
        id: json['id'] as String? ?? '1',
        siteName: json['siteName'] as String? ?? 'Solar Site',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 40.4168,
        longitude: (json['longitude'] as num?)?.toDouble() ?? -3.7038,
        dayOfYear: (json['dayOfYear'] as num?)?.toInt() ?? 172,
        solarHour: (json['solarHour'] as num?)?.toDouble() ?? 13.5,
        objectHeightMeters:
            (json['objectHeightMeters'] as num?)?.toDouble() ?? 3.0,
        elevationDeg: (json['elevationDeg'] as num?)?.toDouble() ?? 62.4,
        azimuthDeg: (json['azimuthDeg'] as num?)?.toDouble() ?? 210.0,
        shadowLengthMeters:
            (json['shadowLengthMeters'] as num?)?.toDouble() ?? 1.56,
        optimalTiltDeg: (json['optimalTiltDeg'] as num?)?.toDouble() ?? 34.0,
        minRowSpacingMeters:
            (json['minRowSpacingMeters'] as num?)?.toDouble() ?? 4.2,
        createdAtIso:
            json['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
        signatureBase64: json['signatureBase64'] as String?,
      );
}

class StorageService extends ChangeNotifier {
  static final StorageService instance = StorageService._();
  StorageService._();

  static const String _keyLocale = 'sunpath_locale';
  static const String _keyLat = 'sunpath_lat';
  static const String _keyLon = 'sunpath_lon';
  static const String _keyInspector = 'sunpath_inspector';
  static const String _keyStudies = 'sunpath_studies_v1';
  static const String _keyFirstInstallDate = 'sunpath_first_install_date';
  static const String _keyIsPro = 'sunpath_is_pro_active';

  SharedPreferences? _prefs;
  String _localeCode = 'es';
  double _latitude = 40.4168;
  double _longitude = -3.7038;
  String _inspectorName = 'Ing. Solar / Evaluador Pro';
  List<SolarStudyRecord> _studies = [];
  bool _isPro = false;
  DateTime? _firstInstallDate;

  String get localeCode => _localeCode;
  AppStrings get strings => AppStrings.get(_localeCode);
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get inspectorName => _inspectorName;
  List<SolarStudyRecord> get studies => List.unmodifiable(_studies);
  bool get isPro => _isPro;
  DateTime get firstInstallDate => _firstInstallDate ?? DateTime.now();

  /// 7-day Free Trial status
  int get trialDaysRemaining {
    if (_isPro) return 999;
    final start = _firstInstallDate ?? DateTime.now();
    final elapsedDays = DateTime.now().difference(start).inDays;
    final remaining = 7 - elapsedDays;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isTrialActive => !_isPro && trialDaysRemaining > 0;
  bool get isTrialExpired => !_isPro && trialDaysRemaining <= 0;
  bool get hasFullAccess => _isPro || isTrialActive;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _localeCode = _prefs?.getString(_keyLocale) ?? 'es';
    _latitude = _prefs?.getDouble(_keyLat) ?? 40.4168;
    _longitude = _prefs?.getDouble(_keyLon) ?? -3.7038;
    _inspectorName =
        _prefs?.getString(_keyInspector) ?? 'Ing. Solar / Evaluador Pro';
    _isPro = _prefs?.getBool(_keyIsPro) ?? false;
    final installMillis = _prefs?.getInt(_keyFirstInstallDate);
    if (installMillis == null) {
      _firstInstallDate = DateTime.now();
      await _prefs?.setInt(_keyFirstInstallDate, _firstInstallDate!.millisecondsSinceEpoch);
    } else {
      _firstInstallDate = DateTime.fromMillisecondsSinceEpoch(installMillis);
    }

    final rawStudies = _prefs?.getString(_keyStudies);
    if (rawStudies != null && rawStudies.isNotEmpty) {
      try {
        final list = jsonDecode(rawStudies) as List<dynamic>;
        _studies = list
            .map((e) => SolarStudyRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _studies = _defaultStudies();
      }
    } else {
      _studies = _defaultStudies();
    }
    notifyListeners();
  }

  List<SolarStudyRecord> _defaultStudies() {
    return [
      SolarStudyRecord(
        id: 'SP-101',
        siteName: 'Cubierta Solar Nave Industrial Sur',
        latitude: 40.4168,
        longitude: -3.7038,
        dayOfYear: 355,
        solarHour: 10.5,
        objectHeightMeters: 2.2,
        elevationDeg: 22.8,
        azimuthDeg: 156.4,
        shadowLengthMeters: 5.23,
        optimalTiltDeg: 38.2,
        minRowSpacingMeters: 4.85,
        createdAtIso: DateTime.now().toIso8601String(),
      ),
      SolarStudyRecord(
        id: 'SP-102',
        siteName: 'Terraza Residencial Hora Dorada',
        latitude: 19.4326,
        longitude: -99.1332,
        dayOfYear: 172,
        solarHour: 16.5,
        objectHeightMeters: 3.5,
        elevationDeg: 28.4,
        azimuthDeg: 278.1,
        shadowLengthMeters: 6.47,
        optimalTiltDeg: 20.0,
        minRowSpacingMeters: 2.40,
        createdAtIso: DateTime.now().toIso8601String(),
      ),
    ];
  }

  Future<void> setLocale(String code) async {
    _localeCode = code;
    await _prefs?.setString(_keyLocale, code);
    notifyListeners();
  }

  Future<void> updateSettings({
    required double latitude,
    required double longitude,
    required String inspectorName,
  }) async {
    _latitude = latitude.clamp(-66.0, 66.0);
    _longitude = longitude.clamp(-180.0, 180.0);
    _inspectorName = inspectorName.trim().isEmpty
        ? 'Ing. Solar / Evaluador Pro'
        : inspectorName.trim();
    await _prefs?.setDouble(_keyLat, _latitude);
    await _prefs?.setDouble(_keyLon, _longitude);
    await _prefs?.setString(_keyInspector, _inspectorName);
    notifyListeners();
  }

  Future<void> saveStudy(SolarStudyRecord record) async {
    _studies.insert(0, record);
    await _persistStudies();
    notifyListeners();
  }

  Future<void> deleteStudy(String id) async {
    _studies.removeWhere((e) => e.id == id);
    await _persistStudies();
    notifyListeners();
  }

  Future<void> setProStatus(bool pro) async {
    _isPro = pro;
    await _prefs?.setBool(_keyIsPro, pro);
    notifyListeners();
  }

  Future<void> _persistStudies() async {
    final encoded = jsonEncode(_studies.map((e) => e.toJson()).toList());
    await _prefs?.setString(_keyStudies, encoded);
  }
}
