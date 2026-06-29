/// Minimal, dependency-free CSV writer that also neutralizes spreadsheet
/// formula injection (CSV injection / "DDE" attacks).
class CsvUtils {
  const CsvUtils._();

  static const _dangerousPrefixes = ['=', '+', '-', '@', '\t', '\r'];

  /// Escapes a single field: prefixes potentially dangerous leading characters
  /// with a single quote, then quotes/escapes per RFC 4180.
  static String escapeField(Object? value) {
    var text = value?.toString() ?? '';

    // Neutralize formula injection for fields that a spreadsheet might
    // interpret as a formula.
    if (text.isNotEmpty && _dangerousPrefixes.contains(text[0])) {
      text = "'$text";
    }

    final needsQuoting =
        text.contains(',') || text.contains('"') || text.contains('\n') ||
            text.contains('\r');
    if (needsQuoting) {
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }
    return text;
  }

  /// Joins a row of fields into a single CSV line.
  static String row(List<Object?> fields) =>
      fields.map(escapeField).join(',');

  /// Builds a full CSV document (CRLF line endings) from a header and rows.
  static String build(List<String> header, List<List<Object?>> rows) {
    final buffer = StringBuffer()..write(row(header));
    for (final r in rows) {
      buffer.write('\r\n');
      buffer.write(row(r));
    }
    return buffer.toString();
  }
}
