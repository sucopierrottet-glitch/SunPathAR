import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SensorService extends ChangeNotifier {
  static final SensorService instance = SensorService._();
  SensorService._();

  static const MethodChannel _channel =
      MethodChannel('com.simpleappspg.sensors/data');

  Timer? _timer;
  bool _useLiveSensors = true; // Predeterminado en VIVO al iniciar
  double _compassAzimuth = 0.0;
  double _devicePitch = 0.0;
  double _deviceRoll = 0.0;
  bool _hasMag = false;

  bool get useLiveSensors => _useLiveSensors;
  double get compassAzimuth => _compassAzimuth;
  double get devicePitch => _devicePitch;
  double get deviceRoll => _deviceRoll;
  bool get hasMag => _hasMag;

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

  void setManualOrientation({double? azimuth, double? pitch}) {
    if (azimuth != null) _compassAzimuth = azimuth.clamp(0.0, 360.0);
    if (pitch != null) _devicePitch = pitch.clamp(-90.0, 90.0);
    notifyListeners();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) async {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>('getSensorSnapshot');
        if (res != null && _useLiveSensors) {
          final az = (res['azimuth'] as num?)?.toDouble() ?? _compassAzimuth;
          final pt = (res['pitch'] as num?)?.toDouble() ?? _devicePitch;
          final rl = (res['roll'] as num?)?.toDouble() ?? _deviceRoll;
          _hasMag = (res['hasMag'] as bool?) ?? false;

          if ((az - _compassAzimuth).abs() > 0.3 || (pt - _devicePitch).abs() > 0.3) {
            _compassAzimuth = az;
            _devicePitch = pt;
            _deviceRoll = rl;
            notifyListeners();
          }
        }
      } catch (_) {
        // Fallback smoothly
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
