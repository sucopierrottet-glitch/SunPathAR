import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../calculators/solar_calculator.dart';
import '../services/pdf_report_service.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
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
  double _objectHeight = 3.0;
  final TextEditingController _siteNameCtrl =
      TextEditingController(text: 'Mi Proyecto Solar & Hogar');
  late TextEditingController _latCtrl;
  late TextEditingController _lonCtrl;
  late TextEditingController _inspectorCtrl;

  // Cuidado de Plantas Interactivo
  int _selectedPlantType = 0; // 0 = Suculentas/Cactus, 1 = Monstera/Ficus, 2 = Orquídeas/Helechos
  // Detector de Luz de Vivienda
  int _selectedRoomOrientation = 0; // 0 = Ventana Este, 1 = Ventana Sur, 2 = Ventana Oeste, 3 = Ventana Norte

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    final now = DateTime.now();
    _dayOfYear = int.parse(
        ((now.difference(DateTime(now.year, 1, 1)).inDays) + 1).toString());
    _solarHour = (now.hour + (now.minute / 60.0)).clamp(0.0, 24.0);

    final store = StorageService.instance;
    _latCtrl = TextEditingController(text: store.latitude.toStringAsFixed(4));
    _lonCtrl = TextEditingController(text: store.longitude.toStringAsFixed(4));
    _inspectorCtrl = TextEditingController(text: store.inspectorName);
  }

  @override
  void dispose() {
    _siteNameCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _inspectorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([StorageService.instance, SensorService.instance]),
      builder: (context, _) {
        final store = StorageService.instance;
        final sensor = SensorService.instance;

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
                const Icon(Icons.wb_sunny_rounded,
                    color: AppTheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _currentIndex == 0
                        ? '☀️ Brújula & Bóveda Solar'
                        : _currentIndex == 1
                            ? '📸 Fotos, UV & Vitamina D'
                            : _currentIndex == 2
                                ? '🏡 Casas, Plantas & Sombras'
                                : _currentIndex == 3
                                    ? '📁 Reportes & Estudios'
                                    : '⚙️ Ajustes',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ActionChip(
                  avatar: Icon(
                    sensor.useLiveSensors
                        ? Icons.explore_rounded
                        : Icons.tune_rounded,
                    size: 16,
                    color: sensor.useLiveSensors
                        ? AppTheme.success
                        : AppTheme.primary,
                  ),
                  label: Text(
                    sensor.useLiveSensors ? 'BRÚJULA EN VIVO' : 'SIMULADOR',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          size: 16,
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
                    _buildSolarDomeTab(pos, arcPoints, store, sensor),
                    _buildLifestylePhotoHealthTab(pos, store),
                    _buildHomeAndPlantsTab(pos, store),
                    _buildSavedStudiesTab(store),
                    _buildSettingsTab(store),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            backgroundColor: AppTheme.darkSurface,
            indicatorColor: AppTheme.primary.withValues(alpha: 0.2),
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.wb_twilight_rounded),
                selectedIcon: Icon(Icons.wb_twilight_rounded, color: AppTheme.primary),
                label: 'Bóveda 3D',
              ),
              NavigationDestination(
                icon: Icon(Icons.camera_alt_outlined),
                selectedIcon: Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                label: 'Fotos & UV',
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

  // ==========================================
  // PESTAÑA 1: BÓVEDA 3D Y BRÚJULA EN VIVO
  // ==========================================
  Widget _buildSolarDomeTab(
    SolarPositionResult pos,
    List<SolarPositionResult> arc,
    StorageService store,
    SensorService sensor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Estado Dinámico del Sol
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: AppTheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pos.sunStatusDescription,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Amanece: ${pos.sunriseTime} • Cenit: ${pos.solarNoonTime} • Ocaso: ${pos.sunsetTime}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Indicador de Brújula en Vivo
          if (sensor.useLiveSensors)
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
                      'Brújula en vivo: ${sensor.compassAzimuth.toStringAsFixed(0)}° (${_getCardinalLabel(sensor.compassAzimuth)}) • Inclinación: ${sensor.devicePitch.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Lienzo de la Bóveda Celeste
          Container(
            height: 290,
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
          const SizedBox(height: 14),

          // KPIs Clave
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Elevación Solar',
                  '${pos.elevationDeg.toStringAsFixed(1)}°',
                  pos.elevationDeg > 0 ? AppTheme.primary : AppTheme.accent,
                  Icons.height_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Orientación (Azimut)',
                  '${pos.azimuthDeg.toStringAsFixed(1)}° (${_getCardinalLabel(pos.azimuthDeg)})',
                  AppTheme.accent,
                  Icons.explore_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Controles de Simulación (Hora y Fecha)
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
                    const Text(
                      'Hora del Día (Simulación Solar)',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    ),
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
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Día del Año (Estaciones)',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    ),
                    Text(
                      'Día $_dayOfYear / 365',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.accent),
                    ),
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
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Hoy', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        final n = DateTime.now();
                        setState(() {
                          _dayOfYear = n.difference(DateTime(n.year, 1, 1)).inDays + 1;
                          _solarHour = (n.hour + (n.minute / 60.0)).clamp(0.0, 24.0);
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Solsticio Verano', style: TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _dayOfYear = 172),
                    ),
                    ActionChip(
                      label: const Text('Equinoccio', style: TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _dayOfYear = 80),
                    ),
                    ActionChip(
                      label: const Text('Solsticio Invierno', style: TextStyle(fontSize: 11)),
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

  // ==========================================
  // PESTAÑA 2: FOTOGRAFÍA, UV & VITAMINA D
  // ==========================================
  Widget _buildLifestylePhotoHealthTab(SolarPositionResult pos, StorageService store) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta Golden Hour / Blue Hour
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB45309), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.camera_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'FOTOGRAFÍA & REDES SOCIALES',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Golden Hour (Hora Dorada de la Tarde)',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  pos.goldenHourEvening,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🌅 Mañana (Amanecer)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(pos.goldenHourMorning, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🌌 Hora Azul (Crepúsculo)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(pos.blueHourEvening, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tips_and_updates_rounded, color: Colors.amberAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Apunta tu cámara a ${pos.azimuthDeg.toStringAsFixed(0)}° (${_getCardinalLabel(pos.azimuthDeg)}) para fotos cálidas y siluetas.',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tarjeta de Salud: Vitamina D y Exposición UV
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: pos.isVitaminDOptimal ? AppTheme.success.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        pos.isVitaminDOptimal ? Icons.health_and_safety_rounded : Icons.wb_sunny_outlined,
                        color: pos.isVitaminDOptimal ? AppTheme.success : Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SALUD & VITAMINA D',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            pos.isVitaminDOptimal ? 'Ventana Óptima Activa ✓' : 'Sol Bajo para Vitamina D',
                            style: TextStyle(
                              color: pos.isVitaminDOptimal ? AppTheme.success : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _healthMiniCard(
                        'Índice UV Estimado',
                        '${pos.uvIndexEstimate} / 12',
                        pos.uvIndexEstimate > 7 ? Colors.redAccent : (pos.uvIndexEstimate > 4 ? Colors.amber : AppTheme.success),
                        Icons.shield_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _healthMiniCard(
                        'Tiempo Seguro de Sol',
                        '${pos.safeSunMinutes} min',
                        AppTheme.primary,
                        Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  pos.isVitaminDOptimal
                      ? 'Con el sol a ${pos.elevationDeg.toStringAsFixed(0)}°, tus brazos y rostro sintetizan vitamina D eficientemente en solo 10-15 minutos.'
                      : 'El sol está a menos de 38° de altura; la atmósfera filtra los rayos UVB. Excelente para pasear sin riesgo de quemaduras.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Consejos Rápidos de Vida Cotidiana
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
                const Row(
                  children: [
                    Icon(Icons.directions_car_rounded, color: AppTheme.accent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ESTACIONAMIENTO & SOMBRA INTELIGENTE',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'El sol se pondrá por el ${_getCardinalLabel(pos.azimuthDeg)} (${pos.azimuthDeg.toStringAsFixed(0)}°). Si estacionas junto a un muro o edificio ubicado al oeste, tu auto tendrá sombra natural por la tarde.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 3: HOGAR, PLANTAS & SOMBRAS
  // ==========================================
  Widget _buildHomeAndPlantsTab(SolarPositionResult pos, StorageService store) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Buscador de Luz para Casas y Pisos
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.apartment_rounded, color: AppTheme.primary, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'EVALUADOR DE LUZ PARA CASAS Y PISOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '¿Estás visitando una vivienda para alquilar o comprar? Selecciona hacia dónde mira la ventana o balcón:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _orientationChip(0, 'Ventana Este (Amanecer)', Icons.wb_twilight_rounded),
                      const SizedBox(width: 8),
                      _orientationChip(1, 'Ventana Sur (Sol Máximo)', Icons.wb_sunny_rounded),
                      const SizedBox(width: 8),
                      _orientationChip(2, 'Ventana Oeste (Tardes)', Icons.nightlight_round),
                      const SizedBox(width: 8),
                      _orientationChip(3, 'Ventana Norte (Luz Difusa)', Icons.cloud_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRoomLightAdvice(_selectedRoomOrientation),
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Asistente Solar para Plantas de Interior
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
                const Row(
                  children: [
                    Icon(Icons.eco_rounded, color: AppTheme.success, size: 22),
                    SizedBox(width: 10),
                    Text(
                      '¿DÓNDE PONER MIS PLANTAS?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Suculentas', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 1, label: Text('Monsteras', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 2, label: Text('Orquídeas', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_selectedPlantType},
                  onSelectionChanged: (set) => setState(() => _selectedPlantType = set.first),
                ),
                const SizedBox(height: 12),
                Text(
                  _getPlantAdvice(_selectedPlantType),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Calculadora de Sombras de Obstáculos (Árboles, Muros, Paneles)
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
                const Text(
                  'CÁLCULO DE SOMBRAS & PANELES SOLARES',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Altura de obstáculo o muro:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Text('${_objectHeight.toStringAsFixed(1)} m', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Slider(
                  value: _objectHeight,
                  min: 0.5,
                  max: 15.0,
                  divisions: 29,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _objectHeight = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard('Longitud Sombra', '${pos.shadowLengthMeters.toStringAsFixed(2)} m', AppTheme.primary, Icons.straighten_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricCard('Inclinación Panel', '${pos.optimalPvTiltDeg.toStringAsFixed(1)}°', AppTheme.accent, Icons.solar_power_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _siteNameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Nombre del sitio / Proyecto',
                    labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    prefixIcon: Icon(Icons.bookmark_border_rounded, color: AppTheme.primary, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final study = SolarStudyRecord(
                      id: 'SP-${DateTime.now().millisecondsSinceEpoch % 10000}',
                      siteName: _siteNameCtrl.text.trim().isEmpty ? 'Proyecto Solar' : _siteNameCtrl.text.trim(),
                      latitude: store.latitude,
                      longitude: store.longitude,
                      dayOfYear: _dayOfYear,
                      solarHour: _solarHour,
                      objectHeightMeters: _objectHeight,
                      elevationDeg: pos.elevationDeg,
                      azimuthDeg: pos.azimuthDeg,
                      shadowLengthMeters: pos.shadowLengthMeters,
                      optimalTiltDeg: pos.optimalPvTiltDeg,
                      minRowSpacingMeters: pos.minPvRowSpacingMeters,
                      createdAtIso: DateTime.now().toIso8601String(),
                    );
                    await store.saveStudy(study);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Estudio guardado correctamente ✓'), backgroundColor: AppTheme.success),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded, color: Colors.black, size: 18),
                  label: const Text('Guardar Estudio en Historial', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 4: ESTUDIOS Y REPORTES PDF
  // ==========================================
  Widget _buildSavedStudiesTab(StorageService store) {
    if (store.studies.isEmpty) {
      return const Center(
        child: Text('No hay estudios guardados aún.', style: TextStyle(color: AppTheme.textMuted)),
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
                  'Elev: ${item.elevationDeg.toStringAsFixed(1)}° • Azimut: ${item.azimuthDeg.toStringAsFixed(1)}° • Sombra: ${item.shadowLengthMeters.toStringAsFixed(2)}m',
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

  // ==========================================
  // PESTAÑA 5: AJUSTES & UBICACIÓN
  // ==========================================
  Widget _buildSettingsTab(StorageService store) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Pro
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
          const SizedBox(height: 20),

          // Coordenadas
          const Text('UBICACIÓN GEOGRÁFICA (100% OFFLINE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
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
                  decoration: const InputDecoration(labelText: 'Nombre / Profesional en Reportes', isDense: true),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    final lat = double.tryParse(_latCtrl.text) ?? store.latitude;
                    final lon = double.tryParse(_lonCtrl.text) ?? store.longitude;
                    store.updateSettings(latitude: lat, longitude: lon, inspectorName: _inspectorCtrl.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Configuración guardada ✓'), backgroundColor: AppTheme.success),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('Guardar Ubicación', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Presets de Ciudades
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CityLocationPreset.presets.map((c) {
              return ActionChip(
                label: Text(c.name, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  _latCtrl.text = c.latitude.toStringAsFixed(4);
                  _lonCtrl.text = c.longitude.toStringAsFixed(4);
                  store.updateSettings(latitude: c.latitude, longitude: c.longitude, inspectorName: _inspectorCtrl.text);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Modales y Helpers
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

  Widget _orientationChip(int index, String label, IconData icon) {
    final isSelected = _selectedRoomOrientation == index;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.black : AppTheme.primary),
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white)),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.darkCard,
      onSelected: (_) => setState(() => _selectedRoomOrientation = index),
    );
  }

  String _getRoomLightAdvice(int index) {
    switch (index) {
      case 0:
        return '☀️ Ventana al Este: Luz suave y fresca al amanecer. Ideal para dormitorios o cocinas; la habitación se mantendrá fresca por la tarde.';
      case 1:
        return '🔥 Ventana al Sur: Máxima entrada de sol y calor casi todo el día (en hemisferio norte). Muy luminosa en invierno, excelente para salas de estar y plantas.';
      case 2:
        return '🌇 Ventana al Oeste: Recibe el sol de la tarde cuando el ambiente ya está caliente. Habitación calurosa en verano pero con hermosas puestas de sol.';
      default:
        return '☁️ Ventana al Norte: Luz difusa y constante sin sol directo cegador. Excelente para estudios de trabajo, oficinas o pintura.';
    }
  }

  String _getPlantAdvice(int type) {
    switch (type) {
      case 0:
        return '🌵 Suculentas & Cactus: Requieren sol directo 4 a 6 horas diarias. Colócalas junto a ventanas orientadas al Sur o al Este. Evita rincones oscuros.';
      case 1:
        return '🌿 Monstera, Ficus & Potos: Prefieren luz brillante pero indirecta. Cerca de una ventana al Este o a 1 metro de una ventana al Sur con cortina ligera.';
      default:
        return '🌸 Orquídeas & Helechos: Luz suave filtrada. El sol directo quema sus hojas rápidamente. Ventanas al Norte o baños iluminados son ideales.';
    }
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
                Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
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
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c)),
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

// Painter de la Bóveda Celeste
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

    // Fondo degradado del cielo
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF16233B), Color(0xFF0B111E)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR));
    canvas.drawCircle(Offset(cx, cy), maxR, bgPaint);

    // Círculos de elevación
    final ringPaint = Paint()
      ..color = const Color(0xFF2A3A54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), maxR, ringPaint);
    canvas.drawCircle(Offset(cx, cy), maxR * 0.66, ringPaint..strokeWidth = 1..color = const Color(0xFF1E293B));
    canvas.drawCircle(Offset(cx, cy), maxR * 0.33, ringPaint);

    // Cruz de coordenadas
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), ringPaint);
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), ringPaint);

    // Puntos Cardinales rotados con la brújula
    final rotationRad = isLive ? (-compassHeading * math.pi / 180.0) : 0.0;

    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 0, 'N', Colors.redAccent, isBold: true);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 90, 'E', AppTheme.textSecondary);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 180, 'S', AppTheme.textSecondary);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 270, 'W', AppTheme.textSecondary);

    // Trayectoria diaria del Sol
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

    final arcPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(path, arcPaint);

    // Posición del Sol
    final sunElev = currentPos.elevationDeg.clamp(0.0, 90.0);
    final sunPos = _polarToScreen(cx, cy, maxR, currentPos.azimuthDeg, sunElev, rotationRad);

    // Resplandor del Sol
    canvas.drawCircle(sunPos, 20, Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.3));
    canvas.drawCircle(sunPos, 10, Paint()..color = const Color(0xFFFBBF24));

    // Rayo al centro
    canvas.drawLine(
      Offset(cx, cy),
      sunPos,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Marcador central
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = isLive ? AppTheme.success : AppTheme.primary);
  }

  void _drawCardinal(Canvas canvas, double cx, double cy, double maxR, double baseRotation, double deg, String label, Color color, {bool isBold = false}) {
    final rad = (deg - 90.0) * math.pi / 180.0 + baseRotation;
    final r = maxR - 12;
    final pos = Offset(cx + r * math.cos(rad), cy + r * math.sin(rad));

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: isBold ? 14 : 11,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
        ),
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
