## 0.1.0

- feat: system font family and weight scanning via Windows DirectWrite
- feat: `JustFontScan.scan()` returns font families sorted by name with caching
- feat: `JustFontScan.weightsFor()` queries supported weights for a specific family
- fix: COM null guards, absolute DLL paths, proper CoUninitialize for safety
