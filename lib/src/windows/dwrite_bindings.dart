// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// --- HRESULT helper ---

bool succeeded(int hr) => hr >= 0;

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
/// );
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

// --- CoInitializeEx ---

typedef CoInitializeExNative = Int32 Function(
  Pointer<Void> reserved,
  Uint32 dwCoInit,
);
typedef CoInitializeExDart = int Function(
  Pointer<Void> reserved,
  int dwCoInit,
);

/// COINIT_APARTMENTTHREADED = 0x2
const int COINIT_APARTMENTTHREADED = 0x2;

// --- COM vtable helpers ---

/// Reads the vtable pointer array from a COM interface pointer.
/// comPtr points to the object, whose first field is a pointer to the vtable.
Pointer<IntPtr> _vtable(Pointer<IntPtr> comPtr) {
  // *comPtr = vtable pointer
  final vtableAddr = comPtr.value;
  return Pointer<IntPtr>.fromAddress(vtableAddr);
}

/// Gets a function pointer from vtable at [slotIndex].
Pointer<NativeFunction<T>> vtableSlot<T extends Function>(
  Pointer<IntPtr> comPtr,
  int slotIndex,
) {
  final vtable = _vtable(comPtr);
  final fnAddr = vtable.elementAt(slotIndex).value;
  return Pointer<NativeFunction<T>>.fromAddress(fnAddr);
}

// --- IUnknown ---

/// IUnknown::Release (slot 2)
typedef _ReleaseNative = Uint32 Function(Pointer<IntPtr> self);
typedef _ReleaseDart = int Function(Pointer<IntPtr> self);

int comRelease(Pointer<IntPtr> comPtr) {
  final fn = vtableSlot<_ReleaseNative>(comPtr, 2).asFunction<_ReleaseDart>();
  return fn(comPtr);
}

// --- IDWriteFactory vtable ---
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

/// IDWriteFactory::GetSystemFontCollection(
///   IDWriteFontCollection** fontCollection,
///   BOOL checkForUpdates
/// )
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
// IUnknown (3) +
//  [3] GetFontFamilyCount
//  [4] GetFontFamily
//  [5] FindFamilyName
//  [6] GetFontFromFontFace

typedef _GetFontFamilyCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetFontFamilyCountDart = int Function(Pointer<IntPtr> self);

int collectionGetFontFamilyCount(Pointer<IntPtr> collection) {
  final fn = vtableSlot<_GetFontFamilyCountNative>(collection, 3)
      .asFunction<_GetFontFamilyCountDart>();
  return fn(collection);
}

/// IDWriteFontCollection::GetFontFamily(UINT32 index, IDWriteFontFamily** fontFamily)
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
// IUnknown (3) +
//  [3] GetFontCollection
//  [4] GetFontCount
//  [5] GetFont

typedef _GetFontCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetFontCountDart = int Function(Pointer<IntPtr> self);

int fontListGetFontCount(Pointer<IntPtr> fontList) {
  final fn = vtableSlot<_GetFontCountNative>(fontList, 4)
      .asFunction<_GetFontCountDart>();
  return fn(fontList);
}

/// IDWriteFontList::GetFont(UINT32 index, IDWriteFont** font)
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
  final fn =
      vtableSlot<_GetFontNative>(fontList, 5).asFunction<_GetFontDart>();
  return fn(fontList, index, outFont);
}

// --- IDWriteFontFamily vtable (extends IDWriteFontList) ---
// IDWriteFontList (6) +
//  [6] GetFamilyNames

/// IDWriteFontFamily::GetFamilyNames(IDWriteLocalizedStrings** names)
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
// IUnknown (3) +
//  [3]  GetFontFamily
//  [4]  GetWeight         ← this is what we need
//  [5]  GetStretch
//  [6]  GetStyle
//  [7]  IsSymbolFont
//  [8]  GetFaceNames
//  [9]  GetInformationalStrings
//  [10] GetSimulations
//  [11] GetMetrics
//  [12] HasCharacter
//  [13] CreateFontFace

typedef _GetWeightNative = Int32 Function(Pointer<IntPtr> self);
typedef _GetWeightDart = int Function(Pointer<IntPtr> self);

int fontGetWeight(Pointer<IntPtr> font) {
  final fn =
      vtableSlot<_GetWeightNative>(font, 4).asFunction<_GetWeightDart>();
  return fn(font);
}

// --- IDWriteLocalizedStrings vtable ---
// IUnknown (3) +
//  [3] GetCount
//  [4] FindLocaleName
//  [5] GetLocaleNameLength
//  [6] GetLocaleName
//  [7] GetStringLength
//  [8] GetString

typedef _GetCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetCountDart = int Function(Pointer<IntPtr> self);

int localizedStringsGetCount(Pointer<IntPtr> strings) {
  final fn =
      vtableSlot<_GetCountNative>(strings, 3).asFunction<_GetCountDart>();
  return fn(strings);
}

/// FindLocaleName(const WCHAR* localeName, UINT32* index, BOOL* exists)
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

/// GetStringLength(UINT32 index, UINT32* length)
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

/// GetString(UINT32 index, WCHAR* stringBuffer, UINT32 size)
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
  final fn = vtableSlot<_GetStringNative>(strings, 8)
      .asFunction<_GetStringDart>();
  return fn(strings, index, buffer, size);
}
