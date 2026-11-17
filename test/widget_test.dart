import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunpathar/calculators/solar_calculator.dart';
import 'package:sunpathar/main.dart';
import 'package:sunpathar/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SolarCalculator computes valid solar elevation, shadow, and PV tilt', () {
    final res = SolarCalculator.calculate(
      latitude: 40.4168,
      longitude: -3.7038,
      dayOfYear: 172, // Summer Solstice
      solarHour: 12.0, // Solar Noon
      objectHeightMeters: 3.0,
    );
    expect(res.elevationDeg, greaterThan(65.0));
    expect(res.shadowLengthMeters, greaterThan(0.5));
    expect(res.shadowLengthMeters, lessThan(2.0));
    expect(res.optimalPvTiltDeg, greaterThan(30.0));
    expect(res.dayLengthHours, greaterThan(13.0));
  });

  test('SolarCalculator computes window sunlight and camera alignment accurately', () {
    final arc = SolarCalculator.calculateDailyArc(
      latitude: 40.4168,
      longitude: -3.7038,
      dayOfYear: 172,
    );
    final southWindow = SolarCalculator.calculateWindowSunlight(
      windowAzimuth: 180.0,
      dailyArc: arc,
    );
    expect(southWindow.directSunHours, greaterThan(4.0));

    final backCamAlign = SolarCalculator.calculateCameraAlignment(
      sunAzimuth: 270.0,
      sunElevation: 15.0,
      deviceAzimuth: 90.0, // Facing away from sun -> illuminando rostro
      cameraElevation: 5.0,
      isFrontCamera: false,
      photoMode: 0,
    );
    expect(backCamAlign.isAligned, isTrue);
    expect(backCamAlign.alignmentScore, greaterThanOrEqualTo(90));

    final frontCamAlign = SolarCalculator.calculateCameraAlignment(
      sunAzimuth: 270.0,
      sunElevation: 15.0,
      deviceAzimuth: 270.0, // Front cam facing sun -> selfie iluminado
      cameraElevation: 7.0,
      isFrontCamera: true,
      photoMode: 0,
    );
    expect(frontCamAlign.isAligned, isTrue);
  });

  testWidgets('WelcomeLandingScreen navigates to HomeNavigationScreen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();

    await tester.pumpWidget(const SunPathArApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btnWelcomeEnter')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btnWelcomeEnter')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);

    // Navigate to Fotos & Auto and Hogar & Sol tabs to verify rendering without overflow/errors
    await tester.tap(find.text('Fotos & Auto'));
    await tester.pumpAndSettle();
    expect(find.text('DIRECTOR DE FOTOGRAFÍA AR'), findsOneWidget);
    expect(find.text('RADAR DE ESTACIONAMIENTO A LA SOMBRA'), findsOneWidget);

    await tester.tap(find.text('Hogar & Sol'));
    await tester.pumpAndSettle();
    expect(find.text('ESCÁNER DE VENTANAS EN VIVO'), findsOneWidget);
    expect(find.text('MEDIDOR DE LUZ PARA PLANTAS (SENSOR LUX)'), findsOneWidget);
  });
}
