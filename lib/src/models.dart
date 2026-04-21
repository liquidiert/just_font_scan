import 'package:just_font_scan/src/list.extension.dart';

/// Represents a system font family with its supported weights.
///
/// Each instance corresponds to a single font family as grouped by the
/// platform's native font API (e.g. DirectWrite on Windows).
class FontFamily {
  /// The font family name (e.g. `'Arial'`, `'Source Code Pro'`).
  final String name;

  /// Fonts included in this family.
  final List<Font> children;

  /// Creates a [FontFamily] with the given [name] and [children].
  const FontFamily({
    required this.name,
    required this.children,
  });

  Font? get regular =>
      children.firstWhereOrNull((f) => f.style == FontStyle.regular);

  Font? get bold => children.firstWhereOrNull((f) => f.style == FontStyle.bold);

  Font? get italic =>
      children.firstWhereOrNull((f) => f.style == FontStyle.italic);

  Font? get boldItalic =>
      children.firstWhereOrNull((f) => f.style == FontStyle.boldItalic);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFamily &&
          name == other.name &&
          // heaviest; thus latest comparison
          _listEquals(
            children.map((fp) => fp.hashCode).toList(),
            other.children.map(((fp) => fp.hashCode)).toList(),
          );

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(children),
      );

  @override
  String toString() => 'FontFamily($name, weights: $children)';

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum FontStyle { regular, bold, italic, boldItalic, unknown }

/// Represents a single system font with information about
/// weight and supported style.
///
/// Also holds the file path of the corresponding font.
class Font {
  final int weight;
  final FontStyle style;
  final String filePath;

  const Font({
    required this.weight,
    required this.style,
    required this.filePath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Font &&
          weight == other.weight &&
          style == other.style &&
          filePath == other.filePath;

  @override
  int get hashCode => Object.hash(
        weight,
        style,
        filePath,
      );

  @override
  String toString() => 'Font($weight, style: $style, path: $filePath)';
}
