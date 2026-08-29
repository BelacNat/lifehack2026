import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecohabit/features/dashboard/presentation/dashboard_page.dart';

void main() {
  testWidgets('DashboardPage renders without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DashboardPage()),
    );

    expect(find.text('Impact + Home'), findsOneWidget);
  });
}
