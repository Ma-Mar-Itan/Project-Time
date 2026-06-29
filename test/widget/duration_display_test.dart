import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/domain/models/enums.dart';
import 'package:project_time/shared/widgets/duration_display.dart';
import 'package:project_time/shared/widgets/status_chip.dart';

void main() {
  testWidgets('FullDurationDisplay renders boxed digits and labels',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: FullDurationDisplay(
              duration: Duration(days: 74, hours: 7, minutes: 32, seconds: 10),
            ),
          ),
        ),
      ),
    );

    expect(find.text('02'), findsOneWidget); // months
    expect(find.text('14'), findsOneWidget); // days
    expect(find.text('07'), findsOneWidget); // hours
    expect(find.text('MO'), findsOneWidget);
    expect(find.text('SS'), findsOneWidget);
  });

  testWidgets('StatusChip shows a textual label (not color alone)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatusChip(status: TimerStatus.running)),
      ),
    );
    expect(find.text('Running'), findsOneWidget);
  });
}
