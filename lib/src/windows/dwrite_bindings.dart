// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// COM/DirectWrite bindings follow Windows SDK naming conventions:
// types use PascalCase (GUID, HRESULT) and constants use ALL_CAPS
// (DWRITE_FACTORY_TYPE_SHARED), which conflict with Dart lint rules.

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

/// Helper: convert a UTF-16 pointer [Pointer<Uint16>] with a known length into
/// a Dart [String]. Trims trailing NUL code units.
String utf16PointerToString(Pointer<Uint16> ptr, int length) {
  if (ptr.address == 0 || length <= 0) return '';
  final units = ptr.asTypedList(length);
  var end = length;
  while (end > 0 && units[end - 1] == 0) {
    end--;
  }
  if (end == 0) return '';
  return String.fromCharCodes(units.sublist(0, end));
}

// --- HRESULT helper ---

bool succeeded(int hr) => hr >= 0;

// --- Font weight range (DWRITE_FONT_WEIGHT) ---

/// Minimum valid DWRITE_FONT_WEIGHT value.
const int kDWriteFontWeightMin = 1;

/// Maximum valid DWRITE_FONT_WEIGHT value (DWRITE_FONT_WEIGHT_ULTRA_BLACK = 950,
/// but values up to 1000 are accepted by some implementations).
const int kDWriteFontWeightMax = 1000;

/// Maximum sane font name length in characters.
const int kMaxFontNameLength = 32767;

/// Maximum sane font family count (guard against corrupt COM data).
const int kMaxFontFamilyCount = 10000;

/// Maximum sane font count per family.
const int kMaxFontCount = 1000;

// --- GUIDs ---

/// GUID struct for COM interfaces.
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

/// Allocates and fills IID_IDWriteFactory:
/// {b859ee5a-d838-4b5b-a2e8-1adc7d93db48}
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

/// DWRITE_FACTORY_TYPE_SHARED = 0
const int DWRITE_FACTORY_TYPE_SHARED = 0;

/// HRESULT DWriteCreateFactory(
///   DWRITE_FACTORY_TYPE factoryType,
///   REFIID iid,
///   IUnknown **factory
/// )
///
/// Note: `Pointer<IntPtr>` is the Dart FFI idiom for an opaque COM interface
/// pointer. The actual native type is `IUnknown*`, but Dart FFI does not have
/// a COM-aware type, so we use IntPtr-width pointers throughout.
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

/// COINIT_APARTMENTTHREADED = 0x2
const int COINIT_APARTMENTTHREADED = 0x2;

// --- DLL loading with absolute System32 path (W-1: prevent DLL hijacking) ---

String _system32Path() {
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  return '$systemRoot\\System32';
}

DynamicLibrary loadOle32() =>
    DynamicLibrary.open('${_system32Path()}\\ole32.dll');

DynamicLibrary loadDWrite() =>
    DynamicLibrary.open('${_system32Path()}\\dwrite.dll');

// --- COM vtable helpers ---

/// Reads the vtable pointer array from a COM interface pointer.
///
/// comPtr points to the object, whose first field is a pointer to the vtable.
/// Throws [StateError] if the COM pointer or vtable pointer is null, preventing
/// an unrecoverable process crash from null-pointer dereference.
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

/// Gets a function pointer from vtable at [slotIndex].
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

/// IUnknown::Release — vtable slot 2
typedef _ReleaseNative = Uint32 Function(Pointer<IntPtr> self);
typedef _ReleaseDart = int Function(Pointer<IntPtr> self);

void comRelease(Pointer<IntPtr> comPtr) {
  if (comPtr.address == 0) return;
  final fn = vtableSlot<_ReleaseNative>(comPtr, 2).asFunction<_ReleaseDart>();
  fn(comPtr);
}

