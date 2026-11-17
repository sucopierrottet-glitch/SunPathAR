import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SensorService extends ChangeNotifier {
  static final SensorService instance = SensorService._();
  SensorService._();

  static const MethodChannel _channel =
      MethodChannel('com.simpleappspg.sensors/data');

  Timer? _timer;
  bool _useLiveSensors = true;
  double _compassAzimuth = 180.0;
  double _devicePitch = 35.0;
  double _deviceRoll = 0.0;
  double _cameraElevation = 15.0;
  double _lightLux = 450.0;
  double _pressureHpa = 1013.25;
  double _magFieldUt = 46.5;
  bool _hasMag = false;
  bool _hasLight = false;
  bool _hasBarometer = false;

  // Native Camera Texture state
  int? _cameraTextureId;
  bool _isCameraActive = false;
  bool _isFrontCamera = false;
  int _sensorOrientation = 90;
  int _extraQuarterTurns = 0;

  bool get useLiveSensors => _useLiveSensors;
  double get compassAzimuth => _compassAzimuth;
  double get devicePitch => _devicePitch;
  double get deviceRoll => _deviceRoll;
  double get cameraElevation => _cameraElevation;
  double get lightLux => _lightLux;
  double get pressureHpa => _pressureHpa;
  double get magFieldUt => _magFieldUt;
  bool get hasMag => _hasMag;
  bool get hasLight => _hasLight;
  bool get hasBarometer => _hasBarometer;

  int? get cameraTextureId => _cameraTextureId;
  bool get isCameraActive => _isCameraActive;
  bool get isFrontCamera => _isFrontCamera;
  int get sensorOrientation => _sensorOrientation;
  int get extraQuarterTurns => _extraQuarterTurns;

  void init() {
    if (_useLiveSensors) {
      _startPolling();
    }
  }

  void setLiveMode(bool value) {
    _useLiveSensors = value;
    if (_useLiveSensors) {
      _startPolling();
    } else {
      _stopPolling();
    }
    notifyListeners();
  }

  void setManualOrientation({double? azimuth, double? pitch, double? cameraElevation, double? lightLux}) {
    if (azimuth != null) _compassAzimuth = azimuth.clamp(0.0, 360.0);
    if (pitch != null) _devicePitch = pitch.clamp(-90.0, 90.0);
    if (cameraElevation != null) _cameraElevation = cameraElevation.clamp(-90.0, 90.0);
    if (lightLux != null) _lightLux = lightLux.clamp(0.0, 100000.0);
    notifyListeners();
  }

  void rotateCameraPreview() {
    _extraQuarterTurns = (_extraQuarterTurns + 1) % 4;
    notifyListeners();
  }

  Future<String> startCamera({bool front = false}) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'startCamera',
        {'lens': front ? 'front' : 'back'},
      );
      if (res == null) return 'error';
      final status = res['status'] as String? ?? 'error';
      if (status == 'ok') {
        _cameraTextureId = (res['textureId'] as num?)?.toInt();
        _isFrontCamera = (res['isFront'] as bool?) ?? front;
        _sensorOrientation = (res['sensorOrientation'] as num?)?.toInt() ?? 90;
        _isCameraActive = _cameraTextureId != null;
        notifyListeners();
        return 'ok';
      }
      return status;
    } catch (_) {
      return 'unavailable';
    }
  }

  Future<String> switchCamera() async {
    return startCamera(front: !_isFrontCamera);
  }

  Future<Map<String, dynamic>?> capturePhoto() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('capturePhoto');
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> stopCamera() async {
    try {
      await _channel.invokeMethod('stopCamera');
    } catch (_) {}
    _isCameraActive = false;
    _cameraTextureId = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchGpsLocation() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getGpsLocation');
      return res;
    } catch (_) {
      return null;
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 70), (_) async {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>('getSensorSnapshot');
        if (res != null && _useLiveSensors) {
          final az = (res['azimuth'] as num?)?.toDouble() ?? _compassAzimuth;
          final pt = (res['pitch'] as num?)?.toDouble() ?? _devicePitch;
          final rl = (res['roll'] as num?)?.toDouble() ?? _deviceRoll;
          final camEl = (res['cameraElevation'] as num?)?.toDouble() ?? _cameraElevation;
          final lux = (res['lightLux'] as num?)?.toDouble() ?? _lightLux;
          final press = (res['pressureHpa'] as num?)?.toDouble() ?? _pressureHpa;
          final magUt = (res['magFieldUt'] as num?)?.toDouble() ?? _magFieldUt;
          _hasMag = (res['hasMag'] as bool?) ?? false;
          _hasLight = (res['hasLight'] as bool?) ?? false;
          _hasBarometer = (res['hasBarometer'] as bool?) ?? false;

          final changed = (az - _compassAzimuth).abs() > 0.3 ||
              (pt - _devicePitch).abs() > 0.3 ||
              (camEl - _cameraElevation).abs() > 0.3 ||
              (lux - _lightLux).abs() > 2.0;

          if (changed) {
            _compassAzimuth = az;
            _devicePitch = pt;
            _deviceRoll = rl;
            _cameraElevation = camEl;
            _lightLux = lux;
            _pressureHpa = press;
            _magFieldUt = magUt;
            notifyListeners();
          }
        }
      } catch (_) {
        // Fallback smoothly in tests or desktop
      }
    });
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
