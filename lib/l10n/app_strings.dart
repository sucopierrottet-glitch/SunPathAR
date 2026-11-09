class AppStrings {
  final String localeCode;
  final String appTitle;
  final String appSubtitle;
  final String enterApp;
  final String quickSolarCheck;

  // Navigation
  final String navDome;
  final String navShadows;
  final String navSaved;
  final String navSettings;

  // Solar Dome & AR
  final String solarDomeTitle;
  final String liveCompassMode;
  final String manualSimMode;
  final String solarElevation;
  final String solarAzimuth;
  final String sunriseLabel;
  final String solarNoonLabel;
  final String sunsetLabel;
  final String goldenHourLabel;
  final String dayLengthLabel;
  final String moonPhaseLabel;
  final String hourOfDayLabel;
  final String dayOfYearLabel;
  final String presetToday;
  final String presetSummerSolstice;
  final String presetEquinox;
  final String presetWinterSolstice;

  // Shadow & PV Calculator
  final String shadowCalcTitle;
  final String objectHeightLabel;
  final String shadowLengthResult;
  final String pvOptimalTiltResult;
  final String pvRowSpacingResult;
  final String siteNameLabel;
  final String saveStudyBtn;
  final String studySavedMsg;

  // Saved & PDF
  final String savedStudiesTitle;
  final String noSavedStudies;
  final String exportPdfBtn;
  final String signAndExportBtn;
  final String pdfReportTitle;
  final String pdfInspectorLabel;

  // Settings
  final String settingsTitle;
  final String languageTitle;
  final String languageSubtitle;
  final String locationPresetTitle;
  final String latitudeLabel;
  final String longitudeLabel;
  final String inspectorNameLabel;
  final String saveSettingsBtn;
  final String proEditionTitle;
  final String proEditionDesc;

  const AppStrings({
    required this.localeCode,
    required this.appTitle,
    required this.appSubtitle,
    required this.enterApp,
    required this.quickSolarCheck,
    required this.navDome,
    required this.navShadows,
    required this.navSaved,
    required this.navSettings,
    required this.solarDomeTitle,
    required this.liveCompassMode,
    required this.manualSimMode,
    required this.solarElevation,
    required this.solarAzimuth,
    required this.sunriseLabel,
    required this.solarNoonLabel,
    required this.sunsetLabel,
    required this.goldenHourLabel,
    required this.dayLengthLabel,
    required this.moonPhaseLabel,
    required this.hourOfDayLabel,
    required this.dayOfYearLabel,
    required this.presetToday,
    required this.presetSummerSolstice,
    required this.presetEquinox,
    required this.presetWinterSolstice,
    required this.shadowCalcTitle,
    required this.objectHeightLabel,
    required this.shadowLengthResult,
    required this.pvOptimalTiltResult,
    required this.pvRowSpacingResult,
    required this.siteNameLabel,
    required this.saveStudyBtn,
    required this.studySavedMsg,
    required this.savedStudiesTitle,
    required this.noSavedStudies,
    required this.exportPdfBtn,
    required this.signAndExportBtn,
    required this.pdfReportTitle,
    required this.pdfInspectorLabel,
    required this.settingsTitle,
    required this.languageTitle,
    required this.languageSubtitle,
    required this.locationPresetTitle,
    required this.latitudeLabel,
    required this.longitudeLabel,
    required this.inspectorNameLabel,
    required this.saveSettingsBtn,
    required this.proEditionTitle,
    required this.proEditionDesc,
  });

  static const AppStrings es = AppStrings(
    localeCode: 'es',
    appTitle: 'SUNPATH AR PRO',
    appSubtitle: 'Trayectoria Solar 3D, Sombras, Hora Dorada & Paneles',
    enterApp: 'Entrar a Bóveda Solar',
    quickSolarCheck: 'Cálculo de Sombra y Paneles',
    navDome: 'Bóveda 3D',
    navShadows: 'Sombras & FV',
    navSaved: 'Estudios',
    navSettings: 'Ajustes',
    solarDomeTitle: 'Bóveda Solar & Brújula AR',
    liveCompassMode: 'SENSORES EN VIVO',
    manualSimMode: 'MODO SIMULACIÓN',
    solarElevation: 'Elevación Solar',
    solarAzimuth: 'Azimut Solar',
    sunriseLabel: 'Amanecer',
    solarNoonLabel: 'Cenit Solar',
    sunsetLabel: 'Atardecer',
    goldenHourLabel: 'Hora Dorada',
    dayLengthLabel: 'Duración Día',
    moonPhaseLabel: 'Ilum. Lunar',
    hourOfDayLabel: 'Hora Solar Local',
    dayOfYearLabel: 'Día del Año (Estación)',
    presetToday: 'Hoy',
    presetSummerSolstice: 'Solsticio Verano',
    presetEquinox: 'Equinoccio',
    presetWinterSolstice: 'Solsticio Invierno',
    shadowCalcTitle: 'Proyección de Sombras & Solar FV',
    objectHeightLabel: 'Altura del Obstáculo / Panel (m)',
    shadowLengthResult: 'Longitud de Sombra Actual',
    pvOptimalTiltResult: 'Inclinación Óptima Panel FV',
    pvRowSpacingResult: 'Separación Mínima Entre Filas',
    siteNameLabel: 'Nombre del Sitio / Proyecto',
    saveStudyBtn: 'Guardar Estudio Solar',
    studySavedMsg: 'Estudio solar guardado localmente ✓',
    savedStudiesTitle: 'Estudios Solares Guardados',
    noSavedStudies: 'No hay estudios guardados aún.',
    exportPdfBtn: 'Reporte PDF',
    signAndExportBtn: 'Firmar y Exportar PDF',
    pdfReportTitle: 'INFORME TÉCNICO DE TRAYECTORIA SOLAR Y SOMBRAS',
    pdfInspectorLabel: 'Ingeniero / Evaluador Solar',
    settingsTitle: 'Ajustes & Coordenadas',
    languageTitle: 'IDIOMA DE LA APLICACIÓN',
    languageSubtitle: 'Selecciona el idioma para la interfaz y los reportes PDF.',
    locationPresetTitle: 'UBICACIÓN GEOGRÁFICA (100% OFFLINE)',
    latitudeLabel: 'Latitud (° N / -S)',
    longitudeLabel: 'Longitud (° E / -W)',
    inspectorNameLabel: 'Nombre del Profesional / Fotógrafo / Ingeniero',
    saveSettingsBtn: 'Guardar Configuración',
    proEditionTitle: 'SunPath AR PRO — Edición Desbloqueada',
    proEditionDesc: '100% Offline • Sin Anuncios • Sin Suscripciones • SimpleAppsPG',
  );

  static const AppStrings en = AppStrings(
    localeCode: 'en',
    appTitle: 'SUNPATH AR PRO',
    appSubtitle: '3D Sun Path, Shadow Calculator, Golden Hour & PV Tilt',
    enterApp: 'Open Solar Dome',
    quickSolarCheck: 'Shadow & Solar PV Calculator',
    navDome: '3D Dome',
    navShadows: 'Shadows & PV',
    navSaved: 'Studies',
    navSettings: 'Settings',
    solarDomeTitle: 'Solar Sky Dome & AR Compass',
    liveCompassMode: 'LIVE SENSORS',
    manualSimMode: 'SIMULATION MODE',
    solarElevation: 'Solar Elevation',
    solarAzimuth: 'Solar Azimuth',
    sunriseLabel: 'Sunrise',
    solarNoonLabel: 'Solar Noon',
    sunsetLabel: 'Sunset',
    goldenHourLabel: 'Golden Hour',
    dayLengthLabel: 'Day Length',
    moonPhaseLabel: 'Lunar Illum.',
    hourOfDayLabel: 'Local Solar Time',
    dayOfYearLabel: 'Day of Year (Season)',
    presetToday: 'Today',
    presetSummerSolstice: 'Summer Solstice',
    presetEquinox: 'Equinox',
    presetWinterSolstice: 'Winter Solstice',
    shadowCalcTitle: 'Shadow Projection & Solar PV Sizing',
    objectHeightLabel: 'Obstacle / Panel Height (m)',
    shadowLengthResult: 'Current Shadow Length',
    pvOptimalTiltResult: 'Optimal PV Panel Tilt',
    pvRowSpacingResult: 'Min Inter-Row PV Spacing',
    siteNameLabel: 'Site / Project Name',
    saveStudyBtn: 'Save Solar Study',
    studySavedMsg: 'Solar study saved locally ✓',
    savedStudiesTitle: 'Saved Solar Site Studies',
    noSavedStudies: 'No saved solar studies yet.',
    exportPdfBtn: 'PDF Report',
    signAndExportBtn: 'Sign & Export PDF',
    pdfReportTitle: 'SOLAR PATH & SHADOW TECHNICAL REPORT',
    pdfInspectorLabel: 'Solar Engineer / Surveyor',
    settingsTitle: 'Settings & Coordinates',
    languageTitle: 'APPLICATION LANGUAGE',
    languageSubtitle: 'Select your preferred language for UI and PDF reports.',
    locationPresetTitle: 'GEOGRAPHIC LOCATION (100% OFFLINE)',
    latitudeLabel: 'Latitude (° N / -S)',
    longitudeLabel: 'Longitude (° E / -W)',
    inspectorNameLabel: 'Professional / Photographer / Engineer Name',
    saveSettingsBtn: 'Save Settings',
    proEditionTitle: 'SunPath AR PRO — Unlocked Edition',
    proEditionDesc: '100% Offline • Zero Ads • No Subscriptions • SimpleAppsPG',
  );

  static const AppStrings pt = AppStrings(
    localeCode: 'pt',
    appTitle: 'SUNPATH AR PRO',
    appSubtitle: 'Trajetória Solar 3D, Sombras, Hora Dourada & Painéis',
    enterApp: 'Abrir Abóbada Solar',
    quickSolarCheck: 'Cálculo de Sombras e Painéis FV',
    navDome: 'Abóbada 3D',
    navShadows: 'Sombras & FV',
    navSaved: 'Estudos',
    navSettings: 'Ajustes',
    solarDomeTitle: 'Abóbada Solar & Bússola AR',
    liveCompassMode: 'SENSORES AO VIVO',
    manualSimMode: 'MODO SIMULAÇÃO',
    solarElevation: 'Elevação Solar',
    solarAzimuth: 'Azimute Solar',
    sunriseLabel: 'Nascer do Sol',
    solarNoonLabel: 'Meio-Dia Solar',
    sunsetLabel: 'Pôr do Sol',
    goldenHourLabel: 'Hora Dourada',
    dayLengthLabel: 'Duração do Dia',
    moonPhaseLabel: 'Ilum. Lunar',
    hourOfDayLabel: 'Hora Solar Local',
    dayOfYearLabel: 'Dia do Ano (Estação)',
    presetToday: 'Hoje',
    presetSummerSolstice: 'Solstício Verão',
    presetEquinox: 'Equinócio',
    presetWinterSolstice: 'Solstício Inverno',
    shadowCalcTitle: 'Projeção de Sombras & Solar FV',
    objectHeightLabel: 'Altura do Obstáculo / Painel (m)',
    shadowLengthResult: 'Comprimento da Sombra Atual',
    pvOptimalTiltResult: 'Inclinação Ideal Painel FV',
    pvRowSpacingResult: 'Espaçamento Mínimo Entre Fileiras',
    siteNameLabel: 'Nome do Local / Projeto',
    saveStudyBtn: 'Salvar Estudo Solar',
    studySavedMsg: 'Estudo solar salvo localmente ✓',
    savedStudiesTitle: 'Estudos Solares Salvos',
    noSavedStudies: 'Nenhum estudo salvo ainda.',
    exportPdfBtn: 'Relatório PDF',
    signAndExportBtn: 'Assinar e Exportar PDF',
    pdfReportTitle: 'RELATÓRIO TÉCNICO DE TRAJETÓRIA SOLAR E SOMBRAS',
    pdfInspectorLabel: 'Engenheiro / Avaliador Solar',
    settingsTitle: 'Ajustes & Coordenadas',
    languageTitle: 'IDIOMA DO APLICATIVO',
    languageSubtitle: 'Selecione o idioma para a interface e relatórios PDF.',
    locationPresetTitle: 'LOCALIZAÇÃO GEOGRÁFICA (100% OFFLINE)',
    latitudeLabel: 'Latitude (° N / -S)',
    longitudeLabel: 'Longitude (° E / -W)',
    inspectorNameLabel: 'Nome do Profissional / Fotógrafo / Engenheiro',
    saveSettingsBtn: 'Salvar Configurações',
    proEditionTitle: 'SunPath AR PRO — Edição Desbloqueada',
    proEditionDesc: '100% Offline • Sem Anúncios • Sem Assinaturas • SimpleAppsPG',
  );

  static AppStrings get(String code) {
    switch (code) {
      case 'en':
        return en;
      case 'pt':
        return pt;
      default:
        return es;
    }
  }
}
