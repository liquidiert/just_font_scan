// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// COM/DirectWrite bindings follow Windows SDK naming conventions:
// types use PascalCase (GUID, HRESULT) and constants use ALL_CAPS
// (DWRITE_FACTORY_TYPE_SHARED), which conflict with Dart lint rules.

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

/// Helper: convert a UTF-16 pointer [Pointer<Uint16>] with a known length into
/// a Dart [String]. Safely decodes UTF-16 manually to avoid package:ffi exceptions
/// on unaligned memory or unexpected code units, stopping at the first null terminator.
String utf16PointerToString(Pointer<Uint16> ptr, int length) {
  if (ptr.address == 0 || length <= 0) return '';
  try {
    final units = ptr.asTypedList(length);
    int end = 0;
    // Scan forward until we hit a null terminator or the end of the specified length
    while (end < length && units[end] != 0) {
      end++;
    }
    if (end == 0) return '';
    // String.fromCharCodes handles surrogate pairs natively and safely in Dart
    final str = String.fromCharCodes(units.sublist(0, end));
    return str;
  } catch (e) {
    return '';
  }
}

// --- HRESULT helper ---

bool succeeded(int hr) => hr >= 0;

// --- Font weight range (DWRITE_FONT_WEIGHT) ---

const int kDWriteFontWeightMin = 1;
const int kDWriteFontWeightMax = 1000;
const int kMaxFontNameLength = 32767;
const int kMaxFontFamilyCount = 10000;
const int kMaxFontCount = 1000;

const int DWRITE_FONT_WEIGHT_NORMAL = 400;
const int DWRITE_FONT_WEIGHT_SEMI_BOLD = 600;
const int DWRITE_FONT_WEIGHT_BOLD = 700;

// --- Font Style (DWRITE_FONT_STYLE) ---
const int DWRITE_FONT_STYLE_NORMAL = 0;
const int DWRITE_FONT_STYLE_OBLIQUE = 1;
const int DWRITE_FONT_STYLE_ITALIC = 2;

// --- Font Simulations (DWRITE_FONT_SIMULATIONS) ---
const int DWRITE_FONT_SIMULATIONS_NONE = 0x0000;
const int DWRITE_FONT_SIMULATIONS_BOLD = 0x0001;
const int DWRITE_FONT_SIMULATIONS_OBLIQUE = 0x0002;

// --- GUIDs ---

base class GUID extends Struct {
  @Uint32()
  external int data1;
  @Uint16()
  external int data2;
  @Uint16()
  external int data3;
  @Uint8()
  external int data4_0;
  @Uint8()
  external int data4_1;
  @Uint8()
  external int data4_2;
  @Uint8()
  external int data4_3;
  @Uint8()
  external int data4_4;
  @Uint8()
  external int data4_5;
  @Uint8()
  external int data4_6;
  @Uint8()
  external int data4_7;
}

Pointer<GUID> allocIIDWriteFactory(Arena arena) {
  final guid = arena<GUID>();
  guid.ref.data1 = 0xb859ee5a;
  guid.ref.data2 = 0xd838;
  guid.ref.data3 = 0x4b5b;
  guid.ref.data4_0 = 0xa2;
  guid.ref.data4_1 = 0xe8;
  guid.ref.data4_2 = 0x1a;
  guid.ref.data4_3 = 0xdc;
  guid.ref.data4_4 = 0x7d;
  guid.ref.data4_5 = 0x93;
  guid.ref.data4_6 = 0xdb;
  guid.ref.data4_7 = 0x48;
  return guid;
}

// --- DWriteCreateFactory ---

const int DWRITE_FACTORY_TYPE_SHARED = 0;

typedef DWriteCreateFactoryNative = Int32 Function(
  Int32 factoryType,
  Pointer<GUID> iid,
  Pointer<Pointer<IntPtr>> factory,
);
typedef DWriteCreateFactoryDart = int Function(
  int factoryType,
  Pointer<GUID> iid,
  Pointer<Pointer<IntPtr>> factory,
);

// --- COM lifecycle (ole32.dll) ---

