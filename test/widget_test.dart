import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:icfes/main.dart';

void main() {
  testWidgets('La app carga correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(
      const AplicacionPrincipal(
        proximaPantalla: Scaffold(
          body: Center(
            child: Text('Pantalla de prueba'),
          ),
        ),
      ),
    );

    expect(find.text('Pantalla de prueba'), findsOneWidget);
  });
}