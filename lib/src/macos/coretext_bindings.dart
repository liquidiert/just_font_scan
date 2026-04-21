import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Load CoreText framework.
DynamicLibrary loadCoreText() => DynamicLibrary.open(
    '/System/Library/Frameworks/CoreText.framework/CoreText');

/// Load CoreFoundation framework.
DynamicLibrary loadCoreFoundation() => DynamicLibrary.open(
    '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation');

final DynamicLibrary _coreText = loadCoreText();
final DynamicLibrary _coreFoundation = loadCoreFoundation();

// --- CF/CT helper typedefs and wrappers -----------------------------

// kCFStringEncodingUTF8
const int kCFStringEncodingUTF8 = 0x08000100;

/// CTFontCollectionRef CTFontCollectionCreateFromAvailableFonts(CFDictionaryRef options)
typedef _CTFontCollectionCreateFromAvailableFontsNative = Pointer<Void>
    Function(Pointer<Void> options);
typedef _CTFontCollectionCreateFromAvailableFontsDart = Pointer<Void> Function(
    Pointer<Void> options);

Pointer<Void> ctFontCollectionCreateFromAvailableFonts(Pointer<Void> options) {
  final fn = _coreText.lookupFunction<
          _CTFontCollectionCreateFromAvailableFontsNative,
          _CTFontCollectionCreateFromAvailableFontsDart>(
      'CTFontCollectionCreateFromAvailableFonts');
  return fn(options);
}

/// CTFontCollectionRef CTFontCollectionCreateFromAvailableFonts(CFDictionaryRef options)
typedef _CTFontCollectionCreateMatchingFontDescriptorsNative = Pointer<Void>
    Function(Pointer<Void> collection);
typedef _CTFontCollectionCreateMatchingFontDescriptorsDart = Pointer<Void>
    Function(Pointer<Void> collection);

Pointer<Void> ctFontCollectionCreateMatchingFontDescriptors(
    Pointer<Void> collection) {
  final fn = _coreText.lookupFunction<
          _CTFontCollectionCreateMatchingFontDescriptorsNative,
          _CTFontCollectionCreateMatchingFontDescriptorsDart>(
      'CTFontCollectionCreateMatchingFontDescriptors');
  return fn(collection);
}

/// CFArrayGetCount / CFArrayGetValueAtIndex
typedef _CFArrayGetCountNative = IntPtr Function(Pointer<Void> array);
typedef _CFArrayGetCountDart = int Function(Pointer<Void> array);

int cfArrayGetCount(Pointer<Void> array) {
  final fn = _coreFoundation.lookupFunction<_CFArrayGetCountNative,
      _CFArrayGetCountDart>('CFArrayGetCount');
  return fn(array);
}

typedef _CFArrayGetValueAtIndexNative = Pointer<Void> Function(
    Pointer<Void> array, IntPtr idx);
typedef _CFArrayGetValueAtIndexDart = Pointer<Void> Function(
    Pointer<Void> array, int idx);

Pointer<Void> cfArrayGetValueAtIndex(Pointer<Void> array, int index) {
  final fn = _coreFoundation.lookupFunction<_CFArrayGetValueAtIndexNative,
      _CFArrayGetValueAtIndexDart>('CFArrayGetValueAtIndex');
  return fn(array, index);
}

/// CTFontDescriptorCopyAttribute(CTFontDescriptorRef descriptor, CFStringRef attributeName)
typedef _CTFontDescriptorCopyAttributeNative = Pointer<Void> Function(
    Pointer<Void> descriptor, Pointer<Void> attributeName);
typedef _CTFontDescriptorCopyAttributeDart = Pointer<Void> Function(
    Pointer<Void> descriptor, Pointer<Void> attributeName);

Pointer<Void> ctFontDescriptorCopyAttribute(
    Pointer<Void> descriptor, Pointer<Void> attributeName) {
  final fn = _coreText.lookupFunction<_CTFontDescriptorCopyAttributeNative,
      _CTFontDescriptorCopyAttributeDart>(
    'CTFontDescriptorCopyAttribute',
  );
  return fn(descriptor, attributeName);
}

// --- CFString helpers ---------------------------------------------