typedef CoInitializeExNative = Int32 Function(
  Pointer<Void> reserved,
  Uint32 dwCoInit,
);
typedef CoInitializeExDart = int Function(
  Pointer<Void> reserved,
  int dwCoInit,
);

typedef CoUninitializeNative = Void Function();
typedef CoUninitializeDart = void Function();

const int COINIT_APARTMENTTHREADED = 0x2;

// --- DLL loading with absolute System32 path ---

String _system32Path() {
  final systemRoot = Platform.environment['SystemRoot'];
  if (systemRoot == null) {
    return r'C:\Windows\System32';
  }
  return '$systemRoot\\System32';
}

DynamicLibrary loadOle32() {
  return DynamicLibrary.open('${_system32Path()}\\ole32.dll');
}

DynamicLibrary loadDWrite() {
  final library = DynamicLibrary.open('${_system32Path()}\\dwrite.dll');
  return library;
}

// --- COM vtable helpers ---

Pointer<IntPtr> _vtable(Pointer<IntPtr> comPtr) {
  if (comPtr.address == 0) {
    throw StateError('COM pointer is null — cannot read vtable');
  }
  final vtableAddr = comPtr.value;
  if (vtableAddr == 0) {
    throw StateError('vtable pointer is null');
  }
  return Pointer<IntPtr>.fromAddress(vtableAddr);
}

Pointer<NativeFunction<T>> vtableSlot<T extends Function>(
  Pointer<IntPtr> comPtr,
  int slotIndex,
) {
  assert(
    slotIndex >= 0 && slotIndex < 64,
    'vtable slot $slotIndex is out of expected range',
  );
  final vtable = _vtable(comPtr);
  final fnAddr = (vtable + slotIndex).value;
  return Pointer<NativeFunction<T>>.fromAddress(fnAddr);
}

// --- IUnknown ---

/// IUnknown::QueryInterface — vtable slot 0
typedef _QueryInterfaceNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<GUID> riid,
  Pointer<Pointer<IntPtr>> ppvObject,
);
typedef _QueryInterfaceDart = int Function(
  Pointer<IntPtr> self,
  Pointer<GUID> riid,
  Pointer<Pointer<IntPtr>> ppvObject,
);

int comQueryInterface(
  Pointer<IntPtr> comPtr,
  Pointer<GUID> iid,
  Pointer<Pointer<IntPtr>> outObject,
) {
  if (comPtr.address == 0) return -2147467261; // E_POINTER
  final fn = vtableSlot<_QueryInterfaceNative>(comPtr, 0)
      .asFunction<_QueryInterfaceDart>();
  return fn(comPtr, iid, outObject);
}

/// IUnknown::Release — vtable slot 2
typedef _ReleaseNative = Uint32 Function(Pointer<IntPtr> self);
typedef _ReleaseDart = int Function(Pointer<IntPtr> self);

void comRelease(Pointer<IntPtr> comPtr) {
  if (comPtr.address == 0) return;
  final fn = vtableSlot<_ReleaseNative>(comPtr, 2).asFunction<_ReleaseDart>();
  fn(comPtr);
}

// --- IDWriteFactory vtable ---

typedef _GetSystemFontCollectionNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> fontCollection,
  Int32 checkForUpdates,
);
typedef _GetSystemFontCollectionDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> fontCollection,
  int checkForUpdates,
);

int factoryGetSystemFontCollection(
  Pointer<IntPtr> factory,
  Pointer<Pointer<IntPtr>> outCollection,
) {
  final fn = vtableSlot<_GetSystemFontCollectionNative>(factory, 3)
      .asFunction<_GetSystemFontCollectionDart>();
  return fn(factory, outCollection, 0);
}

// --- IDWriteFontCollection vtable ---

typedef _GetFontFamilyCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetFontFamilyCountDart = int Function(Pointer<IntPtr> self);

int collectionGetFontFamilyCount(Pointer<IntPtr> collection) {
  final fn = vtableSlot<_GetFontFamilyCountNative>(collection, 3)
      .asFunction<_GetFontFamilyCountDart>();
  return fn(collection);
}

typedef _GetFontFamilyNative = Int32 Function(
  Pointer<IntPtr> self,
  Uint32 index,
  Pointer<Pointer<IntPtr>> fontFamily,
);
typedef _GetFontFamilyDart = int Function(
  Pointer<IntPtr> self,
  int index,
  Pointer<Pointer<IntPtr>> fontFamily,
);

