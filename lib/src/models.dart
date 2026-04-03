/// Represents a system font family with its supported weights.
class FontFamily {
  final String name;

  /// Supported font weights in ascending order (100–950).
  final List<int> weights;

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
