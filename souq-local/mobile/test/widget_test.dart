import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:souq_local/app.dart';

void main() {
  testWidgets('MarGem app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MarGemApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
