import 'dart:io' show Platform;

import 'models.dart';
import 'windows/windows_font_scanner.dart' as windows;

class JustFontScan {
  static List<FontFamily>? _cache;

  /// Scans system font families. Results are sorted by name.
  /// Cached after first call; use [clearCache] to reset.
  static List<FontFamily> scan() {
    if (_cache != null) return _cache!;
    _cache = _scan();
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
  }

  /// Returns supported weights for [familyName].
  /// Returns `[400]` if the family is not found.
  static List<int> weightsFor(String familyName) {
    final families = scan();
    final lowerName = familyName.toLowerCase();
    for (final family in families) {
      if (family.name.toLowerCase() == lowerName) {
        return family.weights;
      }
    }
    return const [400];
  }

  static List<FontFamily> _scan() {
    if (Platform.isWindows) {
      return windows.scanFonts();
    }
    // Future: Platform.isMacOS → macos.scanFonts()
    return const [];
  }
}
