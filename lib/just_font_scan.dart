/// Scan system font families and their supported weights
/// using platform-native APIs.
///
/// ```dart
/// import 'package:just_font_scan/just_font_scan.dart';
///
/// final families = JustFontScan.scan();
/// for (final family in families) {
///   print('${family.name}: ${family.weights}');
/// }
/// ```
library;

export 'src/models.dart';
export 'src/font_scanner.dart';
