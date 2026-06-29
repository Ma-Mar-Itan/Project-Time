import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/core/utilities/csv_utils.dart';

void main() {
  group('CsvUtils.escapeField', () {
    test('neutralizes formula-injection prefixes', () {
      expect(CsvUtils.escapeField('=1+1'), "'=1+1");
      expect(CsvUtils.escapeField('+SUM(A1)'), "'+SUM(A1)");
      expect(CsvUtils.escapeField('-2'), "'-2");
      expect(CsvUtils.escapeField('@cmd'), "'@cmd");
    });

    test('quotes fields containing commas or quotes', () {
      expect(CsvUtils.escapeField('a,b'), '"a,b"');
      expect(CsvUtils.escapeField('he said "hi"'), '"he said ""hi"""');
    });

    test('leaves safe fields untouched', () {
      expect(CsvUtils.escapeField('Research Project'), 'Research Project');
      expect(CsvUtils.escapeField(42), '42');
      expect(CsvUtils.escapeField(null), '');
    });
  });

  group('CsvUtils.build', () {
    test('joins header and rows with CRLF', () {
      final csv = CsvUtils.build(
        ['Name', 'Seconds'],
        [
          ['Alpha', 60],
          ['Beta', 120],
        ],
      );
      expect(csv, 'Name,Seconds\r\nAlpha,60\r\nBeta,120');
    });
  });
}