int collectionGetFontFamily(
  Pointer<IntPtr> collection,
  int index,
  Pointer<Pointer<IntPtr>> outFamily,
) {
  final fn = vtableSlot<_GetFontFamilyNative>(collection, 4)
      .asFunction<_GetFontFamilyDart>();
  return fn(collection, index, outFamily);
}

// --- IDWriteFontList vtable ---

typedef _GetFontCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetFontCountDart = int Function(Pointer<IntPtr> self);

int fontListGetFontCount(Pointer<IntPtr> fontList) {
  final fn = vtableSlot<_GetFontCountNative>(fontList, 4)
      .asFunction<_GetFontCountDart>();
  return fn(fontList);
}

typedef _GetFontNative = Int32 Function(
  Pointer<IntPtr> self,
  Uint32 index,
  Pointer<Pointer<IntPtr>> font,
);
typedef _GetFontDart = int Function(
  Pointer<IntPtr> self,
  int index,
  Pointer<Pointer<IntPtr>> font,
);

int fontListGetFont(
  Pointer<IntPtr> fontList,
  int index,
  Pointer<Pointer<IntPtr>> outFont,
) {
  final fn = vtableSlot<_GetFontNative>(fontList, 5).asFunction<_GetFontDart>();
  return fn(fontList, index, outFont);
}

// --- IDWriteFontFamily vtable ---

typedef _GetFamilyNamesNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> names,
);
typedef _GetFamilyNamesDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> names,
);

int fontFamilyGetFamilyNames(
  Pointer<IntPtr> fontFamily,
  Pointer<Pointer<IntPtr>> outNames,
) {
  final fn = vtableSlot<_GetFamilyNamesNative>(fontFamily, 6)
      .asFunction<_GetFamilyNamesDart>();
  return fn(fontFamily, outNames);
}

// --- IDWriteFont vtable ---

typedef _GetWeightNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetWeightDart = int Function(Pointer<IntPtr> self);

int fontGetWeight(Pointer<IntPtr> font) {
  final fn = vtableSlot<_GetWeightNative>(font, 4).asFunction<_GetWeightDart>();
  return fn(font);
}

/// IDWriteFont::GetStretch — vtable slot 5
typedef _GetStretchNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetStretchDart = int Function(Pointer<IntPtr> self);

int fontGetStretch(Pointer<IntPtr> font) {
  final fn =
      vtableSlot<_GetStretchNative>(font, 5).asFunction<_GetStretchDart>();
  return fn(font);
}

typedef _GetStyleNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetStyleDart = int Function(Pointer<IntPtr> self);

int fontGetStyle(Pointer<IntPtr> font) {
  final fn = vtableSlot<_GetStyleNative>(font, 6).asFunction<_GetStyleDart>();
  return fn(font);
}

/// IDWriteFont::GetSimulations — vtable slot 10
typedef _GetSimulationsNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetSimulationsDart = int Function(Pointer<IntPtr> self);

int fontGetSimulations(Pointer<IntPtr> font) {
  final fn = vtableSlot<_GetSimulationsNative>(font, 10)
      .asFunction<_GetSimulationsDart>();
  return fn(font);
}

// --- IDWriteLocalizedStrings vtable ---

typedef _GetCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetCountDart = int Function(Pointer<IntPtr> self);

int localizedStringsGetCount(Pointer<IntPtr> strings) {
  final fn =
      vtableSlot<_GetCountNative>(strings, 3).asFunction<_GetCountDart>();
  return fn(strings);
}

typedef _FindLocaleNameNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Utf16> localeName,
  Pointer<Uint32> index,
  Pointer<Int32> exists,
);
typedef _FindLocaleNameDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Utf16> localeName,
  Pointer<Uint32> index,
  Pointer<Int32> exists,
);

int localizedStringsFindLocaleName(
  Pointer<IntPtr> strings,
  Pointer<Utf16> localeName,
  Pointer<Uint32> outIndex,
  Pointer<Int32> outExists,
) {
  final fn = vtableSlot<_FindLocaleNameNative>(strings, 4)
      .asFunction<_FindLocaleNameDart>();
  return fn(strings, localeName, outIndex, outExists);
}

