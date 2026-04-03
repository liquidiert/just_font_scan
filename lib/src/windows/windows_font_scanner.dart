import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../models.dart';
import 'dwrite_bindings.dart';

/// Scans system fonts using DirectWrite COM API.
List<FontFamily> scanFonts() {
  return using((arena) => _scanFontsImpl(arena));
}

List<FontFamily> _scanFontsImpl(Arena arena) {
  // Load libraries
  final ole32 = DynamicLibrary.open('ole32.dll');
  final dwrite = DynamicLibrary.open('dwrite.dll');

  // CoInitializeEx — safe to call even if already initialized
  final coInitializeEx =
      ole32.lookupFunction<CoInitializeExNative, CoInitializeExDart>(
    'CoInitializeEx',
  );
  coInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // DWriteCreateFactory
  final createFactory =
      dwrite.lookupFunction<DWriteCreateFactoryNative, DWriteCreateFactoryDart>(
    'DWriteCreateFactory',
  );

  final iid = allocIIDWriteFactory(arena);
  final ppFactory = arena<Pointer<IntPtr>>();

  var hr = createFactory(DWRITE_FACTORY_TYPE_SHARED, iid, ppFactory);
  if (!succeeded(hr)) return const [];

  final factory = ppFactory.value;

  try {
    return _scanWithFactory(factory, arena);
  } finally {
    comRelease(factory);
  }
}

List<FontFamily> _scanWithFactory(Pointer<IntPtr> factory, Arena arena) {
  final ppCollection = arena<Pointer<IntPtr>>();
  var hr = factoryGetSystemFontCollection(factory, ppCollection);
  if (!succeeded(hr)) return const [];

  final collection = ppCollection.value;

  try {
    return _scanCollection(collection, arena);
  } finally {
    comRelease(collection);
  }
}

List<FontFamily> _scanCollection(
  Pointer<IntPtr> collection,
  Arena arena,
) {
  final familyCount = collectionGetFontFamilyCount(collection);
  final families = <FontFamily>[];

  for (var i = 0; i < familyCount; i++) {
    final family = _scanFamily(collection, i, arena);
    if (family != null) {
      families.add(family);
    }
  }

  families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return families;
}

FontFamily? _scanFamily(
  Pointer<IntPtr> collection,
  int index,
  Arena arena,
) {
  final ppFamily = arena<Pointer<IntPtr>>();
  var hr = collectionGetFontFamily(collection, index, ppFamily);
  if (!succeeded(hr)) return null;

  final family = ppFamily.value;

  try {
    // Get family name
    final name = _getFamilyName(family, arena);
    if (name == null || name.isEmpty) return null;

    // Skip vertical writing fonts
    if (name.startsWith('@')) return null;

    // Get weights
    final weights = _getFamilyWeights(family, arena);
    if (weights.isEmpty) return null;

    return FontFamily(name: name, weights: weights);
  } finally {
    comRelease(family);
  }
}

String? _getFamilyName(Pointer<IntPtr> family, Arena arena) {
  final ppNames = arena<Pointer<IntPtr>>();
  var hr = fontFamilyGetFamilyNames(family, ppNames);
  if (!succeeded(hr)) return null;

  final names = ppNames.value;

  try {
    return _getLocalizedString(names, arena);
  } finally {
    comRelease(names);
  }
}

String? _getLocalizedString(Pointer<IntPtr> strings, Arena arena) {
  final pIndex = arena<Uint32>();
  final pExists = arena<Int32>();

  // Try "en-us" first
  final enUs = 'en-us'.toNativeUtf16(allocator: arena);
  var hr = localizedStringsFindLocaleName(strings, enUs, pIndex, pExists);

  int nameIndex;
  if (succeeded(hr) && pExists.value != 0) {
    nameIndex = pIndex.value;
  } else {
    // Fallback to index 0
    final count = localizedStringsGetCount(strings);
    if (count == 0) return null;
    nameIndex = 0;
  }

  // Get string length
  final pLength = arena<Uint32>();
  hr = localizedStringsGetStringLength(strings, nameIndex, pLength);
  if (!succeeded(hr)) return null;

  final length = pLength.value;
  if (length == 0) return null;

  // Get string (length + 1 for null terminator)
  final buffer = arena<Uint16>(length + 1).cast<Utf16>();
  hr = localizedStringsGetString(strings, nameIndex, buffer, length + 1);
  if (!succeeded(hr)) return null;

  return buffer.toDartString(length: length);
}

List<int> _getFamilyWeights(Pointer<IntPtr> family, Arena arena) {
  final fontCount = fontListGetFontCount(family);
  final weightSet = <int>{};

  for (var i = 0; i < fontCount; i++) {
    final ppFont = arena<Pointer<IntPtr>>();
    final hr = fontListGetFont(family, i, ppFont);
    if (!succeeded(hr)) continue;

    final font = ppFont.value;
    try {
      final weight = fontGetWeight(font);
      if (weight >= 1 && weight <= 1000) {
        weightSet.add(weight);
      }
    } finally {
      comRelease(font);
    }
  }

  final weights = weightSet.toList()..sort();
  return weights;
}
