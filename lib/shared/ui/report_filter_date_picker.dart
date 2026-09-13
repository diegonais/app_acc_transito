import 'package:flutter/material.dart';

import '../../data/models/report_date_bounds.dart';
import '../user_message.dart';

/// Selector compartido para filtros, con límites frescos antes y después
/// del diálogo (puede cambiar el día o el historial mientras está abierto).
Future<DateTime?> showReportFilterDatePicker({
  required BuildContext context,
  required Future<ReportDateBounds> Function() loadBounds,
  DateTime? current,
  DateTime? from,
  DateTime? to,
  bool isFrom = true,
}) async {
  try {
    final bounds = await loadBounds();
    if (!context.mounted) return null;
    final otherDateError = bounds.validate(
      from: isFrom ? null : from,
      to: isFrom ? to : null,
    );
    if (otherDateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('$otherDateError Limpie los filtros para elegir otro rango.'),
      ));
      return null;
    }
    final first =
        !isFrom && from != null ? ReportDateBounds.day(from) : bounds.firstDate;
    final last =
        isFrom && to != null ? ReportDateBounds.day(to) : bounds.lastDate;
    var initial = bounds.clamp(current ?? bounds.lastDate);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      currentDate: bounds.lastDate,
      errorInvalidText: 'Elija una fecha dentro del rango permitido.',
    );
    if (selected == null || !context.mounted) return null;
    final freshBounds = await loadBounds();
    if (!context.mounted) return null;
    final error = freshBounds.validate(
      from: isFrom ? selected : from,
      to: isFrom ? to : selected,
    );
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return null;
    }
    return selected;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userMessage(error,
            fallback: 'No se pudieron cargar las fechas disponibles.')),
      ));
    }
    return null;
  }
}