// --- IDWriteFactory vtable ---
// Verified against dwrite.h (Windows SDK) and MSDN.
// IUnknown (3) + IDWriteFactory methods:
//  [3]  GetSystemFontCollection
//  [4]  CreateCustomFontCollection
//  [5]  RegisterFontCollectionLoader
//  [6]  UnregisterFontCollectionLoader
//  [7]  CreateFontFileReference
//  [8]  CreateCustomFontFileReference
//  [9]  CreateFontFace
//  [10] CreateRenderingParams
//  [11] CreateMonitorRenderingParams
//  [12] CreateCustomRenderingParams
//  [13] RegisterFontFileLoader
//  [14] UnregisterFontFileLoader
//  [15] CreateTextFormat
//  [16] CreateTypography
//  [17] GetGdiInterop
//  [18] CreateTextLayout
//  [19] CreateGdiCompatibleTextLayout
//  [20] CreateEllipsisTrimmingSign
//  [21] CreateTextAnalyzer
//  [22] CreateNumberSubstitution
//  [23] CreateGlyphRunAnalysis

/// IDWriteFactory::GetSystemFontCollection — vtable slot 3
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
// Verified against dwrite.h.
// IUnknown (3) +
//  [3] GetFontFamilyCount
//  [4] GetFontFamily
//  [5] FindFamilyName
//  [6] GetFontFromFontFace

/// IDWriteFontCollection::GetFontFamilyCount — vtable slot 3
typedef _GetFontFamilyCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetFontFamilyCountDart = int Function(Pointer<IntPtr> self);

int collectionGetFontFamilyCount(Pointer<IntPtr> collection) {
  final fn = vtableSlot<_GetFontFamilyCountNative>(collection, 3)
      .asFunction<_GetFontFamilyCountDart>();
  return fn(collection);
}

/// IDWriteFontCollection::GetFontFamily — vtable slot 4
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
// Verified against dwrite.h.
// IUnknown (3) +
//  [3] GetFontCollection
//  [4] GetFontCount
//  [5] GetFont

/// IDWriteFontList::GetFontCount — vtable slot 4
typedef _GetFontCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetFontCountDart = int Function(Pointer<IntPtr> self);

int fontListGetFontCount(Pointer<IntPtr> fontList) {
  final fn = vtableSlot<_GetFontCountNative>(fontList, 4)
      .asFunction<_GetFontCountDart>();
  return fn(fontList);
}

/// IDWriteFontList::GetFont — vtable slot 5
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

// --- IDWriteFontFamily vtable (extends IDWriteFontList) ---
// Verified against dwrite.h.
// IDWriteFontList (6) +
//  [6] GetFamilyNames
//  [7] GetFirstMatchingFont
//  [8] GetMatchingFonts

/// IDWriteFontFamily::GetFamilyNames — vtable slot 6
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
// Verified against dwrite.h (IDWriteFont : IUnknown).
// Ref: https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwritefont
// IUnknown (3) +
//  [3]  GetFontFamily
//  [4]  GetWeight         — DWRITE_FONT_WEIGHT GetWeight()
//  [5]  GetStretch
//  [6]  GetStyle
//  [7]  IsSymbolFont
//  [8]  GetFaceNames
//  [9]  GetInformationalStrings
//  [10] GetSimulations
//  [11] GetMetrics
//  [12] HasCharacter
//  [13] CreateFontFace

/// IDWriteFont::GetWeight — vtable slot 4
typedef _GetWeightNative = Int32 Function(Pointer<IntPtr> self);
typedef _GetWeightDart = int Function(Pointer<IntPtr> self);

int fontGetWeight(Pointer<IntPtr> font) {
  final fn = vtableSlot<_GetWeightNative>(font, 4).asFunction<_GetWeightDart>();
  return fn(font);
}

/// IDWriteFont::GetStyle — vtable slot 6
typedef _GetStyleNative = Int32 Function(Pointer<IntPtr> self);
typedef _GetStyleDart = int Function(Pointer<IntPtr> self);

