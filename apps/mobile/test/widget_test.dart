import 'package:banochki/core/ui/banochki_theme.dart';
import 'package:banochki/core/ui/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty state exposes the primary action', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: banochkiLightTheme(),
        home: Scaffold(
          body: EmptyState(
            title: 'Пока пусто',
            message: 'Добавьте первую партию.',
            actionLabel: 'Добавить партию',
            onAction: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Пока пусто'), findsOneWidget);
    await tester.tap(find.text('Добавить партию'));
    expect(pressed, isTrue);
  });
}
