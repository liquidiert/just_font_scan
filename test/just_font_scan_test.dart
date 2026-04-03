import 'package:test/test.dart';
import 'package:just_font_scan/just_font_scan.dart';

void main() {
  group('FontFamily', () {
    test('constructor and properties', () {
      final family = FontFamily(name: 'Arial', weights: [400, 700]);
      expect(family.name, 'Arial');
      expect(family.weights, [400, 700]);
    });

    test('equality', () {
      final a = FontFamily(name: 'Arial', weights: [400, 700]);
      final b = FontFamily(name: 'Arial', weights: [400, 700]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      final family = FontFamily(name: 'Arial', weights: [400, 700]);
      expect(family.toString(), contains('Arial'));
    });
  });
}