int fontGetStyle(Pointer<IntPtr> font) {
  final fn = vtableSlot<_GetStyleNative>(font, 6).asFunction<_GetStyleDart>();
  return fn(font);
}

// --- IDWriteLocalizedStrings vtable ---
// Verified against dwrite.h.
// Ref: https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwritelocalizedstrings
// IUnknown (3) +
//  [3] GetCount
//  [4] FindLocaleName
//  [5] GetLocaleNameLength
//  [6] GetLocaleName
//  [7] GetStringLength
//  [8] GetString

/// IDWriteLocalizedStrings::GetCount — vtable slot 3
typedef _GetCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetCountDart = int Function(Pointer<IntPtr> self);

int localizedStringsGetCount(Pointer<IntPtr> strings) {
  final fn =
      vtableSlot<_GetCountNative>(strings, 3).asFunction<_GetCountDart>();
  return fn(strings);
}

/// IDWriteLocalizedStrings::FindLocaleName — vtable slot 4
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

/// IDWriteLocalizedStrings::GetStringLength — vtable slot 7
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

/// IDWriteLocalizedStrings::GetString — vtable slot 8
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

/// IDWriteFont::CreateFontFace — vtable slot 13
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

/// IDWriteFontFace::GetFiles — vtable slot 5 (best-effort binding)
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
  final fn = vtableSlot<_FontFaceGetFilesNative>(fontFace, 5)
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

/// IDWriteLocalFontFileLoader::GetFilePathLengthFromKey — vtable slot 4 on the
/// loader interface (IDWriteLocalFontFileLoader extends IDWriteFontFileLoader)
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

/// IDWriteLocalFontFileLoader::GetFilePathFromKey — vtable slot 5 on the loader
/// interface
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

