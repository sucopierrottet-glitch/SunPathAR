import 'paywall_screen.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../calculators/solar_calculator.dart';
import '../services/pdf_report_service.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

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
      TextEditingController(text: 'Estudio Fotovoltaico & Sombra');
  late TextEditingController _latCtrl;
  late TextEditingController _lonCtrl;
  late TextEditingController _inspectorCtrl;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
        final s = store.strings;

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
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentIndex == 0
                        ? s.solarDomeTitle
                        : _currentIndex == 1
                            ? s.shadowCalcTitle
                            : _currentIndex == 2
                                ? s.savedStudiesTitle
                                : s.settingsTitle,
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
                    sensor.useLiveSensors ? s.liveCompassMode : s.manualSimMode,
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
                    _buildShadowAndPvTab(pos, store),
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
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.wb_twilight_rounded),
                selectedIcon: const Icon(Icons.wb_twilight_rounded,
                    color: AppTheme.primary),
                label: s.navDome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.solar_power_outlined),
                selectedIcon:
                    const Icon(Icons.solar_power_rounded, color: AppTheme.primary),
                label: s.navShadows,
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_copy_outlined),
                selectedIcon:
                    const Icon(Icons.folder_rounded, color: AppTheme.primary),
                label: s.navSaved,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon:
                    const Icon(Icons.settings_rounded, color: AppTheme.primary),
                label: s.navSettings,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSolarDomeTab(
    SolarPositionResult pos,
    List<SolarPositionResult> arc,
    StorageService store,
    SensorService sensor,
  ) {
    final s = store.strings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3D Solar Sky Dome & AR Compass Canvas
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

          // Live Sensor Status Banner
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
                      'Brújula en vivo: ' + sensor.compassAzimuth.toStringAsFixed(0) + '° (' + _getCardinalLabel(sensor.compassAzimuth) + ') • Inclinación: ' + sensor.devicePitch.toStringAsFixed(0) + '°',
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

          // Live Elevation & Azimuth KPI Row
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  s.solarElevation,
                  '${pos.elevationDeg.toStringAsFixed(1)}°',
                  pos.elevationDeg > 0 ? AppTheme.primary : AppTheme.accent,
                  Icons.height_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  s.solarAzimuth,
                  '${pos.azimuthDeg.toStringAsFixed(1)}°',
                  AppTheme.accent,
                  Icons.explore_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sliders Card (Hour of Day & Day of Year)
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
                    Text(
                      s.hourOfDayLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${_solarHour.floor().toString().padLeft(2, '0')}:${((_solarHour % 1) * 60).round().toString().padLeft(2, '0')} h',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _solarHour,
                  min: 5.0,
                  max: 21.0,
                  divisions: 64,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _solarHour = v),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.dayOfYearLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      'Día #$_dayOfYear (δ ${pos.declinationDeg.toStringAsFixed(1)}°)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _dayOfYear.toDouble(),
                  min: 1,
                  max: 365,
                  activeColor: AppTheme.accent,
                  onChanged: (v) => setState(() => _dayOfYear = v.round()),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: Text(s.presetSummerSolstice),
                      onPressed: () => setState(() => _dayOfYear = 172),
                    ),
                    ActionChip(
                      label: Text(s.presetEquinox),
                      onPressed: () => setState(() => _dayOfYear = 80),
                    ),
                    ActionChip(
                      label: Text(s.presetWinterSolstice),
                      onPressed: () => setState(() => _dayOfYear = 355),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Ephemeris Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _miniStat(s.sunriseLabel, pos.sunriseTime, Icons.wb_twilight),
              _miniStat(s.sunsetLabel, pos.sunsetTime, Icons.nights_stay_rounded),
              _miniStat(
                  s.goldenHourLabel, pos.goldenHourEvening, Icons.camera_alt_rounded),
              _miniStat(s.moonPhaseLabel,
                  '${pos.moonIlluminationPercent.toStringAsFixed(0)}%', Icons.brightness_3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShadowAndPvTab(SolarPositionResult pos, StorageService store) {
    final s = store.strings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                TextField(
                  controller: _siteNameCtrl,
                  decoration: InputDecoration(
                    labelText: s.siteNameLabel,
                    prefixIcon: const Icon(Icons.place_rounded,
                        color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.objectHeightLabel,
                        style: const TextStyle(color: AppTheme.textSecondary)),
                    Text(
                      '${_objectHeight.toStringAsFixed(1)} m',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _objectHeight,
                  min: 0.5,
                  max: 25.0,
                  divisions: 49,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _objectHeight = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _metricCard(
            s.shadowLengthResult,
            '${pos.shadowLengthMeters.toStringAsFixed(2)} m',
            AppTheme.primary,
            Icons.straighten_rounded,
          ),
          const SizedBox(height: 10),
          _metricCard(
            s.pvOptimalTiltResult,
            '${pos.optimalPvTiltDeg.toStringAsFixed(1)}°',
            AppTheme.success,
            Icons.solar_power_rounded,
          ),
          const SizedBox(height: 10),
          _metricCard(
            s.pvRowSpacingResult,
            '${pos.minPvRowSpacingMeters.toStringAsFixed(2)} m',
            AppTheme.accent,
            Icons.swap_horiz_rounded,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () async {
              final rec = SolarStudyRecord(
                id: 'SP-${DateTime.now().millisecondsSinceEpoch % 10000}',
                siteName: _siteNameCtrl.text.trim().isEmpty
                    ? 'Estudio Solar'
                    : _siteNameCtrl.text.trim(),
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
              await store.saveStudy(rec);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(s.studySavedMsg),
                    backgroundColor: AppTheme.success,
                  ),
                );
                setState(() => _currentIndex = 2);
              }
            },
            icon: const Icon(Icons.save_rounded, color: Colors.black),
            label: Text(
              s.saveStudyBtn,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedStudiesTab(StorageService store) {
    final s = store.strings;
    if (store.studies.isEmpty) {
      return Center(
        child: Text(s.noSavedStudies,
            style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: store.studies.length,
      itemBuilder: (context, index) {
        final item = store.studies[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                  Expanded(
                    child: Text(
                      item.siteName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.id,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Elev: ${item.elevationDeg.toStringAsFixed(1)}° • Azimut: ${item.azimuthDeg.toStringAsFixed(1)}° • Sombra: ${item.shadowLengthMeters.toStringAsFixed(2)}m',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openSignAndShareModal(item, store),
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          size: 18, color: Colors.black),
                      label: Text(
                        s.signAndExportBtn,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textMuted),
                    onPressed: () => store.deleteStudy(item.id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSignAndShareModal(
      SolarStudyRecord study, StorageService store) async {
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
              Text(
                store.strings.signAndExportBtn,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Signature(
                  controller: sigController,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () async {
                  String? sigB64;
                  if (sigController.isNotEmpty) {
                    final bytes = await sigController.toPngBytes();
                    if (bytes != null) sigB64 = base64Encode(bytes);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  final signedRecord = SolarStudyRecord(
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
                    signatureBase64: sigB64,
                  );
                  await PdfReportService.shareStudyPdf(
                    study: signedRecord,
                    inspectorName: store.inspectorName,
                    localeCode: store.localeCode,
                  );
                },
                icon: const Icon(Icons.share_rounded, color: Colors.black),
                label: Text(
                  store.strings.exportPdfBtn,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab(StorageService store) {
    final s = store.strings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pro Unlocked Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF047857)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.proEditionTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.proEditionDesc,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.languageTitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                _langBtn(store, 'es', '🇪🇸', 'Español'),
                const SizedBox(width: 8),
                _langBtn(store, 'en', '🇺🇸', 'English'),
                const SizedBox(width: 8),
                _langBtn(store, 'pt', '🇧🇷', 'Português'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.locationPresetTitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: CityLocationPreset.presets.map((city) {
                    return ActionChip(
                      label:
                          Text(city.name, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        _latCtrl.text = city.latitude.toStringAsFixed(4);
                        _lonCtrl.text = city.longitude.toStringAsFixed(4);
                        store.updateSettings(
                          latitude: city.latitude,
                          longitude: city.longitude,
                          inspectorName: _inspectorCtrl.text,
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: s.latitudeLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lonCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: s.longitudeLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _inspectorCtrl,
                  decoration: InputDecoration(labelText: s.inspectorNameLabel),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final lat = double.tryParse(_latCtrl.text) ?? 40.4168;
                      final lon = double.tryParse(_lonCtrl.text) ?? -3.7038;
                      store.updateSettings(
                        latitude: lat,
                        longitude: lon,
                        inspectorName: _inspectorCtrl.text,
                      );
                    },
                    icon: const Icon(Icons.check_rounded, color: Colors.black),
                    label: Text(
                      s.saveSettingsBtn,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langBtn(
      StorageService store, String code, String flag, String label) {
    final selected = store.localeCode == code;
    return Expanded(
      child: InkWell(
        onTap: () => store.setLocale(code),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.2)
                : AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.darkBorder,
            ),
          ),
          child: Column(
            children: [
              Text(flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
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

  Widget _metricCard(
      String title, String value, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
                Text(val,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

    // Background Sky Gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF16233B),
          const Color(0xFF0B111E),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR));
    canvas.drawCircle(Offset(cx, cy), maxR, bgPaint);

    // Outer Horizon Compass Circle
    final ringPaint = Paint()
      ..color = const Color(0xFF2A3A54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), maxR, ringPaint);
    canvas.drawCircle(Offset(cx, cy), maxR * 0.66, ringPaint..strokeWidth = 1..color = const Color(0xFF1E293B));
    canvas.drawCircle(Offset(cx, cy), maxR * 0.33, ringPaint);

    // Crosshairs
    canvas.drawLine(
        Offset(cx - maxR, cy), Offset(cx + maxR, cy), ringPaint);
    canvas.drawLine(
        Offset(cx, cy - maxR), Offset(cx, cy + maxR), ringPaint);

    // Cardinal Points (N, S, E, W) rotated by device compass heading
    final rotationRad = isLive ? (-compassHeading * math.pi / 180.0) : 0.0;

    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 0, 'N', Colors.redAccent, isBold: true);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 90, 'E', AppTheme.textSecondary);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 180, 'S', AppTheme.textSecondary);
    _drawCardinal(canvas, cx, cy, maxR, rotationRad, 270, 'W', AppTheme.textSecondary);

    // Draw Daily Solar Trajectory Path
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

    // Draw Current Sun Position
    final sunElev = currentPos.elevationDeg.clamp(0.0, 90.0);
    final sunPos =
        _polarToScreen(cx, cy, maxR, currentPos.azimuthDeg, sunElev, rotationRad);

    // Sun Glow
    canvas.drawCircle(
      sunPos,
      20,
      Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      sunPos,
      10,
      Paint()..color = const Color(0xFFFBBF24),
    );

    // Ray to center
    canvas.drawLine(
      Offset(cx, cy),
      sunPos,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Center Device Marker
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

  Offset _polarToScreen(
      double cx, double cy, double maxR, double azDeg, double elDeg, double baseRotation) {
    final r = maxR * (1.0 - (elDeg.clamp(0.0, 90.0) / 90.0));
    final rad = (azDeg - 90.0) * math.pi / 180.0 + baseRotation;
    return Offset(cx + r * math.cos(rad), cy + r * math.sin(rad));
  }

  @override
  bool shouldRepaint(covariant _SolarSkyDomePainter oldDelegate) => true;
}