typedef _CFStringGetLengthNative = IntPtr Function(Pointer<Void> cfStr);
typedef _CFStringGetLengthDart = int Function(Pointer<Void> cfStr);

int cfStringGetLength(Pointer<Void> cfStr) {
  final fn = _coreFoundation
      .lookupFunction<_CFStringGetLengthNative, _CFStringGetLengthDart>(
    'CFStringGetLength',
  );
  return fn(cfStr);
}

typedef _CFStringGetCStringPtrNative = Pointer<Utf8> Function(
    Pointer<Void> cfStr, Uint32 encoding);
typedef _CFStringGetCStringPtrDart = Pointer<Utf8> Function(
    Pointer<Void> cfStr, int encoding);

Pointer<Utf8> cfStringGetCStringPtr(Pointer<Void> cfStr, int encoding) {
  final fn = _coreFoundation.lookupFunction<_CFStringGetCStringPtrNative,
      _CFStringGetCStringPtrDart>('CFStringGetCStringPtr');
  return fn(cfStr, encoding);
}

typedef _CFStringGetCStringNative = Int32 Function(Pointer<Void> cfStr,
    Pointer<Utf8> buffer, IntPtr bufferSize, Uint32 encoding);
typedef _CFStringGetCStringDart = int Function(
    Pointer<Void> cfStr, Pointer<Utf8> buffer, int bufferSize, int encoding);

bool cfStringGetCString(
    Pointer<Void> cfStr, Pointer<Utf8> buffer, int bufferSize, int encoding) {
  final fn = _coreFoundation.lookupFunction<_CFStringGetCStringNative,
      _CFStringGetCStringDart>('CFStringGetCString');
  final res = fn(cfStr, buffer, bufferSize, encoding);
  return res != 0;
}

/// Convert a CFStringRef to a Dart String.
///
/// This helper will first try `CFStringGetCStringPtr` (fast path). If that
/// returns NULL it falls back to `CFStringGetCString`.
String cfStringToDartString(Pointer<Void> cfStr) {
  if (cfStr.address == 0) return '';

  // Try fast path
  final cptr = cfStringGetCStringPtr(cfStr, kCFStringEncodingUTF8);
  if (cptr.address != 0) {
    try {
      return cptr.toDartString();
    } catch (_) {
      // fallthrough to safe path
    }
  }

  // Safe path: get character count and allocate buffer for UTF-8 bytes.
  final length = cfStringGetLength(cfStr);
  // Conservative UTF-8 buffer size: up to 4 bytes per UTF-16 code unit + 1
  final bufSize = (length > 0 ? (length * 4 + 1) : 1024);
  final buf = calloc<Uint8>(bufSize).cast<Utf8>();
  try {
    final ok = cfStringGetCString(cfStr, buf, bufSize, kCFStringEncodingUTF8);
    if (!ok) return '';
    return buf.toDartString();
  } finally {
    calloc.free(buf);
  }
}

// --- CFRelease ----------------------------------------------------

typedef _CFReleaseNative = Void Function(Pointer<Void> cfObj);
typedef _CFReleaseDart = void Function(Pointer<Void> cfObj);

void cfRelease(Pointer<Void> cfObj) {
  if (cfObj.address == 0) return;
  final fn = _coreFoundation
      .lookupFunction<_CFReleaseNative, _CFReleaseDart>('CFRelease');
  fn(cfObj);
}

// --- CFURL -> filesystem path ------------------------------------

typedef _CFURLGetFileSystemRepresentationNative = Uint8 Function(
  Pointer<Void> url,
  Uint8 resolveAgainstBase,
  Pointer<Uint8> buffer,
  IntPtr maxBufLen,
);
typedef _CFURLGetFileSystemRepresentationDart = int Function(
  Pointer<Void> url,
  int resolveAgainstBase,
  Pointer<Uint8> buffer,
  int maxBufLen,
);

bool cfURLGetFileSystemRepresentation(Pointer<Void> url,
    bool resolveAgainstBase, Pointer<Uint8> buffer, int maxBufLen) {
  if (url.address == 0) return false;
  final fn = _coreFoundation.lookupFunction<
      _CFURLGetFileSystemRepresentationNative,
      _CFURLGetFileSystemRepresentationDart>(
    'CFURLGetFileSystemRepresentation',
  );
  final res = fn(url, resolveAgainstBase ? 1 : 0, buffer, maxBufLen);
  return res != 0;
}

