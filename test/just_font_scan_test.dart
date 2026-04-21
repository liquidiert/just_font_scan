import 'package:test/test.dart';
import 'package:just_font_scan/just_font_scan.dart';

void main() {
  group('FontFamily', () {
    test('constructor and properties', () {
      final family = FontFamily(
        name: 'Arial',
        children: const [
          Font(
              weight: 400,
              style: FontStyle.regular,
              filePath: '/tmp/arial-regular.ttf'),
          Font(
              weight: 700,
              style: FontStyle.bold,
              filePath: '/tmp/arial-bold.ttf'),
        ],
      );
      expect(family.name, 'Arial');
      expect(family.children.map((c) => c.weight).toList(), [400, 700]);
    });

    test('equality', () {
      final a = FontFamily(
        name: 'Arial',
        children: const [
          Font(
              weight: 400,
              style: FontStyle.regular,
              filePath: '/tmp/arial-regular.ttf'),
          Font(
              weight: 700,
              style: FontStyle.bold,
              filePath: '/tmp/arial-bold.ttf'),
        ],
      );
      final b = FontFamily(
        name: 'Arial',
        children: const [
          Font(
              weight: 400,
              style: FontStyle.regular,
              filePath: '/tmp/arial-regular.ttf'),
          Font(
              weight: 700,
              style: FontStyle.bold,
              filePath: '/tmp/arial-bold.ttf'),
        ],
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      final family = FontFamily(
        name: 'Arial',
        children: const [
          Font(
              weight: 400,
              style: FontStyle.regular,
              filePath: '/tmp/arial-regular.ttf'),
          Font(
              weight: 700,
              style: FontStyle.bold,
              filePath: '/tmp/arial-bold.ttf'),
        ],
      );
      expect(family.toString(), contains('Arial'));
    });
  });
}
