/// Límites inclusivos de los días que pueden usarse para consultar informes.
class ReportDateBounds {
  ReportDateBounds({required DateTime today, DateTime? earliestReportDate})
      : lastDate = day(today),
        firstDate = earliestReportDate == null ||
                day(earliestReportDate).isAfter(day(today))
            ? day(today)
            : day(earliestReportDate);

  final DateTime firstDate;
  final DateTime lastDate;

  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime clamp(DateTime value) {
    final date = day(value);
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  String? validate({DateTime? from, DateTime? to}) {
    final start = from == null ? null : day(from);
    final end = to == null ? null : day(to);
    if (start != null && end != null && start.isAfter(end)) {
      return 'La fecha de inicio no puede ser posterior a la fecha límite.';
    }
    for (final date in [start, end]) {
      if (date == null) continue;
      if (date.isAfter(lastDate)) {
        return 'No se pueden buscar informes con fechas posteriores a hoy.';
      }
      if (date.isBefore(firstDate)) {
        final formatted = '${firstDate.day.toString().padLeft(2, '0')}/'
            '${firstDate.month.toString().padLeft(2, '0')}/${firstDate.year}';
        return 'La fecha mínima de consulta es $formatted.';
      }
    }
    return null;
  }
}