/// Convert CFURLRef to Dart String (filesystem path). Returns empty string on failure.
String cfUrlToFileSystemPath(Pointer<Void> url) {
  if (url.address == 0) return '';

  // Ask for a representative length — use a reasonably large buffer.
  const maxPath = 4096;
  final buf = calloc<Uint8>(maxPath);
  try {
    final ok = cfURLGetFileSystemRepresentation(url, true, buf, maxPath);
    if (!ok) return '';
    // Interpret buffer as UTF-8 NUL-terminated
    final u8 = buf.cast<Utf8>();
    final path = u8.toDartString();
    return path;
  } finally {
    calloc.free(buf);
  }
}

// --- Symbol helpers ------------------------------------------------

/// Some CoreText attribute keys (e.g. kCTFontURLAttribute) are exported as
/// global `CFStringRef` constants. This helper returns the CFStringRef for
/// a given exported symbol name (e.g. 'kCTFontURLAttribute') or a null
/// pointer if not found. The lookup can throw if the symbol is missing, so
/// we catch that and return a null pointer (address 0) in that case.
Pointer<Void> ctGetSymbolCFString(String symbolName) {
  try {
    final symbol = _coreText.lookup<Pointer<Void>>(symbolName);
    // symbol is a pointer to the CFStringRef global; cast and read its value
    return symbol.cast<Pointer<Void>>().value;
  } catch (_) {
    // Symbol not found or lookup failed — return NULL-equivalent pointer
    return Pointer<Void>.fromAddress(0);
  }
}

// --- Convenience high-level helpers --------------------------------

/// Create a CTFontCollection of available fonts (options may be nullptr).
Pointer<Void> createAvailableFontCollection() =>
    ctFontCollectionCreateFromAvailableFonts(nullptr);

/// Return descriptors matching the collection (CFArrayRef of CTFontDescriptorRef)
Pointer<Void> createMatchingDescriptors(Pointer<Void> collection) =>
    ctFontCollectionCreateMatchingFontDescriptors(collection);

/// Read a CFString attribute (if present) from a descriptor and return Dart string.
/// Returns empty string if attribute missing or not a CFString.
String ctFontDescriptorGetStringAttribute(
    Pointer<Void> descriptor, Pointer<Void> attributeCFString) {
  if (descriptor.address == 0 || attributeCFString.address == 0) return '';
  final cfVal = ctFontDescriptorCopyAttribute(descriptor, attributeCFString);
  if (cfVal.address == 0) return '';
  try {
    // We expect a CFStringRef; convert to Dart string.
    final s = cfStringToDartString(cfVal);
    return s;
  } finally {
    cfRelease(cfVal);
  }
}

/// Read a CFURL attribute from a descriptor and convert it to filesystem path.
/// Returns empty string if missing or not a URL.
String ctFontDescriptorGetUrlAttributeAsPath(
    Pointer<Void> descriptor, Pointer<Void> attributeCFString) {
  if (descriptor.address == 0 || attributeCFString.address == 0) return '';
  final cfVal = ctFontDescriptorCopyAttribute(descriptor, attributeCFString);
  if (cfVal.address == 0) return '';
  try {
    final path = cfUrlToFileSystemPath(cfVal);
    return path;
  } finally {
    cfRelease(cfVal);
  }
}

/// CFDictionaryGetValue — wrapper for CFDictionaryGetValue(dict, key)
typedef _CFDictionaryGetValueNative = Pointer<Void> Function(
    Pointer<Void> dict, Pointer<Void> key);
typedef _CFDictionaryGetValueDart = Pointer<Void> Function(
    Pointer<Void> dict, Pointer<Void> key);

Pointer<Void> cfDictionaryGetValue(Pointer<Void> dict, Pointer<Void> key) {
  if (dict.address == 0 || key.address == 0)
    return Pointer<Void>.fromAddress(0);
  final fn = _coreFoundation.lookupFunction<_CFDictionaryGetValueNative,
      _CFDictionaryGetValueDart>('CFDictionaryGetValue');
  return fn(dict, key);
}

