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
  });
}
