import 'dart:async';

import 'package:app_acc_transito/features/reports/description_dictation_field.dart';
import 'package:app_acc_transito/services/speech/dictation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Speech extends DictationService {
  final result = Completer<String?>();
  bool cancelled = false;
  @override
  Future<String?> listen() => result.future;
  @override
  Future<void> stop() async => result.complete('El vehículo se detuvo.');
  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

void main() {
  Future<void> open(
          WidgetTester tester, TextEditingController text, _Speech speech) =>
      tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Form(
                  child: DescriptionDictationField(
                      controller: text, service: speech)))));

  testWidgets('añade el dictado sin perder texto y permite corregirlo',
      (tester) async {
    final text = TextEditingController(text: 'Descripción previa.');
    final speech = _Speech();
    await open(tester, text, speech);
    await tester.tap(find.text('Dictar descripción'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.tap(find.text('Terminar dictado'));
    await tester.pumpAndSettle();
    expect(text.text, 'Descripción previa.\nEl vehículo se detuvo.');
    await tester.enterText(find.byType(TextFormField), 'Texto revisado');
    expect(text.text, 'Texto revisado');
    await tester.pumpWidget(const SizedBox());
    expect(speech.cancelled, isTrue);
    text.dispose();
  });

  testWidgets('cancelar ignora resultados tardíos y conserva el texto',
      (tester) async {
    final text = TextEditingController(text: 'Texto original');
    final speech = _Speech();
    await open(tester, text, speech);
    await tester.tap(find.text('Dictar descripción'));
    await tester.pump();
    await tester.tap(find.text('Cancelar dictado'));
    await tester.pump();
    speech.result.complete('Resultado tardío');
    await tester.pumpAndSettle();
    expect(text.text, 'Texto original');
    expect(speech.cancelled, isTrue);
    await tester.pumpWidget(const SizedBox());
    text.dispose();
  });

  for (final code in [
    'permission',
    'unavailable',
    'recognition',
    'language_missing',
    'recognition_12',
    'recognition_13',
    'recognition_6',
    'recognition_7'
  ]) {
    testWidgets('fallo $code permite escribir sin perder contenido',
        (tester) async {
      final text = TextEditingController(text: 'Texto original');
      final speech = _Speech();
      await open(tester, text, speech);
      await tester.tap(find.text('Dictar descripción'));
      await tester.pump();
      speech.result.completeError(PlatformException(code: code));
      await tester.pumpAndSettle();
      expect(text.text, 'Texto original');
      await tester.enterText(find.byType(TextFormField), 'Corrección manual');
      expect(text.text, 'Corrección manual');
      expect(find.text('Dictar descripción'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      text.dispose();
    });
  }
}
