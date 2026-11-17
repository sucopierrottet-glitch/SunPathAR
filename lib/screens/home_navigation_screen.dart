import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../calculators/solar_calculator.dart';
import '../services/pdf_report_service.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../services/weather_solar_service.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

class HomeNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const HomeNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  late int _currentIndex;
  double _solarHour = 13.5;
  int _dayOfYear = 172;
  final double _objectHeight = 3.0;
  final TextEditingController _siteNameCtrl =
      TextEditingController(text: 'Mi Medición Solar');
  late TextEditingController _latCtrl;
  late TextEditingController _lonCtrl;
  late TextEditingController _inspectorCtrl;

  // Fotografía AR
  int _photoMode = 0; // 0 = Luz Dorada Rostro, 1 = Contraluz/Halo, 2 = Capturar Sol, 3 = Luz Cine 45°
  String? _cameraStatusNote;

  // Estacionamiento a la sombra
  double _parkingStayHours = 3.0;

  // Cronómetro Vitamina D / Sol Seguro
  Timer? _sunTimer;
  int _sunSecondsElapsed = 0;
  bool _isSunTimerRunning = false;

  // Escáner de Hogar & Obstáculos
  double? _frozenWindowAzimuth;
  double? _frozenObstacleAngle;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    final now = DateTime.now();
    _dayOfYear = (now.difference(DateTime(now.year, 1, 1)).inDays) + 1;
    _solarHour = (now.hour + (now.minute / 60.0)).clamp(0.0, 24.0);

    final store = StorageService.instance;
    _latCtrl = TextEditingController(text: store.latitude.toStringAsFixed(4));
    _lonCtrl = TextEditingController(text: store.longitude.toStringAsFixed(4));
    _inspectorCtrl = TextEditingController(text: store.inspectorName);
  }

  @override
  void dispose() {
    _sunTimer?.cancel();
    if (SensorService.instance.isCameraActive) {
      SensorService.instance.stopCamera();
    }
    _siteNameCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _inspectorCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRealGpsAndWeather(StorageService store) async {
    setState(() => _gpsLoading = true);
    final res = await SensorService.instance.fetchGpsLocation();
    if (!mounted) return;

    if (res != null && res['status'] == 'ok') {
      final lat = (res['lat'] as num).toDouble();
      final lon = (res['lon'] as num).toDouble();
      _latCtrl.text = lat.toStringAsFixed(4);
      _lonCtrl.text = lon.toStringAsFixed(4);
      await store.updateSettings(
        latitude: lat,
        longitude: lon,
        inspectorName: store.inspectorName,
      );
      await WeatherSolarService.instance.refresh(latitude: lat, longitude: lon);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación GPS y Clima Solar actualizados ✓'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } else {
      await WeatherSolarService.instance.refresh(
        latitude: store.latitude,
        longitude: store.longitude,
      );
      if (mounted) {
        final st = res?['status'] ?? 'offline';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              st == 'permission_denied'
                  ? 'Permiso GPS denegado. Actualizamos el clima con tus coordenadas actuales.'
                  : 'Clima solar actualizado para tus coordenadas actuales.',
            ),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }

    if (mounted) setState(() => _gpsLoading = false);
  }

  Future<void> _toggleCamera({bool? front}) async {
    final sensor = SensorService.instance;
    if (sensor.isCameraActive && front == null) {
      await sensor.stopCamera();
      setState(() => _cameraStatusNote = null);
      return;
    }

    final status = await sensor.startCamera(front: front ?? sensor.isFrontCamera);
    if (!mounted) return;
    if (status == 'ok') {
      setState(() => _cameraStatusNote = null);
    } else if (status == 'permission_denied') {
      setState(() => _cameraStatusNote = 'Permiso de cámara denegado. Actívalo en Ajustes.');
    } else {
      setState(() => _cameraStatusNote = 'Modo radar AR activo (usa el HUD con tus sensores).');
    }
  }

  void _toggleSunTimer() {
    if (_isSunTimerRunning) {
      _sunTimer?.cancel();
      setState(() => _isSunTimerRunning = false);
    } else {
      setState(() => _isSunTimerRunning = true);
      _sunTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _sunSecondsElapsed++);
      });
    }
  }

  void _resetSunTimer() {
    _sunTimer?.cancel();
    setState(() {
      _isSunTimerRunning = false;
      _sunSecondsElapsed = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        StorageService.instance,
        SensorService.instance,
        WeatherSolarService.instance,
      ]),
      builder: (context, _) {
        final store = StorageService.instance;
        final sensor = SensorService.instance;
        final weather = WeatherSolarService.instance;

        final pos = SolarCalculator.calculate(
          latitude: store.latitude,
          longitude: store.longitude,
          dayOfYear: _dayOfYear,
          solarHour: _solarHour,
          objectHeightMeters: _objectHeight,
        );

        final arcPoints = SolarCalculator.calculateDailyArc(
          latitude: store.latitude,
          longitude: store.longitude,
          dayOfYear: _dayOfYear,
        );

        return Scaffold(
          backgroundColor: AppTheme.darkBg,
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentIndex == 0
                        ? 'Cielo & Brújula'
                        : _currentIndex == 1
                            ? 'Fotos, Auto & UV'
                            : _currentIndex == 2
                                ? 'Hogar & Plantas'
                                : _currentIndex == 3
                                    ? 'Estudios Guardados'
                                    : 'Ajustes & GPS',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: _gpsLoading ? null : () => _fetchRealGpsAndWeather(store),
                icon: _gpsLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : const Icon(Icons.my_location_rounded, size: 16, color: AppTheme.primary),
                label: const Text(
                  'GPS',
                  style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ActionChip(
                  avatar: Icon(
                    sensor.useLiveSensors ? Icons.explore_rounded : Icons.tune_rounded,
                    size: 15,
                    color: sensor.useLiveSensors ? AppTheme.success : AppTheme.primary,
                  ),
                  label: Text(
                    sensor.useLiveSensors ? 'EN VIVO' : 'MANUAL',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => sensor.setLiveMode(!sensor.useLiveSensors),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (!store.isPro)
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: store.isTrialExpired
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : AppTheme.primary.withValues(alpha: 0.15),
                      border: Border(
                        bottom: BorderSide(
                          color: store.isTrialExpired
                              ? Colors.redAccent.withValues(alpha: 0.4)
                              : AppTheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          store.isTrialExpired ? Icons.lock_clock_rounded : Icons.timer_outlined,
                          size: 15,
                          color: store.isTrialExpired ? Colors.redAccent : AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            store.isTrialExpired
                                ? 'Prueba gratuita de 7 días finalizada • Toca para desbloquear PRO'
                                : 'Prueba de 7 días activa: ${store.trialDaysRemaining} días restantes • Acceso Total',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: store.isTrialExpired ? Colors.redAccent : AppTheme.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: store.isTrialExpired ? Colors.redAccent : AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            store.isTrialExpired ? 'DESBLOQUEAR' : 'PRO',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildSolarDomeTab(pos, arcPoints, store, sensor, weather),
                    _buildLifestylePhotoHealthTab(pos, store, sensor, weather),
                    _buildHomeAndPlantsTab(pos, arcPoints, store, sensor),
                    _buildSavedStudiesTab(store),
                    _buildSettingsTab(store, weather),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            backgroundColor: AppTheme.darkSurface,
            indicatorColor: AppTheme.primary.withValues(alpha: 0.2),
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) {
              if (idx != 1 && sensor.isCameraActive) {
                sensor.stopCamera();
              }
              setState(() => _currentIndex = idx);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.wb_twilight_rounded),
                selectedIcon: Icon(Icons.wb_twilight_rounded, color: AppTheme.primary),
                label: 'Bóveda 3D',
              ),
              NavigationDestination(
                icon: Icon(Icons.camera_alt_outlined),
                selectedIcon: Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                label: 'Fotos & Auto',
              ),
              NavigationDestination(
                icon: Icon(Icons.home_work_outlined),
                selectedIcon: Icon(Icons.home_work_rounded, color: AppTheme.primary),
                label: 'Hogar & Sol',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_copy_outlined),
                selectedIcon: Icon(Icons.folder_rounded, color: AppTheme.primary),
                label: 'Estudios',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
                label: 'Ajustes',
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // PESTAÑA 1: BÓVEDA 3D + CLIMA SOLAR GRATIS + SENSORES EN VIVO
  // =========================================================================
  Widget _buildSolarDomeTab(
    SolarPositionResult pos,
    List<SolarPositionResult> arc,
    StorageService store,
    SensorService sensor,
    WeatherSolarService weather,
  ) {
    final wData = weather.data;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clima Solar Gratis (Open-Meteo + Sensor de Luz)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_rounded, color: AppTheme.primary, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pos.sunStatusDescription,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            wData != null
                                ? '📍 ${wData.cityName} • Amanece ${pos.sunriseTime} • Ocaso ${pos.sunsetTime}'
                                : 'Amanece ${pos.sunriseTime} • Cenit ${pos.solarNoonTime} • Ocaso ${pos.sunsetTime}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar Clima Solar Gratis',
                      onPressed: weather.isLoading
                          ? null
                          : () => weather.refresh(latitude: store.latitude, longitude: store.longitude),
                      icon: weather.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                            )
                          : const Icon(Icons.cloud_sync_rounded, color: AppTheme.primary, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _miniChip(
                      Icons.thermostat_rounded,
                      wData != null ? '${wData.temperatureC.toStringAsFixed(0)}°C' : 'Clima: Toca 🔄',
                      Colors.orangeAccent,
                    ),
                    _miniChip(
                      Icons.cloud_outlined,
                      wData != null ? '${wData.cloudCoverPercent}% nubes' : 'Nubes: --',
                      Colors.lightBlueAccent,
                    ),
                    _miniChip(
                      Icons.wb_iridescent_rounded,
                      'UV ${wData != null ? wData.liveUvIndex.toStringAsFixed(1) : pos.uvIndexEstimate}',
                      Colors.amberAccent,
                    ),
                    _miniChip(
                      Icons.light_mode_rounded,
                      '${sensor.lightLux.toStringAsFixed(0)} lx',
                      AppTheme.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Indicador de Brújula y Orientación en Vivo
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F231D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.compass_calibration_rounded, color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sensor.useLiveSensors
                        ? 'Apuntando: ${sensor.compassAzimuth.toStringAsFixed(0)}° (${_getCardinalLabel(sensor.compassAzimuth)}) • Elevación cámara: ${sensor.cameraElevation.toStringAsFixed(0)}°'
                        : 'Modo Manual: Activa EN VIVO arriba para usar tus sensores',
                    style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Bóveda Celeste con Cono de Visión del Teléfono
          Container(
            height: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: CustomPaint(
              painter: _SolarSkyDomePainter(
                currentPos: pos,
                dailyArc: arc,
                compassHeading: sensor.compassAzimuth,
                isLive: sensor.useLiveSensors,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),

          // KPIs Clave
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Altura del Sol',
                  '${pos.elevationDeg.toStringAsFixed(1)}°',
                  pos.elevationDeg > 0 ? AppTheme.primary : AppTheme.accent,
                  Icons.height_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Posición Solar',
                  '${pos.azimuthDeg.toStringAsFixed(1)}° (${_getCardinalLabel(pos.azimuthDeg)})',
                  AppTheme.accent,
                  Icons.explore_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Controles de Simulación
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hora del Día', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    Text(
                      '${_solarHour.floor().toString().padLeft(2, '0')}:${((_solarHour % 1) * 60).round().toString().padLeft(2, '0')} h',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _solarHour,
                  min: 0.0,
                  max: 23.99,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.darkBorder,
                  onChanged: (v) => setState(() => _solarHour = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Día del Año (Estación)', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    Text('Día $_dayOfYear / 365', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.accent)),
                  ],
                ),
                Slider(
                  value: _dayOfYear.toDouble(),
                  min: 1.0,
                  max: 365.0,
                  activeColor: AppTheme.accent,
                  inactiveColor: AppTheme.darkBorder,
                  onChanged: (v) => setState(() => _dayOfYear = v.round()),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Ahora', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        final n = DateTime.now();
                        setState(() {
                          _dayOfYear = n.difference(DateTime(n.year, 1, 1)).inDays + 1;
                          _solarHour = (n.hour + (n.minute / 60.0)).clamp(0.0, 24.0);
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Verano', style: TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _dayOfYear = 172),
                    ),
                    ActionChip(
                      label: const Text('Equinoccio', style: TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _dayOfYear = 80),
                    ),
                    ActionChip(
                      label: const Text('Invierno', style: TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _dayOfYear = 355),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PESTAÑA 2: CÁMARA AR FOTOGRAFÍA + RADAR ESTACIONAMIENTO + SALUD UV
  // =========================================================================
  Widget _buildLifestylePhotoHealthTab(
    SolarPositionResult pos,
    StorageService store,
    SensorService sensor,
    WeatherSolarService weather,
  ) {
    final alignment = SolarCalculator.calculateCameraAlignment(
      sunAzimuth: pos.azimuthDeg,
      sunElevation: pos.elevationDeg,
      deviceAzimuth: sensor.compassAzimuth,
      cameraElevation: sensor.cameraElevation,
      isFrontCamera: sensor.isFrontCamera,
      photoMode: _photoMode,
    );

    final wData = weather.data;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. VISOR DE CÁMARA AR PARA FOTOGRAFÍA (FRONTAL Y TRASERA)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: alignment.isAligned ? AppTheme.success : AppTheme.primary.withValues(alpha: 0.6),
                width: alignment.isAligned ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.camera_enhance_rounded, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'DIRECTOR DE FOTOGRAFÍA AR',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: alignment.isAligned
                            ? AppTheme.success.withValues(alpha: 0.2)
                            : AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${alignment.alignmentScore}% Precisión',
                        style: TextStyle(
                          color: alignment.isAligned ? AppTheme.success : AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Modos Fotográficos
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _modeChip(0, '✨ Luz en Rostro', _photoMode, (v) => setState(() => _photoMode = v)),
                      const SizedBox(width: 6),
                      _modeChip(1, '🌅 Halo Contraluz', _photoMode, (v) => setState(() => _photoMode = v)),
                      const SizedBox(width: 6),
                      _modeChip(2, '☀️ Ver el Sol', _photoMode, (v) => setState(() => _photoMode = v)),
                      const SizedBox(width: 6),
                      _modeChip(3, '🎬 Luz Cine 45°', _photoMode, (v) => setState(() => _photoMode = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Visor Cámara Nativa + HUD AR Superpuesto
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 290,
                    color: const Color(0xFF070B14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (sensor.isCameraActive && sensor.cameraTextureId != null)
                          Center(
                            child: Transform.scale(
                              scaleX: sensor.isFrontCamera ? -1.0 : 1.0,
                              child: RotatedBox(
                                quarterTurns: ((sensor.sensorOrientation ~/ 90) + sensor.extraQuarterTurns) % 4,
                                child: Texture(textureId: sensor.cameraTextureId!),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: RadialGradient(
                                colors: [Color(0xFF1A263D), Color(0xFF080D17)],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam_outlined, color: AppTheme.textMuted, size: 42),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Radar AR de Sensores Activo',
                                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  if (_cameraStatusNote != null) ...[
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Text(
                                        _cameraStatusNote!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: AppTheme.primary, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                        // HUD AR con Mira, Sol Objetivo y Flechas Dinámicas
                        CustomPaint(
                          painter: _CameraArHudPainter(
                            alignment: alignment,
                            isFrontCamera: sensor.isFrontCamera,
                          ),
                        ),

                        // Barra Superior de Instrucción Clara sobre la Cámara
                        Positioned(
                          top: 10,
                          left: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: alignment.isAligned
                                  ? AppTheme.success.withValues(alpha: 0.9)
                                  : Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  alignment.isAligned ? Icons.check_circle_rounded : Icons.screen_rotation_rounded,
                                  color: alignment.isAligned ? Colors.black : AppTheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    alignment.instructionText,
                                    style: TextStyle(
                                      color: alignment.isAligned ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Indicador Inferior de Lente Activa
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sensor.isFrontCamera ? '🤳 Lente Frontal (Selfie)' : '📷 Lente Trasera',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botones de Control de Cámara
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleCamera(),
                        icon: Icon(
                          sensor.isCameraActive ? Icons.videocam_off_rounded : Icons.camera_alt_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                        label: Text(
                          sensor.isCameraActive ? 'Cerrar Cámara' : 'Abrir Cámara en Vivo',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sensor.isCameraActive ? Colors.amber : AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleCamera(front: !sensor.isFrontCamera),
                        icon: const Icon(Icons.cameraswitch_rounded, size: 17, color: Colors.white),
                        label: Text(
                          sensor.isFrontCamera ? 'Trasera' : 'Selfie',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppTheme.darkBorder),
                        ),
                      ),
                    ),
                    if (sensor.isCameraActive) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Girar imagen cámara',
                        onPressed: () => sensor.rotateCameraPreview(),
                        icon: const Icon(Icons.rotate_right_rounded, color: AppTheme.primary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Horarios de Hora Dorada + Calidad por Clima
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF78350F), Color(0xFFB45309)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('🌅 Hora Dorada: ${pos.goldenHourEvening}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('🌌 Azul: ${pos.blueHourEvening}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        wData != null
                            ? 'Calidad del cielo hoy (${wData.goldenHourQualityScore}%): ${wData.goldenHourQualityLabel}'
                            : 'Toca el botón GPS o 🔄 en Bóveda 3D para medir nubosidad real de tu foto.',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. RADAR DE ESTACIONAMIENTO A LA SOMBRA (GRÁFICO CON BRÚJULA EN VIVO)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_car_filled_rounded, color: AppTheme.accent, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'RADAR DE ESTACIONAMIENTO A LA SOMBRA',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${_parkingStayHours.toStringAsFixed(0)}h estancia',
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gira el teléfono en el estacionamiento: la flecha naranja señala hacia el Oeste / Sol, y la zona verde muestra dónde proyectará sombra un edificio o árbol.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 230,
                  child: CustomPaint(
                    painter: _ParkingShadowRadarPainter(
                      deviceHeading: sensor.compassAzimuth,
                      currentSunAzimuth: pos.azimuthDeg,
                      latitude: store.latitude,
                      stayHours: _parkingStayHours,
                      solarHour: _solarHour,
                      dayOfYear: _dayOfYear,
                      isLive: sensor.useLiveSensors,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Tiempo estacionado:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    Expanded(
                      child: Slider(
                        value: _parkingStayHours,
                        min: 1.0,
                        max: 6.0,
                        divisions: 5,
                        activeColor: AppTheme.accent,
                        onChanged: (v) => setState(() => _parkingStayHours = v),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F231D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '🅿️ Consejo en vivo: Estaciona al lado ESTE/NORESTE de un árbol o edificio. El sol se moverá hacia el Oeste (270°) y mantendrá tu auto cubierto durante las próximas ${_parkingStayHours.toStringAsFixed(0)} horas.',
                    style: const TextStyle(color: AppTheme.success, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. SALUD SOLAR: VITAMINA D + CRONÓMETRO SEGURO
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      pos.isVitaminDOptimal ? Icons.health_and_safety_rounded : Icons.wb_sunny_outlined,
                      color: pos.isVitaminDOptimal ? AppTheme.success : Colors.amber,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SALUD, UV Y CRONÓMETRO DE SOL',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(
                            pos.isVitaminDOptimal ? 'Ventana Óptima de Vitamina D ✓' : 'UV Suave / Paseo Seguro',
                            style: TextStyle(
                              color: pos.isVitaminDOptimal ? AppTheme.success : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _healthMiniCard(
                        wData != null ? 'UV Real (Nubes)' : 'UV Astronómico',
                        '${wData != null ? wData.liveUvIndex.toStringAsFixed(1) : pos.uvIndexEstimate} / 12',
                        pos.uvIndexEstimate > 7 ? Colors.redAccent : AppTheme.primary,
                        Icons.shield_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _healthMiniCard(
                        'Tiempo Seguro Hoy',
                        '${pos.safeSunMinutes} min',
                        AppTheme.success,
                        Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cronómetro de Exposición', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            Text(
                              '${(_sunSecondsElapsed ~/ 60).toString().padLeft(2, '0')}:${(_sunSecondsElapsed % 60).toString().padLeft(2, '0')} / ${pos.safeSunMinutes}:00',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _toggleSunTimer,
                        style: IconButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                        icon: Icon(_isSunTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _resetSunTimer,
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PESTAÑA 3: HOGAR, VENTANAS EN VIVO, LUXÓMETRO DE PLANTAS E INCLINÓMETRO
  // =========================================================================
  Widget _buildHomeAndPlantsTab(
    SolarPositionResult pos,
    List<SolarPositionResult> arc,
    StorageService store,
    SensorService sensor,
  ) {
    final activeWindowAz = _frozenWindowAzimuth ?? sensor.compassAzimuth;
    final windowSun = SolarCalculator.calculateWindowSunlight(
      windowAzimuth: activeWindowAz,
      dailyArc: arc,
    );

    final lux = sensor.lightLux;
    final obstacleAngle = (_frozenObstacleAngle ?? sensor.cameraElevation).clamp(0.0, 89.0);
    final sunInThatDir = pos; // Compara contra la altura solar actual o máxima del día
    final isBlocked = sunInThatDir.elevationDeg > 0 && obstacleAngle > sunInThatDir.elevationDeg;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. ESCÁNER DE VENTANAS EN VIVO CON BRÚJULA
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.window_rounded, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ESCÁNER DE VENTANAS EN VIVO',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _frozenWindowAzimuth = _frozenWindowAzimuth == null ? sensor.compassAzimuth : null;
                        });
                      },
                      icon: Icon(
                        _frozenWindowAzimuth != null ? Icons.lock_rounded : Icons.explore_rounded,
                        size: 14,
                        color: _frozenWindowAzimuth != null ? Colors.amber : AppTheme.success,
                      ),
                      label: Text(
                        _frozenWindowAzimuth != null ? 'Soltar' : 'Fijar Ventana',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: AppTheme.darkBorder),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Párate frente a una ventana o balcón y apunta el teléfono hacia afuera: la brújula calcula en vivo cuántas horas de sol directo entrarán.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 165,
                  child: CustomPaint(
                    painter: _WindowSunScannerPainter(
                      windowAzimuth: activeWindowAz,
                      dailyArc: arc,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _healthMiniCard(
                        'Orientación Ventana',
                        '${activeWindowAz.toStringAsFixed(0)}° (${_getCardinalLabel(activeWindowAz)})',
                        AppTheme.primary,
                        Icons.explore_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _healthMiniCard(
                        'Sol Directo Hoy',
                        '${windowSun.directSunHours.toStringAsFixed(1)} hrs (${windowSun.firstSunTime}-${windowSun.lastSunTime})',
                        AppTheme.success,
                        Icons.wb_sunny_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(windowSun.thermalVerdict,
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(windowSun.bestRoomUse,
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. LUXÓMETRO DE PLANTAS CON SENSOR FÍSICO DE LUZ (TYPE_LIGHT)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco_rounded, color: AppTheme.success, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'MEDIDOR DE LUZ PARA PLANTAS (SENSOR LUX)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${lux.toStringAsFixed(0)} lx',
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  sensor.hasLight
                      ? 'Coloca la pantalla del teléfono donde pondrás tu maceta. Sensor físico activo leyendo intensidad luminosa en tiempo real.'
                      : 'Sensor de luz ambiental simulado. Mueve el control o apunta a la ventana para diagnosticar compatibilidad.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 12),
                _luxDiagnosisBanner(lux),
                const SizedBox(height: 12),
                _plantMatchBar('🌵 Suculentas & Cactus', _computePlantMatch(lux, 5000, 30000)),
                _plantMatchBar('🍅 Huerto & Aromáticas (Albahaca)', _computePlantMatch(lux, 8000, 40000)),
                _plantMatchBar('🌿 Monstera, Ficus & Potos', _computePlantMatch(lux, 800, 6000)),
                _plantMatchBar('🌸 Orquídeas & Anturios', _computePlantMatch(lux, 400, 2500)),
                _plantMatchBar('🪴 Sansevieria & Zamioculca', _computePlantMatch(lux, 120, 2000)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. ESCÁNER DE SOMBRAS Y OBSTÁCULOS CON INCLINÓMETRO ("¿ME TAPARÁ EL EDIFICIO?")
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.architecture_rounded, color: AppTheme.accent, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '¿ESE EDIFICIO O ÁRBOL ME DARÁ SOMBRA?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _frozenObstacleAngle = _frozenObstacleAngle == null ? sensor.cameraElevation : null;
                        });
                      },
                      child: Text(_frozenObstacleAngle != null ? 'Soltar' : 'Medir / Fijar',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Text(
                  'Apunta el borde superior del teléfono hacia la cima de un edificio o árbol frente a tu terraza/jardín. El clinómetro mide su ángulo y verifica si tapa al sol.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: CustomPaint(
                    painter: _ObstacleClinometerPainter(
                      obstacleAngleDeg: obstacleAngle,
                      sunElevationDeg: pos.elevationDeg.clamp(0.0, 90.0),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? Colors.redAccent.withValues(alpha: 0.14)
                        : AppTheme.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBlocked ? Colors.redAccent.withValues(alpha: 0.5) : AppTheme.success.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    pos.elevationDeg <= 0
                        ? '🌙 Ahora es de noche. Mueve el simulador de hora en Bóveda 3D para probar si el obstáculo (${obstacleAngle.toStringAsFixed(0)}°) bloquea el sol de día.'
                        : isBlocked
                            ? '🏢 Sombra Bloqueada: El obstáculo está a ${obstacleAngle.toStringAsFixed(0)}° y supera al sol (${pos.elevationDeg.toStringAsFixed(0)}°). Tendrás sombra en este punto.'
                            : '☀️ Sol Libre: El sol está a ${pos.elevationDeg.toStringAsFixed(0)}° por encima del obstáculo (${obstacleAngle.toStringAsFixed(0)}°). Disfrutarás sol directo sin bloqueos.',
                    style: TextStyle(
                      color: pos.elevationDeg <= 0
                          ? Colors.white70
                          : (isBlocked ? Colors.redAccent : AppTheme.success),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _siteNameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Guardar esta medición con nombre (ej. Balcón Sala)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    prefixIcon: Icon(Icons.bookmark_border_rounded, color: AppTheme.primary, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final study = SolarStudyRecord(
                      id: 'SP-${DateTime.now().millisecondsSinceEpoch % 10000}',
                      siteName: _siteNameCtrl.text.trim().isEmpty ? 'Medición Hogar' : _siteNameCtrl.text.trim(),
                      latitude: store.latitude,
                      longitude: store.longitude,
                      dayOfYear: _dayOfYear,
                      solarHour: _solarHour,
                      objectHeightMeters: _objectHeight,
                      elevationDeg: pos.elevationDeg,
                      azimuthDeg: activeWindowAz,
                      shadowLengthMeters: obstacleAngle,
                      optimalTiltDeg: windowSun.directSunHours,
                      minRowSpacingMeters: lux,
                      createdAtIso: DateTime.now().toIso8601String(),
                    );
                    await store.saveStudy(study);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Medición guardada en Estudios ✓'), backgroundColor: AppTheme.success),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded, color: Colors.black, size: 18),
                  label: const Text('Guardar Medición de Hogar / Luz', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PESTAÑA 4: ESTUDIOS GUARDADOS Y PDF
  // =========================================================================
  Widget _buildSavedStudiesTab(StorageService store) {
    if (store.studies.isEmpty) {
      return const Center(
        child: Text('No hay mediciones guardadas aún.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: store.studies.length,
      itemBuilder: (ctx, idx) {
        final item = store.studies[idx];
        return Card(
          color: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.darkBorder),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.siteName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(item.id, style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Elevación Sol: ${item.elevationDeg.toStringAsFixed(1)}° • Azimut: ${item.azimuthDeg.toStringAsFixed(0)}° • Luz: ${item.minRowSpacingMeters.toStringAsFixed(0)} lx',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openSignAndShareModal(item, store),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.black),
                        label: const Text('Firmar y Exportar PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted),
                      onPressed: () => store.deleteStudy(item.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // PESTAÑA 5: AJUSTES, GPS & CIUDADES
  // =========================================================================
  Widget _buildSettingsTab(StorageService store, WeatherSolarService weather) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: store.isPro
                      ? [const Color(0xFF065F46), const Color(0xFF047857)]
                      : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: store.isPro ? const Color(0xFF10B981) : AppTheme.primary.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    store.isPro ? Icons.verified_rounded : Icons.star_rounded,
                    color: store.isPro ? Colors.white : AppTheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.isPro
                              ? 'SunPath AR PRO — Desbloqueado'
                              : (store.isTrialActive
                                  ? 'Prueba Gratuita (${store.trialDaysRemaining} días restantes)'
                                  : 'Actualizar a SunPath AR PRO'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          store.isPro
                              ? 'Licencia PRO activa • Acceso ilimitado'
                              : 'Toca aquí para ver planes y prueba de 7 días',
                          style: TextStyle(fontSize: 12, color: store.isPro ? Colors.white70 : AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _gpsLoading ? null : () => _fetchRealGpsAndWeather(store),
            icon: const Icon(Icons.gps_fixed_rounded, color: Colors.black),
            label: const Text('Detectar Mi Ubicación por GPS & Clima Real', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 18),
          const Text('COORDENADAS MANUALES / FIRMA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _latCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Latitud (° N / -S)', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _lonCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Longitud (° E / -W)', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _inspectorCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Tu Nombre (para reportes PDF)', isDense: true),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () async {
                    final lat = double.tryParse(_latCtrl.text) ?? store.latitude;
                    final lon = double.tryParse(_lonCtrl.text) ?? store.longitude;
                    await store.updateSettings(latitude: lat, longitude: lon, inspectorName: _inspectorCtrl.text);
                    await weather.refresh(latitude: lat, longitude: lon);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ubicación y clima actualizados ✓'), backgroundColor: AppTheme.success),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('Guardar Coordenadas', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CityLocationPreset.presets.map((c) {
              return ActionChip(
                label: Text(c.name, style: const TextStyle(fontSize: 11)),
                onPressed: () async {
                  _latCtrl.text = c.latitude.toStringAsFixed(4);
                  _lonCtrl.text = c.longitude.toStringAsFixed(4);
                  await store.updateSettings(latitude: c.latitude, longitude: c.longitude, inspectorName: _inspectorCtrl.text);
                  await weather.refresh(latitude: c.latitude, longitude: c.longitude);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPERS Y MODALES
  // =========================================================================
  Future<void> _openSignAndShareModal(SolarStudyRecord study, StorageService store) async {
    if (store.isTrialExpired) {
      final unlocked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      if (!mounted) return;
      if (unlocked != true && !store.isPro) return;
    }
    final sigController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Firma Digital y Exportar Reporte PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Signature(controller: sigController, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final sigBytes = await sigController.toPngBytes();
                  final sigBase64 = sigBytes != null ? base64Encode(sigBytes) : null;
                  final updatedStudy = SolarStudyRecord(
                    id: study.id,
                    siteName: study.siteName,
                    latitude: study.latitude,
                    longitude: study.longitude,
                    dayOfYear: study.dayOfYear,
                    solarHour: study.solarHour,
                    objectHeightMeters: study.objectHeightMeters,
                    elevationDeg: study.elevationDeg,
                    azimuthDeg: study.azimuthDeg,
                    shadowLengthMeters: study.shadowLengthMeters,
                    optimalTiltDeg: study.optimalTiltDeg,
                    minRowSpacingMeters: study.minRowSpacingMeters,
                    createdAtIso: study.createdAtIso,
                    signatureBase64: sigBase64,
                  );
                  await PdfReportService.shareStudyPdf(
                    study: updatedStudy,
                    inspectorName: store.inspectorName,
                    localeCode: store.localeCode,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.share_rounded, color: Colors.black),
                label: const Text('Exportar & Compartir PDF', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _modeChip(int value, String label, int selected, ValueChanged<int> onTap) {
    final active = value == selected;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.black : Colors.white),
      ),
      selected: active,
      selectedColor: AppTheme.primary,
      backgroundColor: const Color(0xFF131D2E),
      onSelected: (_) => onTap(value),
    );
  }

  Widget _luxDiagnosisBanner(double lux) {
    String label;
    Color col;
    if (lux < 150) {
      label = '🌑 Sombra Profunda (< 150 lx) • Solo plantas muy resistentes';
      col = Colors.blueGrey;
    } else if (lux < 800) {
      label = '☁️ Luz Interior Suave ($lux lx) • Ideal Orquídeas y Helechos';
      col = Colors.lightBlueAccent;
    } else if (lux < 4500) {
      label = '✨ Luz Brillante Indirecta • Excelente para Monstera y Ficus';
      col = AppTheme.success;
    } else {
      label = '☀️ Sol Directo Intenso • Perfecto para Cactus, Suculentas y Huerto';
      col = AppTheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withValues(alpha: 0.45)),
      ),
      child: Text(label, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  double _computePlantMatch(double lux, double minIdeal, double maxIdeal) {
    if (lux >= minIdeal && lux <= maxIdeal) return 1.0;
    if (lux < minIdeal) return (lux / minIdeal).clamp(0.1, 0.95);
    return (maxIdeal / lux).clamp(0.25, 0.95);
  }

  Widget _plantMatchBar(String name, double pct) {
    final color = pct >= 0.75 ? AppTheme.success : (pct >= 0.45 ? AppTheme.primary : Colors.redAccent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              Text('${(pct * 100).round()}% ideal', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String val, Color c, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthMiniCard(String label, String val, Color c, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 4),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  String _getCardinalLabel(double az) {
    if (az >= 337.5 || az < 22.5) return 'Norte';
    if (az >= 22.5 && az < 67.5) return 'Noreste';
    if (az >= 67.5 && az < 112.5) return 'Este';
    if (az >= 112.5 && az < 157.5) return 'Sureste';
    if (az >= 157.5 && az < 202.5) return 'Sur';
    if (az >= 202.5 && az < 247.5) return 'Suroeste';
    if (az >= 247.5 && az < 292.5) return 'Oeste';
    return 'Noroeste';
  }
}

// =========================================================================
// CUSTOM PAINTER 1: BÓVEDA CELESTE 3D + CONO DE VISIÓN EN VIVO
// =========================================================================
class _SolarSkyDomePainter extends CustomPainter {
  final SolarPositionResult currentPos;
  final List<SolarPositionResult> dailyArc;
  final double compassHeading;
  final bool isLive;

  _SolarSkyDomePainter({
    required this.currentPos,
    required this.dailyArc,
    required this.compassHeading,
    required this.isLive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy) - 22;

    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF16233B), Color(0xFF0B111E)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR));
    canvas.drawCircle(Offset(cx, cy), maxR, bgPaint);

    // Cono de visión hacia arriba (dirección donde apunta el teléfono)
    if (isLive) {
      final fovPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.success.withValues(alpha: 0.28),
            AppTheme.success.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR));
      final fovPath = Path()
        ..moveTo(cx, cy)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: maxR),
          -math.pi / 2 - 0.38,
          0.76,
          false,
        )
        ..close();
      canvas.drawPath(fovPath, fovPaint);
    }

    final ringPaint = Paint()
      ..color = const Color(0xFF2A3A54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), maxR, ringPaint);
    canvas.drawCircle(Offset(cx, cy), maxR * 0.66, ringPaint..strokeWidth = 1..color = const Color(0xFF1E293B));
    canvas.drawCircle(Offset(cx, cy), maxR * 0.33, ringPaint);

    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), ringPaint);
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), ringPaint);

    final rotationRad = isLive ? (-compassHeading * math.pi / 180.0) : 0.0;

    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 0, 'N', Colors.redAccent, isBold: true);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 90, 'E', AppTheme.textSecondary);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 180, 'S', AppTheme.textSecondary);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 270, 'O', AppTheme.textSecondary);

    final path = Path();
    bool started = false;
    for (final pt in dailyArc) {
      if (pt.elevationDeg >= 0) {
        final offset = _polarToScreen(cx, cy, maxR, pt.azimuthDeg, pt.elevationDeg, rotationRad);
        if (!started) {
          path.moveTo(offset.dx, offset.dy);
          started = true;
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    final sunElev = currentPos.elevationDeg.clamp(0.0, 90.0);
    final sunPos = _polarToScreen(cx, cy, maxR, currentPos.azimuthDeg, sunElev, rotationRad);

    canvas.drawCircle(sunPos, 20, Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.3));
    canvas.drawCircle(sunPos, 10, Paint()..color = const Color(0xFFFBBF24));
    canvas.drawLine(
      Offset(cx, cy),
      sunPos,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.4)
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = isLive ? AppTheme.success : AppTheme.primary);
  }

  void _drawCardinal(Canvas canvas, double cx, double cy, double maxR, double baseRotation, double deg, String label, Color color, {bool isBold = false}) {
    final rad = (deg - 90.0) * math.pi / 180.0 + baseRotation;
    final r = maxR - 12;
    final pos = Offset(cx + r * math.cos(rad), cy + r * math.sin(rad));

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontSize: isBold ? 14 : 11, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  Offset _polarToScreen(double cx, double cy, double maxR, double azDeg, double elDeg, double baseRotation) {
    final r = maxR * (1.0 - (elDeg.clamp(0.0, 90.0) / 90.0));
    final rad = (azDeg - 90.0) * math.pi / 180.0 + baseRotation;
    return Offset(cx + r * math.cos(rad), cy + r * math.sin(rad));
  }

  @override
  bool shouldRepaint(covariant _SolarSkyDomePainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM PAINTER 2: HUD AR SOBRE LA CÁMARA FOTOGRÁFICA
// =========================================================================
class _CameraArHudPainter extends CustomPainter {
  final CameraAlignmentResult alignment;
  final bool isFrontCamera;

  _CameraArHudPainter({required this.alignment, required this.isFrontCamera});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Mira central
    final reticleColor = alignment.isAligned ? AppTheme.success : Colors.white.withValues(alpha: 0.6);
    final reticlePaint = Paint()
      ..color = reticleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = alignment.isAligned ? 2.8 : 1.5;
    canvas.drawCircle(Offset(cx, cy), 34, reticlePaint);
    canvas.drawLine(Offset(cx - 46, cy), Offset(cx - 22, cy), reticlePaint);
    canvas.drawLine(Offset(cx + 22, cy), Offset(cx + 46, cy), reticlePaint);
    canvas.drawLine(Offset(cx, cy - 46), Offset(cx, cy - 22), reticlePaint);
    canvas.drawLine(Offset(cx, cy + 22), Offset(cx, cy + 46), reticlePaint);

    // Posición del objetivo en el visor según deltaAzimuth y deltaElevation
    final dx = (alignment.deltaAzimuth / 60.0).clamp(-1.0, 1.0) * (size.width * 0.38);
    final dy = -(alignment.deltaElevation / 45.0).clamp(-1.0, 1.0) * (size.height * 0.34);
    final targetOffset = Offset(cx + dx, cy + dy);

    // Línea guía hacia el punto ideal
    if (!alignment.isAligned) {
      canvas.drawLine(
        Offset(cx, cy),
        targetOffset,
        Paint()
          ..color = AppTheme.primary.withValues(alpha: 0.75)
          ..strokeWidth = 2.0,
      );
    }

    // Esfera Objetivo (Sol / Dirección ideal de cámara)
    canvas.drawCircle(
      targetOffset,
      24,
      Paint()..color = (alignment.isAligned ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      targetOffset,
      11,
      Paint()..color = alignment.isAligned ? AppTheme.success : AppTheme.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraArHudPainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM PAINTER 3: RADAR GRÁFICO DE ESTACIONAMIENTO A LA SOMBRA
// =========================================================================
class _ParkingShadowRadarPainter extends CustomPainter {
  final double deviceHeading;
  final double currentSunAzimuth;
  final double latitude;
  final double stayHours;
  final double solarHour;
  final int dayOfYear;
  final bool isLive;

  _ParkingShadowRadarPainter({
    required this.deviceHeading,
    required this.currentSunAzimuth,
    required this.latitude,
    required this.stayHours,
    required this.solarHour,
    required this.dayOfYear,
    required this.isLive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy) - 16;
    final rot = isLive ? (-deviceHeading * math.pi / 180.0) : 0.0;

    // Fondo radar
    canvas.drawCircle(Offset(cx, cy), maxR, Paint()..color = const Color(0xFF0E1726));
    canvas.drawCircle(
      Offset(cx, cy),
      maxR,
      Paint()
        ..color = const Color(0xFF243046)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Abanico de sombra durante las próximas [stayHours] horas
    final futureAzEnd = SolarCalculator.calculate(
      latitude: latitude,
      longitude: 0,
      dayOfYear: dayOfYear,
      solarHour: (solarHour + stayHours).clamp(0.0, 23.9),
    ).azimuthDeg;

    final startShadowAz = (currentSunAzimuth + 180.0) % 360.0;
    final endShadowAz = (futureAzEnd + 180.0) % 360.0;
    final startAngleRad = (startShadowAz - 90.0) * math.pi / 180.0 + rot;
    double sweepRad = ((endShadowAz - startShadowAz + 540.0) % 360.0 - 180.0) * math.pi / 180.0;
    if (sweepRad.abs() < 0.35) sweepRad = 0.45;

    final shadowPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: maxR * 0.88), startAngleRad, sweepRad, false)
      ..close();
    canvas.drawPath(shadowPath, Paint()..color = AppTheme.success.withValues(alpha: 0.25));

    // Flecha Naranja hacia el Oeste / Sol de tarde (270°)
    final westRad = (270.0 - 90.0) * math.pi / 180.0 + rot;
    final westPt = Offset(cx + (maxR - 14) * math.cos(westRad), cy + (maxR - 14) * math.sin(westRad));
    canvas.drawLine(Offset(cx, cy), westPt, Paint()..color = Colors.orangeAccent..strokeWidth = 3);
    canvas.drawCircle(westPt, 8, Paint()..color = Colors.orangeAccent);
    _paintTag(canvas, westPt, 'OESTE / SOL', Colors.orangeAccent);

    // Zona y Flecha Verde "APARCA AQUÍ" en lado opuesto (Este / Sombra)
    final safeRad = startAngleRad + sweepRad / 2;
    final safePt = Offset(cx + (maxR * 0.65) * math.cos(safeRad), cy + (maxR * 0.65) * math.sin(safeRad));
    canvas.drawLine(Offset(cx, cy), safePt, Paint()..color = AppTheme.success..strokeWidth = 3.5);
    canvas.drawCircle(safePt, 10, Paint()..color = AppTheme.success);
    _paintTag(canvas, safePt, 'APARCA AQUÍ', AppTheme.success);

    // Edificio / Árbol central
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 28, height: 28), const Radius.circular(6)),
      Paint()..color = const Color(0xFF334155),
    );
    _paintTag(canvas, Offset(cx, cy + 20), 'Edificio/Árbol', Colors.white70);
  }

  void _paintTag(Canvas canvas, Offset pt, String label, Color c) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - tp.height - 10));
  }

  @override
  bool shouldRepaint(covariant _ParkingShadowRadarPainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM PAINTER 4: ESCÁNER DE VENTANAS EN VIVO
// =========================================================================
class _WindowSunScannerPainter extends CustomPainter {
  final double windowAzimuth;
  final List<SolarPositionResult> dailyArc;

  _WindowSunScannerPainter({required this.windowAzimuth, required this.dailyArc});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 12;
    final radius = math.min(cx, cy) - 18;

    // Habitación (parte inferior)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 75, cy, 150, 48), const Radius.circular(8)),
      Paint()..color = const Color(0xFF1E293B),
    );
    // Ventana brillante arriba
    canvas.drawLine(
      Offset(cx - 42, cy),
      Offset(cx + 42, cy),
      Paint()..color = Colors.lightBlueAccent..strokeWidth = 5,
    );

    // Rayos de sol que entran por esa ventana hoy
    for (final pt in dailyArc) {
      if (pt.elevationDeg > 5.0) {
        final diff = ((pt.azimuthDeg - windowAzimuth + 540.0) % 360.0 - 180.0);
        if (diff.abs() <= 72.0) {
          final rad = -math.pi / 2 + (diff * math.pi / 180.0);
          final sunPt = Offset(cx + radius * math.cos(rad), cy + radius * math.sin(rad));
          canvas.drawLine(
            sunPt,
            Offset(cx, cy),
            Paint()..color = AppTheme.primary.withValues(alpha: 0.35)..strokeWidth = 2,
          );
          canvas.drawCircle(sunPt, 4, Paint()..color = AppTheme.primary);
        }
      }
    }

    final tp = TextPainter(
      text: const TextSpan(text: 'HABITACIÓN / INTERIOR', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 16));
  }

  @override
  bool shouldRepaint(covariant _WindowSunScannerPainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM PAINTER 5: CLINÓMETRO DE OBSTÁCULOS VS ALTURA DEL SOL
// =========================================================================
class _ObstacleClinometerPainter extends CustomPainter {
  final double obstacleAngleDeg;
  final double sunElevationDeg;

  _ObstacleClinometerPainter({required this.obstacleAngleDeg, required this.sunElevationDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(24, size.height - 20);
    final maxLen = size.width - 56;

    // Suelo
    canvas.drawLine(origin, Offset(size.width - 16, origin.dy), Paint()..color = Colors.white24..strokeWidth = 2);

    // Edificio / Árbol obstáculo
    final obsRad = obstacleAngleDeg * math.pi / 180.0;
    final obsTopX = origin.dx + maxLen * 0.55;
    final obsHeight = (maxLen * 0.55) * math.tan(obsRad.clamp(0.0, 1.35));
    final obsTopY = (origin.dy - obsHeight).clamp(12.0, origin.dy);

    canvas.drawRect(
      Rect.fromLTRB(obsTopX - 18, obsTopY, obsTopX + 18, origin.dy),
      Paint()..color = const Color(0xFF334155),
    );
    canvas.drawLine(origin, Offset(obsTopX, obsTopY), Paint()..color = Colors.redAccent..strokeWidth = 2);

    // Rayo del Sol
    final sunRad = sunElevationDeg * math.pi / 180.0;
    final sunX = origin.dx + maxLen * 0.85;
    final sunY = (origin.dy - (maxLen * 0.85) * math.tan(sunRad.clamp(0.0, 1.35))).clamp(12.0, origin.dy);

    canvas.drawLine(origin, Offset(sunX, sunY), Paint()..color = AppTheme.primary..strokeWidth = 2.5);
    canvas.drawCircle(Offset(sunX, sunY), 10, Paint()..color = AppTheme.primary);
  }

  @override
  bool shouldRepaint(covariant _ObstacleClinometerPainter oldDelegate) => true;
}