/// High-level helper: extract file paths for a font family using DirectWrite:
/// - For each font in the family, create an IDWriteFontFace
/// - Ask the font face for its font files (IDWriteFontFile*[])
/// - For each IDWriteFontFile call GetReferenceKey; if the loader is a
///   local file loader (IDWriteLocalFontFileLoader), use it to get the actual
///   file path via GetFilePathLengthFromKey/GetFilePathFromKey.
/// Note: this is best-effort. Only files whose loader supports the local-file
/// path API will yield paths. COM references are released.
List<String> getFamilyFilePaths(Pointer<IntPtr> family) {
  final paths = <String>[];

  // Determine number of fonts in the family (IDWriteFontList::GetFontCount — vtable slot 4)
  final fontCount = fontListGetFontCount(family).clamp(0, kMaxFontCount);

  final ppFont = calloc<Pointer<IntPtr>>();
  final ppFontFace = calloc<Pointer<IntPtr>>();
  final pFileCount = calloc<Uint32>();
  final ppLoader = calloc<Pointer<IntPtr>>();
  try {
    for (var i = 0; i < fontCount; i++) {
      // Get font (IDWriteFontList::GetFont vtable slot 5) — wrapper fontListGetFont used
      final hrFont = fontListGetFont(family, i, ppFont);
      if (!succeeded(hrFont)) continue;

      final font = ppFont.value;
      if (font.address == 0) {
        continue;
      }

      try {
        // Create font face for the font
        ppFontFace.value = Pointer<IntPtr>.fromAddress(0);
        final hrCreateFace = fontCreateFontFace(font, ppFontFace);
        if (!succeeded(hrCreateFace)) continue;
        final fontFace = ppFontFace.value;
        if (fontFace.address == 0) continue;

        try {
          // Get files from the font face
          pFileCount.value = 0;
          // First call with null files to get count (some implementations accept nullptr)
          var hrFiles = fontFaceGetFiles(
              fontFace, pFileCount, Pointer<Pointer<IntPtr>>.fromAddress(0));
          final fileCount = pFileCount.value;
          if (fileCount == 0) continue;

          final filesArray = calloc<Pointer<IntPtr>>(fileCount);
          try {
            hrFiles = fontFaceGetFiles(fontFace, pFileCount, filesArray);
            if (!succeeded(hrFiles)) continue;

            for (var j = 0; j < fileCount; j++) {
              final file = filesArray[j];
              if (file.address == 0) continue;

              try {
                // Get loader for this font file (IDWriteFontFile::GetLoader)
                ppLoader.value = Pointer<IntPtr>.fromAddress(0);
                final hrLoader = fontFileGetLoader(file, ppLoader);
                if (!succeeded(hrLoader)) {
                  // fallback: try to interpret reference key as path (legacy behavior)
                  final pKeyPtr = calloc<Pointer<Void>>();
                  final pKeySize = calloc<Uint32>();
                  try {
                    final hrKey =
                        fontFileGetReferenceKey(file, pKeyPtr, pKeySize);
                    if (!succeeded(hrKey)) continue;
                    final keyPtr = pKeyPtr.value;
                    final keySize = pKeySize.value;
                    if (keyPtr.address == 0 || keySize == 0) continue;
                    if (keySize % 2 != 0) continue;
                    final charCount = keySize ~/ 2;
                    final pathPtr = Pointer<Uint16>.fromAddress(keyPtr.address);
                    final raw = utf16PointerToString(pathPtr, charCount);
                    if (raw.isNotEmpty) {
                      final trimmed = raw.split('\u0000').first;
                      if (trimmed.isNotEmpty) paths.add(trimmed);
                    }
                  } finally {
                    calloc.free(pKeyPtr);
                    calloc.free(pKeySize);
                  }
                  continue;
                }

                final loader = ppLoader.value;
                if (loader.address == 0) continue;

                try {
                  // Get reference key first
                  final pKeyPtr = calloc<Pointer<Void>>();
                  final pKeySize = calloc<Uint32>();
                  try {
                    final hrKey =
                        fontFileGetReferenceKey(file, pKeyPtr, pKeySize);
                    if (!succeeded(hrKey)) continue;
                    final keyPtr = pKeyPtr.value;
                    final keySize = pKeySize.value;
                    if (keyPtr.address == 0 || keySize == 0) continue;

                    // Ask loader for path length
                    final pPathLen = calloc<Uint32>();
                    try {
                      final hrLen = loaderGetFilePathLengthFromKey(
                          loader, keyPtr, keySize, pPathLen);
                      if (!succeeded(hrLen)) continue;
                      final pathLen = pPathLen.value;
                      if (pathLen == 0) continue;

                      final buf = calloc<Uint16>(pathLen + 1);
                      try {
                        final hrGet = loaderGetFilePathFromKey(
                            loader, keyPtr, keySize, buf, pathLen + 1);
                        if (!succeeded(hrGet)) continue;
                        final raw = utf16PointerToString(buf, pathLen);
                        if (raw.isNotEmpty) {
                          final trimmed = raw.split('\u0000').first;
                          if (trimmed.isNotEmpty) paths.add(trimmed);
                        }
                      } finally {
                        calloc.free(buf);
                      }
                    } finally {
                      calloc.free(pPathLen);
                    }
                  } finally {
                    calloc.free(pKeyPtr);
                    calloc.free(pKeySize);
                  }
                } finally {
                  comRelease(loader);
                }
              } finally {
                // Release the IDWriteFontFile COM object
                comRelease(file);
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
    calloc.free(ppLoader);
  }

  return paths;
}

/// Helper: for a given IDWriteFont, attempt to create a font face, query its
/// associated font files, and return the first local file path found (or an
/// empty string if none). This is a convenience wrapper used by higher-level
/// scanners that want a best-effort per-font file path.
String getFirstFilePathForFont(Pointer<IntPtr> font) {
  if (font.address == 0) return '';

  final ppFontFace = calloc<Pointer<IntPtr>>();
  final pFileCount = calloc<Uint32>();
  final ppLoader = calloc<Pointer<IntPtr>>();
  try {
    ppFontFace.value = Pointer<IntPtr>.fromAddress(0);
    var hr = fontCreateFontFace(font, ppFontFace);
    if (!succeeded(hr)) return '';

    final fontFace = ppFontFace.value;
    if (fontFace.address == 0) return '';

    try {
      // Get files
      pFileCount.value = 0;
      hr = fontFaceGetFiles(
          fontFace, pFileCount, Pointer<Pointer<IntPtr>>.fromAddress(0));
      final fileCount = pFileCount.value;
      if (fileCount == 0) return '';

      final filesArray = calloc<Pointer<IntPtr>>(fileCount);
      try {
        hr = fontFaceGetFiles(fontFace, pFileCount, filesArray);
        if (!succeeded(hr)) return '';

        for (var j = 0; j < fileCount; j++) {
          final file = filesArray[j];
          if (file.address == 0) continue;

          try {
            // Get loader for this font file
            ppLoader.value = Pointer<IntPtr>.fromAddress(0);
            final hrLoader = fontFileGetLoader(file, ppLoader);
            if (!succeeded(hrLoader)) {
              // Fallback: try to interpret reference key as UTF-16 path
              final pKeyPtr = calloc<Pointer<Void>>();
              final pKeySize = calloc<Uint32>();
              try {
                final hrKey = fontFileGetReferenceKey(file, pKeyPtr, pKeySize);
                if (!succeeded(hrKey)) continue;
                final keyPtr = pKeyPtr.value;
                final keySize = pKeySize.value;
                if (keyPtr.address == 0 || keySize == 0) continue;
                if (keySize % 2 != 0) continue;
                final charCount = keySize ~/ 2;
                final pathPtr = Pointer<Uint16>.fromAddress(keyPtr.address);
                final raw = utf16PointerToString(pathPtr, charCount);
                if (raw.isNotEmpty) {
                  final trimmed = raw.split('\u0000').first;
                  if (trimmed.isNotEmpty) return trimmed;
                }
              } finally {
                calloc.free(pKeyPtr);
                calloc.free(pKeySize);
              }
              continue;
            }

            final loader = ppLoader.value;
            if (loader.address == 0) continue;

            try {
              // Get reference key first
              final pKeyPtr = calloc<Pointer<Void>>();
              final pKeySize = calloc<Uint32>();
              try {
                final hrKey = fontFileGetReferenceKey(file, pKeyPtr, pKeySize);
                if (!succeeded(hrKey)) continue;
                final keyPtr = pKeyPtr.value;
                final keySize = pKeySize.value;
                if (keyPtr.address == 0 || keySize == 0) continue;

                // Ask loader for path length
                final pPathLen = calloc<Uint32>();
                try {
                  final hrLen = loaderGetFilePathLengthFromKey(
                      loader, keyPtr, keySize, pPathLen);
                  if (!succeeded(hrLen)) continue;
                  final pathLen = pPathLen.value;
                  if (pathLen == 0) continue;

                  final buf = calloc<Uint16>(pathLen + 1);
                  try {
                    final hrGet = loaderGetFilePathFromKey(
                        loader, keyPtr, keySize, buf, pathLen + 1);
                    if (!succeeded(hrGet)) continue;
                    final raw = utf16PointerToString(buf, pathLen);
                    if (raw.isNotEmpty) {
                      final trimmed = raw.split('\u0000').first;
                      if (trimmed.isNotEmpty) return trimmed;
                    }
                  } finally {
                    calloc.free(buf);
                  }
                } finally {
                  calloc.free(pPathLen);
                }
              } finally {
                calloc.free(pKeyPtr);
                calloc.free(pKeySize);
              }
            } finally {
              comRelease(loader);
            }
          } finally {
            comRelease(file);
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
    calloc.free(ppLoader);
  }

  return '';
}
