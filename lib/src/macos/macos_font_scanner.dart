import '../models.dart';
import 'coretext_bindings.dart';

/// Scans system fonts using CoreText / CoreFoundation APIs.
///
/// Best-effort: individual descriptor failures are silently skipped.
/// Returns an empty list on fatal failure.
List<FontFamily> scanFonts() {
  try {
    return _scanFonts();
  } catch (_) {
    return const [];
  }
}

/// Internal macOS font scanning implementation.
///
/// Approach:
/// - Create a CTFontCollection of available fonts.
/// - Get matching CTFontDescriptor array.
/// - For each descriptor, read family name and file URL attribute (when available).
/// - Aggregate weights and file paths per family.
List<FontFamily> _scanFonts() {
  final collection = createAvailableFontCollection();
  if (collection.address == 0) return const [];

  final descriptors = createMatchingDescriptors(collection);
  if (descriptors.address == 0) {
    cfRelease(collection);
    return const [];
  }

  final familyChildren = <String, List<Font>>{};
  try {
    final count = cfArrayGetCount(descriptors);
    if (count == 0) return const [];

    // Map family name -> list of Font children directly (per-descriptor).

    // Pre-resolve attribute keys we will use.
    final familyAttr = ctGetSymbolCFString('kCTFontFamilyNameAttribute');
    final urlAttr = ctGetSymbolCFString('kCTFontURLAttribute');
    final traitsAttr = ctGetSymbolCFString('kCTFontTraitsAttribute');
    final faceNameAttr = ctGetSymbolCFString('kCTFontFaceNameAttribute');
    final styleNameAttr = ctGetSymbolCFString('kCTFontStyleNameAttribute');

    // Helper: map CT numeric trait to integer 100..1000 weight.
    int mapTraitDoubleToWeight(double v) {
      int computed;
      if (v >= -2.0 && v <= 3.0) {
        computed = (v * 300 + 400).round();
      } else {
        computed = (v * 1000).round();
      }
      if (computed < 100) computed = 100;
      if (computed > 1000) computed = 1000;
      return computed;
    }

    for (var i = 0; i < count; i++) {
      final desc = cfArrayGetValueAtIndex(descriptors, i);
      if (desc.address == 0) continue;

      // Family name — try multiple attributes (family, display name, name)
      String familyName = '';
      // Try primary family attribute first
      if (familyAttr.address != 0) {
        try {
          familyName = ctFontDescriptorGetStringAttribute(desc, familyAttr);
        } catch (_) {
          familyName = '';
        }
      }
      // Fallback to display name attribute if available and family is empty
      final displayAttr = ctGetSymbolCFString('kCTFontDisplayNameAttribute');
      if (familyName.isEmpty && displayAttr.address != 0) {
        try {
          familyName = ctFontDescriptorGetStringAttribute(desc, displayAttr);
        } catch (_) {
          familyName = '';
        }
      }
      // Final fallback to generic name attribute if still empty
      final nameAttr = ctGetSymbolCFString('kCTFontNameAttribute');
      if (familyName.isEmpty && nameAttr.address != 0) {
        try {
          familyName = ctFontDescriptorGetStringAttribute(desc, nameAttr);
        } catch (_) {
          familyName = '';
        }
      }
      if (familyName.isEmpty) continue;

      // File path (CFURL) if available
      String path = '';
      if (urlAttr.address != 0) {
        try {
          path = ctFontDescriptorGetUrlAttributeAsPath(desc, urlAttr);
        } catch (_) {
          path = '';
        }
      }

      // Determine weight (best-effort) using traits attribute when present.
      int weightValue = 400;
      if (traitsAttr.address != 0) {
        try {
          final traitVal = ctFontDescriptorCopyAttribute(desc, traitsAttr);
          if (traitVal.address != 0) {
            try {
              final weightKey = ctGetSymbolCFString('kCTFontWeightTrait');
              bool assigned = false;

              // If traitVal is a dictionary, check for kCTFontWeightTrait.
              if (weightKey.address != 0 && isCFDictionary(traitVal)) {
                final weightObj = cfDictionaryGetValue(traitVal, weightKey);
                if (weightObj.address != 0) {
                  // Prefer numeric extraction via CFNumber
                  final numVal = cfNumberToDouble(weightObj);
                  if (numVal != null) {
                    weightValue = mapTraitDoubleToWeight(numVal);
                    assigned = true;
                  } else if (isCFString(weightObj)) {
                    final s = cfStringToDartString(weightObj);
                    final parsedDouble = double.tryParse(s);
                    if (parsedDouble != null) {
                      weightValue = mapTraitDoubleToWeight(parsedDouble);
                      assigned = true;
                    } else {
                      final parsedInt = int.tryParse(s);
                      if (parsedInt != null) {
                        var v = parsedInt;
                        if (v < 100) v = 100;
                        if (v > 1000) v = 1000;
                        weightValue = v;
                        assigned = true;
                      }
                    }
                  } else if (isCFNumber(weightObj)) {
                    final n2 = cfNumberToDouble(weightObj);
                    if (n2 != null) {
                      weightValue = mapTraitDoubleToWeight(n2);
                      assigned = true;
                    }
                  } else if (isCFDictionary(weightObj)) {
                    // Nested dictionary: try nested kCTFontWeightTrait
                    final nestedKey = ctGetSymbolCFString('kCTFontWeightTrait');
                    if (nestedKey.address != 0) {
                      final nested = cfDictionaryGetValue(weightObj, nestedKey);
                      if (nested.address != 0) {
                        if (isCFNumber(nested)) {
                          final nd = cfNumberToDouble(nested);
                          if (nd != null) {
                            weightValue = mapTraitDoubleToWeight(nd);
                            assigned = true;
                          }
                        } else if (isCFString(nested)) {
                          final s = cfStringToDartString(nested);
                          final pd = double.tryParse(s);
                          if (pd != null) {
                            weightValue = mapTraitDoubleToWeight(pd);
                            assigned = true;
                          } else {
                            final pi = int.tryParse(s);
                            if (pi != null) {
                              var v = pi;
                              if (v < 100) v = 100;
                              if (v > 1000) v = 1000;
                              weightValue = v;
                              assigned = true;
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // If not assigned from dictionary, try the traitVal itself.
              if (!assigned) {
                if (isCFNumber(traitVal)) {
                  final d = cfNumberToDouble(traitVal);
                  if (d != null) {
                    weightValue = mapTraitDoubleToWeight(d);
                    assigned = true;
                  }
                } else if (isCFString(traitVal)) {
                  final s = cfStringToDartString(traitVal);
                  final parsedDouble = double.tryParse(s);
                  if (parsedDouble != null) {
                    weightValue = mapTraitDoubleToWeight(parsedDouble);
                    assigned = true;
                  } else {
                    final parsedInt = int.tryParse(s);
                    if (parsedInt != null) {
                      var v = parsedInt;
                      if (v < 100) v = 100;
                      if (v > 1000) v = 1000;
                      weightValue = v;
                      assigned = true;
                    }
                  }
                } else if (isCFDictionary(traitVal)) {
                  // Fallback: dictionary may contain weight under other keys
                  final nestedKey = ctGetSymbolCFString('kCTFontWeightTrait');
                  if (nestedKey.address != 0) {
                    final nested = cfDictionaryGetValue(traitVal, nestedKey);
                    if (nested.address != 0) {
                      if (isCFNumber(nested)) {
                        final nd = cfNumberToDouble(nested);
                        if (nd != null) {
                          weightValue = mapTraitDoubleToWeight(nd);
                          assigned = true;
                        }
                      } else if (isCFString(nested)) {
                        final s = cfStringToDartString(nested);
                        final pd = double.tryParse(s);
                        if (pd != null) {
                          weightValue = mapTraitDoubleToWeight(pd);
                          assigned = true;
                        }
                      }
                    }
                  }
                }
              }
            } finally {
              cfRelease(traitVal);
            }
          }
        } catch (_) {
          // ignore and use fallback
        }
      }

      // Style detection: try face/style name heuristics and weight
      String faceName = '';
      String styleName = '';
      if (faceNameAttr.address != 0) {
        try {
          faceName = ctFontDescriptorGetStringAttribute(desc, faceNameAttr);
        } catch (_) {
          faceName = '';
        }
      }
      if (styleNameAttr.address != 0) {
        try {
          styleName = ctFontDescriptorGetStringAttribute(desc, styleNameAttr);
        } catch (_) {
          styleName = '';
        }
      }
      final combined = '${faceName.toLowerCase()} ${styleName.toLowerCase()}';

      final isItalic = combined.contains('italic') ||
          combined.contains('oblique') ||
          combined.contains('slanted');
      final isBoldName = combined.contains('bold') || weightValue >= 700;

      FontStyle style;
      if (isItalic) {
        // If the face/style name or traits indicate both bold and italic,
        // prefer boldItalic; otherwise italic.
        style = isBoldName ? FontStyle.boldItalic : FontStyle.italic;
      } else {
        // If not italic, map bold names/weights to FontStyle.bold, otherwise regular.
        style = isBoldName ? FontStyle.bold : FontStyle.regular;
      }

      // Create Font and append
      final fontObj = Font(weight: weightValue, style: style, filePath: path);
      familyChildren.putIfAbsent(familyName, () => <Font>[]).add(fontObj);
    }
  } finally {
    // Release CF objects
    cfRelease(descriptors);
    cfRelease(collection);
  }

  // Build result list from per-family children
  final families = <FontFamily>[];
  for (final entry in familyChildren.entries) {
    final name = entry.key;
    final children = entry.value;
    // Stable sort by weight
    children.sort((a, b) => a.weight.compareTo(b.weight));
    families.add(FontFamily(name: name, children: children));
  }

  families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return families;
}
