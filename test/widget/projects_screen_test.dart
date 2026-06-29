import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/data/database/app_database.dart';
import 'package:project_time/domain/services/project_service.dart';
import 'package:project_time/features/projects/presentation/screens/projects_screen.dart';
import 'package:project_time/shared/providers/core_providers.dart';

import '../helpers/test_doubles.dart';
import 'package:project_time/core/utilities/clock.dart';

void main() {
  testWidgets('shows the empty state when there are no projects',
      (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProjectsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('Add project'), findsWidgets);
  });

  testWidgets('renders a created project in the list', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);

    final service = ProjectService(
      db: db,
      clock: const SystemClock(),
      ids: CounterIdGenerator(),
    );
    await service.create(ProjectInput(name: 'Visible', colorValue: 0xFF1A73E8));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProjectsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visible'), findsOneWidget);
  });
}
