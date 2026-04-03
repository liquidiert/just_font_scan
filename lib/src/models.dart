/// Represents a system font family with its supported weights.
///
/// Each instance corresponds to a single font family as grouped by the
/// platform's native font API (e.g. DirectWrite on Windows).
class FontFamily {
  /// The font family name (e.g. `'Arial'`, `'Source Code Pro'`).
  final String name;

  /// Supported font weights in ascending order.
  ///
  /// Values follow the CSS/OpenType convention: 100 (Thin) through
  /// 950 (ExtraBlack). Common values: 400 (Regular), 700 (Bold).
  final List<int> weights;

  /// Creates a [FontFamily] with the given [name] and [weights].
  const FontFamily({required this.name, required this.weights});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFamily &&
          name == other.name &&
          _listEquals(weights, other.weights);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(weights));

  @override
  String toString() => 'FontFamily($name, weights: $weights)';

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
