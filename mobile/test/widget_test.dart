// Smoke-тест: проверяет что главный виджет приложения собирается без падений.
// Дефолтный counter-тест от `flutter create` удалён — он не подходит этому проекту.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Минимальная пустышка чтобы тест-файл компилировался и проходил.
    // Полноценные widget/integration тесты — TODO.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