typedef _GetStringLengthNative = Int32 Function(
  Pointer<IntPtr> self,
  Uint32 index,
  Pointer<Uint32> length,
);
typedef _GetStringLengthDart = int Function(
  Pointer<IntPtr> self,
  int index,
  Pointer<Uint32> length,
);

int localizedStringsGetStringLength(
  Pointer<IntPtr> strings,
  int index,
  Pointer<Uint32> outLength,
) {
  final fn = vtableSlot<_GetStringLengthNative>(strings, 7)
      .asFunction<_GetStringLengthDart>();
  return fn(strings, index, outLength);
}

typedef _GetStringNative = Int32 Function(
  Pointer<IntPtr> self,
  Uint32 index,
  Pointer<Utf16> stringBuffer,
  Uint32 size,
);
typedef _GetStringDart = int Function(
  Pointer<IntPtr> self,
  int index,
  Pointer<Utf16> stringBuffer,
  int size,
);

int localizedStringsGetString(
  Pointer<IntPtr> strings,
  int index,
  Pointer<Utf16> buffer,
  int size,
) {
  final fn =
      vtableSlot<_GetStringNative>(strings, 8).asFunction<_GetStringDart>();
  return fn(strings, index, buffer, size);
}

typedef _CreateFontFaceNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> fontFace,
);
typedef _CreateFontFaceDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> fontFace,
);

int fontCreateFontFace(
  Pointer<IntPtr> font,
  Pointer<Pointer<IntPtr>> outFontFace,
) {
  final fn = vtableSlot<_CreateFontFaceNative>(font, 13)
      .asFunction<_CreateFontFaceDart>();
  return fn(font, outFontFace);
}

/// IDWriteFontFace::GetFiles — vtable slot 4
typedef _FontFaceGetFilesNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Uint32> numberOfFiles,
  Pointer<Pointer<IntPtr>> files,
);
typedef _FontFaceGetFilesDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Uint32> numberOfFiles,
  Pointer<Pointer<IntPtr>> files,
);

int fontFaceGetFiles(
  Pointer<IntPtr> fontFace,
  Pointer<Uint32> outFileCount,
  Pointer<Pointer<IntPtr>> outFiles,
) {
  final fn = vtableSlot<_FontFaceGetFilesNative>(fontFace, 4)
      .asFunction<_FontFaceGetFilesDart>();
  return fn(fontFace, outFileCount, outFiles);
}

/// IDWriteFontFile::GetReferenceKey — vtable slot 3
typedef _FontFileGetReferenceKeyNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<Void>> key,
  Pointer<Uint32> keySize,
);
typedef _FontFileGetReferenceKeyDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<Void>> key,
  Pointer<Uint32> keySize,
);

int fontFileGetReferenceKey(
  Pointer<IntPtr> fontFile,
  Pointer<Pointer<Void>> outKey,
  Pointer<Uint32> outKeySize,
) {
  final fn = vtableSlot<_FontFileGetReferenceKeyNative>(fontFile, 3)
      .asFunction<_FontFileGetReferenceKeyDart>();
  return fn(fontFile, outKey, outKeySize);
}

/// IDWriteFontFile::GetLoader — vtable slot 4
typedef _FontFileGetLoaderNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> loader,
);
typedef _FontFileGetLoaderDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> loader,
);

int fontFileGetLoader(
  Pointer<IntPtr> fontFile,
  Pointer<Pointer<IntPtr>> outLoader,
) {
  final fn = vtableSlot<_FontFileGetLoaderNative>(fontFile, 4)
      .asFunction<_FontFileGetLoaderDart>();
  return fn(fontFile, outLoader);
}

/// IDWriteLocalFontFileLoader::GetFilePathLengthFromKey — vtable slot 4
typedef _GetFilePathLengthFromKeyNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Void> referenceKey,
  Uint32 referenceKeySize,
  Pointer<Uint32> filePathLength,
);
typedef _GetFilePathLengthFromKeyDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Void> referenceKey,
  int referenceKeySize,
  Pointer<Uint32> filePathLength,
);

