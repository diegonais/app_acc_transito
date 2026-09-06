/// Formato de consulta y exportación; no transforma los datos persistidos.
class ReportFormat {
  const ReportFormat._();

  static String value(String? value) =>
      value == null || value.trim().isEmpty ? 'No registrado' : value.trim();

  static String dateTime(DateTime? value) {
    if (value == null) return 'No registrado';
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} · '
        '${two(value.hour)}:${two(value.minute)}';
  }

  static String boolean(bool? value) =>
      value == null ? 'No registrado' : (value ? 'Sí' : 'No');

  static String personType(String value) => switch (value) {
        'HERIDO' => 'Herido',
        'FALLECIDO' => 'Fallecido',
        _ => ReportFormat.value(value),
      };

  // Versiones anteriores guardaban MIME como descripción de la fotografía.
  static String? photoDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty ||
        RegExp(r'^image/[\w.+-]+$', caseSensitive: false).hasMatch(text)) {
      return null;
    }
    return text;
  }
}
