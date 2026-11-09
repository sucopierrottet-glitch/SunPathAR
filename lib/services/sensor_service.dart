import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SensorService extends ChangeNotifier {
  static final SensorService instance = SensorService._();
  SensorService._();

  static const MethodChannel _channel =
      MethodChannel('com.simpleappspg.sensors/data');

  Timer? _timer;
  bool _useLiveSensors = false;
  double _compassAzimuth = 180.0;
  double _devicePitch = 35.0;
  double _deviceRoll = 0.0;

  bool get useLiveSensors => _useLiveSensors;
  double get compassAzimuth => _compassAzimuth;
  double get devicePitch => _devicePitch;
  double get deviceRoll => _deviceRoll;

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
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>('getSensorSnapshot');
        if (res != null && _useLiveSensors) {
          final az = (res['azimuth'] as num?)?.toDouble() ?? _compassAzimuth;
          final pt = (res['pitch'] as num?)?.toDouble() ?? _devicePitch;
          final rl = (res['roll'] as num?)?.toDouble() ?? _deviceRoll;
          _compassAzimuth = az;
          _devicePitch = pt;
          _deviceRoll = rl;
          notifyListeners();
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