int loaderGetFilePathLengthFromKey(
  Pointer<IntPtr> loader,
  Pointer<Void> referenceKey,
  int referenceKeySize,
  Pointer<Uint32> outFilePathLength,
) {
  final fn = vtableSlot<_GetFilePathLengthFromKeyNative>(loader, 4)
      .asFunction<_GetFilePathLengthFromKeyDart>();
  return fn(loader, referenceKey, referenceKeySize, outFilePathLength);
}

/// IDWriteLocalFontFileLoader::GetFilePathFromKey — vtable slot 5
typedef _GetFilePathFromKeyNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Void> referenceKey,
  Uint32 referenceKeySize,
  Pointer<Uint16> filePath,
  Uint32 filePathSize,
);
typedef _GetFilePathFromKeyDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Void> referenceKey,
  int referenceKeySize,
  Pointer<Uint16> filePath,
  int filePathSize,
);

int loaderGetFilePathFromKey(
  Pointer<IntPtr> loader,
  Pointer<Void> referenceKey,
  int referenceKeySize,
  Pointer<Uint16> outFilePath,
  int filePathSize,
) {
  final fn = vtableSlot<_GetFilePathFromKeyNative>(loader, 5)
      .asFunction<_GetFilePathFromKeyDart>();
  return fn(loader, referenceKey, referenceKeySize, outFilePath, filePathSize);
}

