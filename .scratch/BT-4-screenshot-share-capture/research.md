# Research: Android Share Sheet & On-Device OCR Pipeline (BT-4)

## 1. Trigger Architecture: Android Intent `ACTION_SEND`

When a user taps "Share" on a transaction receipt in a banking app:
1. The source app creates an Intent:
   - Action: `Intent.ACTION_SEND`
   - Type: `image/png`, `image/jpeg`, or `image/*`
   - Extra: `Intent.EXTRA_STREAM` containing the `content://` Uri of the receipt image.
2. Android opens the system Share Sheet.
3. User selects Cashew.
4. Android routes the intent to Cashew's `MainActivity`.

### Intent Registration (`AndroidManifest.xml`)
```xml
<activity
    android:name=".MainActivity"
    ...>
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="image/*" />
        <data android:mimeType="text/plain" />
    </intent-filter>
</activity>
```

---

## 2. On-Device OCR Engine: Bundled Google ML Kit

### Why Not `google_mlkit_text_recognition` Plugin?
The pub.dev package `google_mlkit_text_recognition` (v0.13.0+) depends on newer Android Gradle Plugin (AGP) and compileSdk versions that conflict with Flutter 3.19.6's locked toolchain.

### Recommended Path: Direct Kotlin Integration
Directly add Google's standalone ML Kit Text Recognition client in `android/app/build.gradle`:
```groovy
dependencies {
    implementation 'com.google.mlkit:text-recognition:16.0.1'
}
```
In `MainActivity.kt`:
1. Use `TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)`.
2. Process `InputImage.fromFilePath(context, uri)`.
3. Return recognized lines and blocks over a Flutter `MethodChannel`:
   - `channel: "com.budget.tracker/ocr"`
   - `method: "processImage"` -> `List<Map<String, dynamic>>` (text, bounding box, lines).

---

## 3. Storage & Privacy Lifecycle
1. The shared image is read from the `content://` Uri or cached to app cache directory (`context.cacheDir`).
2. OCR runs on-device in a background thread (`Dispatchers.Default`).
3. Extracted text is passed to Dart.
4. **Immediate Deletion**: The temporary file in cache is deleted immediately (`file.delete()`).
5. No images are persisted to SQLite or Drift database.
