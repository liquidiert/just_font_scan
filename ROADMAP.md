# just_font_scan 구현 로드맵

## 현재 상태
- `flutter create --template=package` 기본 템플릿 상태
- Calculator 클래스만 존재, example 없음

---

## Phase 1: 프로젝트 기반 정리

- [ ] `pubspec.yaml` 수정
  - description, homepage, sdk constraint 정리
  - flutter 의존성 제거 (순수 Dart 패키지, dart:ffi만 사용)
  - `ffi` 패키지 의존성 추가 여부 결정 (dart:ffi는 내장이라 불필요할 수 있음)
  - platforms: windows 명시
- [ ] 기본 템플릿 파일 정리
  - `lib/just_font_scan.dart` — Calculator 제거
  - `test/` — 기본 테스트 제거

## Phase 2: 모델 & Public API 정의

- [ ] `lib/src/models.dart` — `FontFamily` 클래스
  - `name: String`, `weights: List<int>` (오름차순, 100~900)
  - `toString()`, `==`, `hashCode` 구현
- [ ] `lib/src/font_scanner.dart` — `JustFontScan` 클래스
  - `static List<FontFamily> scan()` — 시스템 폰트 스캔 (캐시)
  - `static void clearCache()` — 캐시 초기화
  - `static List<int> weightsFor(String familyName)` — 특정 패밀리 weight 조회
  - `Platform.isWindows` 분기 (향후 macOS 확장 지점)
- [ ] `lib/just_font_scan.dart` — export 파일
  - models.dart, font_scanner.dart export

## Phase 3: Windows DirectWrite COM 바인딩

- [ ] `lib/src/windows/dwrite_bindings.dart`
  - `dwrite.dll` DynamicLibrary.open
  - `DWriteCreateFactory` 함수 lookup & typedef
  - COM vtable 호출 헬퍼 함수들:
    - IUnknown: Release (vtable[2])
    - IDWriteFactory: GetSystemFontCollection (vtable[3])
    - IDWriteFontCollection: GetFontFamilyCount (vtable[3]), GetFontFamily (vtable[4])
    - IDWriteFontFamily: GetFamilyNames (vtable[?]), GetFontCount (vtable[?]), GetFont (vtable[?])
    - IDWriteFont: GetWeight (vtable[?])
    - IDWriteLocalizedStrings: GetCount (vtable[?]), FindLocaleName (vtable[?]), GetStringLength (vtable[?]), GetString (vtable[?])
  - vtable 오프셋 계산 (MSDN 기준 정확히)
    - IUnknown: 3개 (QI=0, AddRef=1, Release=2)
    - IDWriteFactory: IUnknown(3) + 커스텀 메서드 순서
    - IDWriteFontCollection: IUnknown(3) + 커스텀
    - IDWriteFontList: IUnknown(3) + 커스텀 (GetFontCollection=0, GetFontCount=1, GetFont=2)
    - IDWriteFontFamily: IDWriteFontList 상속 + GetFamilyNames 등
    - IDWriteFont: IUnknown(3) + 커스텀
    - IDWriteLocalizedStrings: IUnknown(3) + 커스텀
  - CoInitializeEx 호출 (ole32.dll)
  - GUID 구조체 (IID_IDWriteFactory)

## Phase 4: Windows 폰트 스캐너 구현

- [ ] `lib/src/windows/windows_font_scanner.dart`
  - `List<FontFamily> scanFonts()` 함수 구현
  - 흐름:
    1. CoInitializeEx 호출
    2. DWriteCreateFactory → IDWriteFactory 얻기
    3. GetSystemFontCollection → IDWriteFontCollection 얻기
    4. GetFontFamilyCount로 패밀리 수 확인
    5. 각 패밀리에 대해:
       a. GetFontFamily → IDWriteFontFamily
       b. GetFamilyNames → IDWriteLocalizedStrings → 이름 추출
          - "en-us" 로캘 우선, 없으면 index 0
       c. '@'로 시작하면 skip
       d. GetFontCount + GetFont → IDWriteFont → GetWeight
       e. weight 값 수집 & 중복 제거 & 오름차순 정렬
    6. 모든 COM 리소스 Release()
    7. 패밀리명 기준 정렬하여 반환
  - 에러 처리: HRESULT 체크, 실패 시 빈 리스트 반환, 크래시 방지

## Phase 5: Example

- [ ] `example/main.dart`
  - scan() 호출 → 전체 패밀리 목록 출력
  - weightsFor("Arial") 같은 개별 조회 예시
  - "Source Code Pro" 등으로 패밀리 그룹핑 확인

## Phase 6: 테스트 & 정리

- [ ] 단위 테스트 (모델 클래스 테스트)
- [ ] Windows 환경 통합 테스트 (실제 scan 호출)
- [ ] analysis_options.yaml 정리
- [ ] README.md 작성

---

## 핵심 기술 포인트

### COM vtable 오프셋 (MSDN 기준 정밀 계산 필요)

```
IUnknown (3개):
  [0] QueryInterface
  [1] AddRef
  [2] Release

IDWriteFactory (IUnknown + 커스텀):
  [3] GetSystemFontCollection    ← 이것을 사용
  [4] GetSystemFontFallback (Win8.1+)
  ... (나머지 메서드들)

IDWriteFontCollection (IUnknown + 커스텀):
  [3] GetFontFamilyCount         ← 이것을 사용
  [4] GetFontFamily              ← 이것을 사용
  [5] FindFamilyName
  [6] GetFontFromFontFace

IDWriteFontList (IUnknown + 커스텀):
  [3] GetFontCollection
  [4] GetFontCount               ← 이것을 사용
  [5] GetFont                    ← 이것을 사용

IDWriteFontFamily (IDWriteFontList + 커스텀):
  [6] GetFamilyNames             ← 이것을 사용

IDWriteFont (IUnknown + 커스텀):
  [3] GetFontFamily
  [4] GetFace
  [5] IsSymbolFont
  [6] GetFaceNames
  [7] GetInformationalStrings
  [8] GetSimulations
  [9] GetMetrics
  [10] HasCharacter
  [11] CreateFontFace
  ... GetWeight는 어디? → GetSimulations=8, GetMetrics=9 사이에 GetWeight가 없음
  → 실제로 GetWeight는 별도 확인 필요

IDWriteLocalizedStrings (IUnknown + 커스텀):
  [3] GetCount
  [4] FindLocaleName
  [5] GetLocaleNameLength
  [6] GetLocaleName
  [7] GetStringLength
  [8] GetString
```

> **주의**: 위 오프셋은 추정치. 구현 시 MSDN의 실제 vtable 순서를 반드시 교차 검증해야 함. 특히 IDWriteFactory의 GetSystemFontCollection 위치와 IDWriteFont의 GetWeight 위치는 헤더 파일(dwrite.h) 기준으로 확인.

### 작업 순서 권장

Phase 2 → 3 → 4 순서가 핵심. Phase 3에서 vtable 오프셋을 틀리면 크래시가 나므로, dwrite.h 헤더의 인터페이스 정의 순서를 정확히 따라야 함. Phase 4에서 실제 호출 테스트를 빠르게 해서 오프셋 검증.

---

## 향후 확장

- **macOS**: `lib/src/macos/coretext_font_scanner.dart` 추가, CoreText API (CTFontCollectionCreateFromAvailableFonts 등) 사용
- **Linux**: fontconfig 기반 구현 가능
- **비동기 API**: 필요 시 `scanAsync()` 추가 (Isolate에서 FFI 호출)