/// CFCopyDescription — returns a CFStringRef describing a CF object.
/// Caller is responsible for releasing the returned CFStringRef.
typedef _CFCopyDescriptionNative = Pointer<Void> Function(Pointer<Void> cfObj);
typedef _CFCopyDescriptionDart = Pointer<Void> Function(Pointer<Void> cfObj);

Pointer<Void> cfCopyDescription(Pointer<Void> cfObj) {
  if (cfObj.address == 0) return Pointer<Void>.fromAddress(0);
  final fn = _coreFoundation.lookupFunction<_CFCopyDescriptionNative,
      _CFCopyDescriptionDart>('CFCopyDescription');
  return fn(cfObj);
}

/// CF type ID helpers — allow guarding by CF type before calling CFString APIs.

/// CFTypeID CFGetTypeID(CFTypeRef cf)
typedef _CFGetTypeIDNative = IntPtr Function(Pointer<Void> cfObj);
typedef _CFGetTypeIDDart = int Function(Pointer<Void> cfObj);

int cfGetTypeID(Pointer<Void> cfObj) {
  final fn =
      _coreFoundation.lookupFunction<_CFGetTypeIDNative, _CFGetTypeIDDart>(
    'CFGetTypeID',
  );
  return fn(cfObj);
}

/// CFTypeID CFStringGetTypeID(void)
typedef _CFStringGetTypeIDNative = IntPtr Function();
typedef _CFStringGetTypeIDDart = int Function();

int cfStringGetTypeID() {
  final fn = _coreFoundation.lookupFunction<_CFStringGetTypeIDNative,
      _CFStringGetTypeIDDart>('CFStringGetTypeID');
  return fn();
}

/// CFTypeID CFDictionaryGetTypeID(void)
typedef _CFDictionaryGetTypeIDNative = IntPtr Function();
typedef _CFDictionaryGetTypeIDDart = int Function();

int cfDictionaryGetTypeID() {
  final fn = _coreFoundation.lookupFunction<_CFDictionaryGetTypeIDNative,
      _CFDictionaryGetTypeIDDart>('CFDictionaryGetTypeID');
  return fn();
}

/// CFTypeID CFNumberGetTypeID(void)
typedef _CFNumberGetTypeIDNative = IntPtr Function();
typedef _CFNumberGetTypeIDDart = int Function();

int cfNumberGetTypeID() {
  final fn = _coreFoundation.lookupFunction<_CFNumberGetTypeIDNative,
      _CFNumberGetTypeIDDart>('CFNumberGetTypeID');
  return fn();
}

/// Helpers to test CF types quickly.
bool isCFString(Pointer<Void> obj) {
  if (obj.address == 0) return false;
  try {
    return cfGetTypeID(obj) == cfStringGetTypeID();
  } catch (_) {
    return false;
  }
}

bool isCFDictionary(Pointer<Void> obj) {
  if (obj.address == 0) return false;
  try {
    return cfGetTypeID(obj) == cfDictionaryGetTypeID();
  } catch (_) {
    return false;
  }
}

bool isCFNumber(Pointer<Void> obj) {
  if (obj.address == 0) return false;
  try {
    return cfGetTypeID(obj) == cfNumberGetTypeID();
  } catch (_) {
    return false;
  }
}

/// CFNumberGetValue — attempt to read a double out of a CFNumberRef.
/// We pick kCFNumberFloat64Type (6) as the requested type; this is commonly
/// supported. Returns null on failure.
const int _kCFNumberFloat64Type = 6;
typedef _CFNumberGetValueNative = Uint8 Function(
    Pointer<Void> number, Int32 theType, Pointer<Void> valuePtr);
typedef _CFNumberGetValueDart = int Function(
    Pointer<Void> number, int theType, Pointer<Void> valuePtr);

double? cfNumberToDouble(Pointer<Void> number) {
  if (number.address == 0) return null;
  if (!isCFNumber(number)) return null;
  final ptr = calloc<Double>();
  try {
    final fn = _coreFoundation.lookupFunction<_CFNumberGetValueNative,
        _CFNumberGetValueDart>('CFNumberGetValue');
    final ok = fn(number, _kCFNumberFloat64Type, ptr.cast<Void>());
    if (ok == 0) return null;
    return ptr.value;
  } catch (_) {
    return null;
  } finally {
    calloc.free(ptr);
  }
}
