import 'package:app_acc_transito/data/models/report_date_bounds.dart';
import 'package:app_acc_transito/shared/ui/report_filter_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final firstReport = DateTime(2026, 1, 10, 18);
  final today = DateTime(2026, 9, 13, 12);
  final bounds =
      ReportDateBounds(today: today, earliestReportDate: firstReport);

  for (final isFrom in [true, false]) {
    testWidgets(
        'selector ${isFrom ? 'inicio' : 'límite'} impide invertir el rango',
        (tester) async {
      await _open(tester,
          loadBounds: () async => bounds,
          isFrom: isFrom,
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 8, 31));
      final dialog =
          tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(dialog.firstDate,
          isFrom ? DateTime(2026, 1, 10) : DateTime(2026, 8, 1));
      expect(dialog.lastDate,
          isFrom ? DateTime(2026, 8, 31) : DateTime(2026, 9, 13));
      final localizations = MaterialLocalizations.of(
          tester.element(find.byType(DatePickerDialog)));
      await tester.tap(find.byTooltip(localizations.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField), isFrom ? '01/09/2026' : '31/07/2026');
      await tester.tap(find.text(localizations.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('Elija una fecha dentro del rango permitido.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'fecha única rechaza fechas futuras y anteriores al primer informe por teclado',
      (tester) async {
    await _open(tester, loadBounds: () async => bounds);
    final dialog =
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(dialog.firstDate, DateTime(2026, 1, 10));
    expect(dialog.lastDate, DateTime(2026, 9, 13));
    final localizations =
        MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog)));
    await tester.tap(find.byTooltip(localizations.inputDateModeButtonLabel));
    await tester.pumpAndSettle();
    for (final date in ['14/09/2026', '01/01/1900']) {
      await tester.enterText(find.byType(TextField), date);
      await tester.tap(find.text(localizations.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('Elija una fecha dentro del rango permitido.'),
          findsOneWidget);
    }
  });

  testWidgets('permite consultar un solo día y limita a hoy sin historial',
      (tester) async {
    DateTime? selected;
    final emptyBounds = ReportDateBounds(today: today);
    await _open(tester,
        loadBounds: () async => emptyBounds,
        from: emptyBounds.lastDate,
        isFrom: false,
        onSelected: (date) => selected = date);
    final dialog =
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(dialog.firstDate, emptyBounds.lastDate);
    expect(dialog.lastDate, emptyBounds.lastDate);
    final localizations =
        MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog)));
    await tester.tap(find.text(localizations.okButtonLabel));
    await tester.pumpAndSettle();
    expect(selected, emptyBounds.lastDate);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'revalida hoy al confirmar si cambia el reloj con el diálogo abierto',
      (tester) async {
    var calls = 0;
    DateTime? selected;
    await _open(tester,
        loadBounds: () async {
          calls++;
          return ReportDateBounds(
              today: calls == 1 ? today : DateTime(2026, 9, 12),
              earliestReportDate: firstReport);
        },
        onSelected: (date) => selected = date);
    final localizations =
        MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog)));
    await tester.tap(find.text(localizations.okButtonLabel));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(selected, isNull);
    expect(
        find.text('No se pueden buscar informes con fechas posteriores a hoy.'),
        findsOneWidget);
  });
}

Future<void> _open(
  WidgetTester tester, {
  required Future<ReportDateBounds> Function() loadBounds,
  DateTime? from,
  DateTime? to,
  bool isFrom = true,
  ValueChanged<DateTime?>? onSelected,
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('es', 'BO'),
    supportedLocales: const [Locale('es', 'BO')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () async {
                    final selected = await showReportFilterDatePicker(
                        context: context,
                        loadBounds: loadBounds,
                        from: from,
                        to: to,
                        isFrom: isFrom);
                    onSelected?.call(selected);
                  },
                  child: const Text('Elegir fecha'),
                ))),
  ));
  await tester.tap(find.text('Elegir fecha'));
  await tester.pumpAndSettle();
}