// --- NEW HELPER: Safely Extract Path From A Single IDWriteFontFile ---
String _extractPathFromFontFile(Pointer<IntPtr> file) {
  String? extractedPath;
  final ppLoader = calloc<Pointer<IntPtr>>();

  try {
    final hrLoader = fontFileGetLoader(file, ppLoader);

    if (succeeded(hrLoader) && ppLoader.value.address != 0) {
      final loader = ppLoader.value;

      // IID_IDWriteLocalFontFileLoader: {b2d9f3ec-c9fe-4a11-a2ca-fac62438cb23}
      final pIID = calloc<GUID>();
      pIID.ref.data1 = 0xb2d9f3ec;
      pIID.ref.data2 = 0xc9fe;
      pIID.ref.data3 = 0x4a11;
      pIID.ref.data4_0 = 0xa2;
      pIID.ref.data4_1 = 0xca;
      pIID.ref.data4_2 = 0xfa;
      pIID.ref.data4_3 = 0xc6;
      pIID.ref.data4_4 = 0x24;
      pIID.ref.data4_5 = 0x38;
      pIID.ref.data4_6 = 0xcb;
      pIID.ref.data4_7 = 0x23;

      final ppLocalLoader = calloc<Pointer<IntPtr>>();
      try {
        // MUST QueryInterface safely before using derived loader methods
        final hrQI = comQueryInterface(loader, pIID, ppLocalLoader);

        if (succeeded(hrQI) && ppLocalLoader.value.address != 0) {
          final localLoader = ppLocalLoader.value;
          try {
            final pKeyPtr = calloc<Pointer<Void>>();
            final pKeySize = calloc<Uint32>();
            try {
              final hrKey = fontFileGetReferenceKey(file, pKeyPtr, pKeySize);

              if (succeeded(hrKey) &&
                  pKeyPtr.value.address != 0 &&
                  pKeySize.value != 0) {
                final pPathLen = calloc<Uint32>();
                try {
                  final hrLen = loaderGetFilePathLengthFromKey(
                      localLoader, pKeyPtr.value, pKeySize.value, pPathLen);

                  if (succeeded(hrLen) && pPathLen.value != 0) {
                    final buf = calloc<Uint16>(pPathLen.value + 1);
                    try {
                      final hrPath = loaderGetFilePathFromKey(
                          localLoader,
                          pKeyPtr.value,
                          pKeySize.value,
                          buf,
                          pPathLen.value + 1);

                      if (succeeded(hrPath)) {
                        final raw = utf16PointerToString(buf, pPathLen.value);
                        if (raw.isNotEmpty) extractedPath = raw;
                      }
                    } finally {
                      calloc.free(buf);
                    }
                  }
                } finally {
                  calloc.free(pPathLen);
                }
              }
            } finally {
              calloc.free(pKeyPtr);
              calloc.free(pKeySize);
            }
          } finally {
            comRelease(localLoader);
          }
        }
      } finally {
        calloc.free(pIID);
        calloc.free(ppLocalLoader);
        comRelease(loader);
      }
    }
  } catch (e) {
    // Exception caught in main execution block
  } finally {
    calloc.free(ppLoader);
  }

  if (extractedPath != null && extractedPath.isNotEmpty) {
    return extractedPath;
  }

  // Fallback: Parse the specialized System Font Collection reference key struct
  final pKeyPtr = calloc<Pointer<Void>>();
  final pKeySize = calloc<Uint32>();
  try {
    final hrFallbackKey = fontFileGetReferenceKey(file, pKeyPtr, pKeySize);

    if (succeeded(hrFallbackKey) &&
        pKeyPtr.value.address != 0 &&
        pKeySize.value != 0 &&
        (pKeySize.value % 2 == 0)) {
      // Valid UTF-16 size

      final units =
          pKeyPtr.value.cast<Uint16>().asTypedList(pKeySize.value ~/ 2);

      // Find the actual end of the string (skip trailing nulls)
      int end = units.length;
      while (end > 0 && units[end - 1] == 0) {
        end--;
      }

      if (end > 4) {
        // Needs to be larger than the standard 8-byte header
        // The internal System Font Collection reference key typically has an 8-byte
        // header (4 Uint16s) representing a FILETIME, followed by the UTF-16 string.
        // We skip the first 4 elements to bypass the binary garbage.
        String fallbackStr = String.fromCharCodes(units.sublist(4, end));

        // Sometimes it has a leading '*' or '?' indicator. Strip them.
        while (fallbackStr.isNotEmpty &&
            (fallbackStr.startsWith('*') || fallbackStr.startsWith('?'))) {
          fallbackStr = fallbackStr.substring(1);
        }

        final lower = fallbackStr.toLowerCase();
        if (lower.endsWith('.ttf') ||
            lower.endsWith('.ttc') ||
            lower.endsWith('.otf') ||
            lower.endsWith('.fon')) {
          // System fonts often just provide the filename (e.g. "MARLETT.TTF").
          // If there are no slashes, we know it resides in the Windows Fonts folder.
          if (!fallbackStr.contains(r'\') && !fallbackStr.contains('/')) {
            final sysRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
            fallbackStr = '$sysRoot\\Fonts\\$fallbackStr';
          }

          return fallbackStr;
        }
      }
    }
  } catch (e) {
    // Exception caught in fallback
  } finally {
    calloc.free(pKeyPtr);
    calloc.free(pKeySize);
  }

  return '';
}

// --- Rewritten High-Level APIs ---

List<String> getFamilyFilePaths(Pointer<IntPtr> family) {
  final paths = <String>[];
  final fontCount = fontListGetFontCount(family).clamp(0, kMaxFontCount);

  final ppFont = calloc<Pointer<IntPtr>>();
  final ppFontFace = calloc<Pointer<IntPtr>>();
  final pFileCount = calloc<Uint32>();

  try {
    for (var i = 0; i < fontCount; i++) {
      final hrFont = fontListGetFont(family, i, ppFont);
      if (!succeeded(hrFont) || ppFont.value.address == 0) {
        continue;
      }
      final font = ppFont.value;

      try {
        ppFontFace.value = Pointer<IntPtr>.fromAddress(0);
        final hrFace = fontCreateFontFace(font, ppFontFace);
        if (!succeeded(hrFace) || ppFontFace.value.address == 0) {
          continue;
        }
        final fontFace = ppFontFace.value;

        try {
          pFileCount.value = 0;
          fontFaceGetFiles(
              fontFace, pFileCount, Pointer<Pointer<IntPtr>>.fromAddress(0));
          final fileCount = pFileCount.value;
          if (fileCount == 0) continue;

          final filesArray = calloc<Pointer<IntPtr>>(fileCount);
          try {
            final hrFiles = fontFaceGetFiles(fontFace, pFileCount, filesArray);
            if (succeeded(hrFiles)) {
              for (var j = 0; j < fileCount; j++) {
                final file = filesArray[j];
                if (file.address == 0) continue;

                try {
                  final path = _extractPathFromFontFile(file);
                  if (path.isNotEmpty) paths.add(path);
                } catch (e) {
                  // exception extracting path
                } finally {
                  comRelease(file);
                }
              }
            }
          } finally {
            calloc.free(filesArray);
          }
        } finally {
          comRelease(fontFace);
        }
      } finally {
        comRelease(font);
      }
    }
  } finally {
    calloc.free(ppFont);
    calloc.free(ppFontFace);
    calloc.free(pFileCount);
  }

  return paths;
}

String getFirstFilePathForFont(Pointer<IntPtr> font) {
  if (font.address == 0) {
    return '';
  }
  final paths = <String>[];

  final ppFontFace = calloc<Pointer<IntPtr>>();
  final pFileCount = calloc<Uint32>();
  try {
    ppFontFace.value = Pointer<IntPtr>.fromAddress(0);
    final hrFace = fontCreateFontFace(font, ppFontFace);
    if (!succeeded(hrFace) || ppFontFace.value.address == 0) {
      return '';
    }
    final fontFace = ppFontFace.value;

    try {
      pFileCount.value = 0;
      fontFaceGetFiles(
          fontFace, pFileCount, Pointer<Pointer<IntPtr>>.fromAddress(0));
      final fileCount = pFileCount.value;
      if (fileCount == 0) return '';

      final filesArray = calloc<Pointer<IntPtr>>(fileCount);
      try {
        final hrFiles = fontFaceGetFiles(fontFace, pFileCount, filesArray);
        if (succeeded(hrFiles)) {
          for (var j = 0; j < fileCount; j++) {
            final file = filesArray[j];
            if (file.address == 0) continue;

            try {
              final path = _extractPathFromFontFile(file);
              if (path.isNotEmpty) paths.add(path);
            } catch (e) {
              // exception extracting path
            } finally {
              comRelease(file);
            }
          }
        }
      } finally {
        calloc.free(filesArray);
      }
    } finally {
      comRelease(fontFace);
    }
  } finally {
    calloc.free(ppFontFace);
    calloc.free(pFileCount);
  }

  return paths.isNotEmpty ? paths.first : '';
}

/// Helper to determine if a font is strictly Bold.
bool isFontBold(Pointer<IntPtr> font) {
  if (font.address == 0) return false;

  final weight = fontGetWeight(font) & 0xFFFFFFFF;
  final sims = fontGetSimulations(font) & 0xFFFFFFFF;

  // Safety check: Valid DWrite font weights are generally 1..1000.
  // If an HRESULT error (like 0x80004002) is accidentally returned, it will be
  // a huge number (e.g. 2147500034) which is >= 700. The <= 1000 check stops this.
  bool isWeightBold =
      (weight <= kDWriteFontWeightMax && weight >= DWRITE_FONT_WEIGHT_BOLD);
  bool isSimBold =
      (sims <= 0xFFFF && (sims & DWRITE_FONT_SIMULATIONS_BOLD) != 0);

  return isWeightBold || isSimBold;
}

/// Helper to determine if a font is Italic or Oblique.
bool isFontItalic(Pointer<IntPtr> font) {
  if (font.address == 0) return false;

  final style = fontGetStyle(font) & 0xFFFFFFFF;
  final sims = fontGetSimulations(font) & 0xFFFFFFFF;

  // No aggressive bitmasking (e.g. & 0xFF) here!
  // Masking to 8 bits converts HRESULT errors like E_NOINTERFACE (0x80004002)
  // directly into DWRITE_FONT_STYLE_ITALIC (2), creating random false positives.
  bool isStyleItalic =
      (style == DWRITE_FONT_STYLE_ITALIC || style == DWRITE_FONT_STYLE_OBLIQUE);
  bool isSimItalic =
      (sims <= 0xFFFF && (sims & DWRITE_FONT_SIMULATIONS_OBLIQUE) != 0);

  return isStyleItalic || isSimItalic;
}

/// Helper to reliably determine if a font is strictly treated as Bold AND Italic.
bool isFontBoldItalic(Pointer<IntPtr> font) {
  return isFontBold(font) && isFontItalic(font);
}
