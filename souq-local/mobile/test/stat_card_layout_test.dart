import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/widgets/content_widgets.dart';

void main() {
  testWidgets('StatCard keeps compact icon-to-value spacing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 128,
            child: StatCard(
              label: 'Profile views',
              value: '0',
              icon: Icons.visibility_outlined,
              trend: 'No views yet',
            ),
          ),
        ),
      ),
    );

    final icon = tester.getRect(find.byIcon(Icons.visibility_outlined));
    final value = tester.getRect(find.text('0'));
    expect(value.top - icon.bottom, closeTo(8, 2.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatCard does not overflow with Arabic text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 160,
              height: 136,
              child: StatCard(
                label: 'مشاهدات الملف',
                value: '0',
                icon: Icons.visibility_outlined,
                trend: 'لا مشاهدات بعد',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('مشاهدات الملف'), findsOneWidget);
    expect(find.textContaining('OVERFLOWED'), findsNothing);
  });

  testWidgets('StatCard fits narrow 320dp half-width cards', (tester) async {
    // ~320dp phone with 16px padding and 12px gap => ~138px card width.
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 138,
              height: 136,
              child: StatCard(
                label: 'الاستفسارات',
                value: '12',
                icon: Icons.chat_bubble_outline,
                trend: 'لا توجد استفسارات بعد',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
