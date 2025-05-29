// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:work_hours/core/app.dart';
import 'package:work_hours/data/repositories/work_hours_repository.dart';
import 'package:work_hours/features/settings/settings_controller.dart';
import 'package:work_hours/features/salary/salary_controller.dart';
import 'package:work_hours/features/home/home_controller.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkHoursRepository>(
            create: (context) => WorkHoursRepository(),
          ),
          ChangeNotifierProvider<SettingsController>(
            create: (context) => SettingsController(
              context.read<WorkHoursRepository>(),
            ),
          ),
          ChangeNotifierProvider<SalaryController>(
            create: (context) => SalaryController(
              context.read<WorkHoursRepository>(),
            ),
          ),
          ChangeNotifierProvider<HomeController>(
            create: (context) => HomeController(
              context.read<WorkHoursRepository>(),
            ),
          ),
        ],
        child: const App(),
      ),
    );

    // Verify that the app builds successfully
    expect(find.byType(App), findsOneWidget);
  });
}
