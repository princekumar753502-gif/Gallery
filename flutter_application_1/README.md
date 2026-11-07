# Gallery

A simple, beautiful photo gallery for Android, built with Flutter.

**Features:** photo grid (newest first) · albums · full-screen viewer with swipe, pinch-zoom and double-tap zoom · photo details · delete · premium dark and light themes (System / Light / Dark, remembered) · Android 14 "Select photos" support · 100% free, no API keys, no internet needed.

---

## 1. Project structure

```
gallery/
├── pubspec.yaml
├── android/app/src/main/AndroidManifest.xml     <- photo permissions live here
├── lib/
│   ├── main.dart                                <- app entry + theme wiring
│   ├── theme/app_theme.dart                     <- dark & light themes
│   ├── state/
│   │   ├── theme_controller.dart                <- System/Light/Dark, saved
│   │   ├── gallery_controller.dart              <- permission + albums + main list
│   │   └── paged_assets.dart                    <- loads photos page by page
│   ├── services/gallery_service.dart            <- the only file that talks to photo_manager
│   ├── screens/
│   │   ├── home_shell.dart                      <- Photos / Albums tabs, permission states
│   │   ├── albums_screen.dart                   <- album grid + album contents
│   │   └── photo_viewer_screen.dart             <- full-screen viewer, details, delete
│   ├── widgets/
│   │   ├── photo_grid.dart                      <- thumbnail grid
│   │   ├── zoomable_image.dart                  <- pinch / double-tap zoom
│   │   ├── state_views.dart                     <- empty / permission screens
│   │   └── theme_menu_button.dart               <- theme picker
│   └── utils/format.dart                        <- date and file-size text
└── test/widget_test.dart
```

## 2. Dependencies (`pubspec.yaml`)

| Package | Why |
|---|---|
| `photo_manager ^3.11.0` | Reads photos/albums from the device and handles Android photo permissions |
| `photo_manager_image_provider ^2.2.0` | Lets Flutter's `Image` widget show those photos |
| `shared_preferences ^2.3.0` | Remembers your theme choice |

All are free and open source. (`pubspec.yaml` is included in this folder.)

## 3. Android permissions (already in `AndroidManifest.xml`)

| Permission | Android versions | Purpose |
|---|---|---|
| `READ_EXTERNAL_STORAGE` (max SDK 32) | 12L and older | Read photos |
| `READ_MEDIA_IMAGES` | 13+ | Read photos |
| `READ_MEDIA_VIDEO` | 13+ | Required by the plugin, which requests images and videos together (the app never shows videos) |
| `READ_MEDIA_VISUAL_USER_SELECTED` | 14+ | Enables the "Select photos" (limited access) choice |
| `WRITE_EXTERNAL_STORAGE` (max SDK 29) | 10 and older | Lets the plugin delete photos |

On Android 14+ the user can pick **Allow all** or **Select photos**. In the second case Gallery shows a "Showing only the photos you selected" banner with a **Manage** button to choose more.

No Gradle edits are needed on a fresh `flutter create` project.

---

## 4. Setup on Windows (Android Studio)

1. **Install Flutter**: follow <https://docs.flutter.dev/get-started/install/windows/mobile>. Unzip/clone the SDK to a short path such as `C:\src\flutter` and add `C:\src\flutter\bin` to your `PATH`.
2. **Install Android Studio** and, in *Settings → Plugins*, install **Flutter** (this also installs **Dart**).
3. In Android Studio: *Settings → Languages & Frameworks → Android SDK* → install an **Android 14 or 15 SDK Platform**, plus **Android SDK Command-line Tools** (SDK Tools tab).
4. Open **PowerShell** and run:
   ```powershell
   flutter doctor --android-licenses   # press y to accept all
   flutter doctor                      # everything for Android should be ticked
   ```
5. **Create the project and add Gallery's files:**
   ```powershell
   cd $HOME\AndroidStudioProjects
   flutter create --org com.example --platforms android gallery
   ```
   Then copy from this folder into the new `gallery` project, **replacing** what exists:
   - `pubspec.yaml`
   - the whole `lib/` folder (delete the generated `main.dart` first, or just overwrite it)
   - `test/widget_test.dart`
   - `android/app/src/main/AndroidManifest.xml`

   > The manifest assumes the app id `com.example.gallery`, which is what the command above creates. If you used a different `--org`, keep your generated manifest and only paste the five `<uses-permission>` lines from this one.
6. Fetch packages and check the code:
   ```powershell
   cd gallery
   flutter pub get
   flutter analyze
   flutter test
   ```
7. Open the `gallery` folder in Android Studio (*File → Open*).

## 5. Run it

### On the emulator
1. *Tools → Device Manager → Create Device* → pick a Pixel phone → choose a **system image with Google Play, API 34 or 35** → Finish → press ▶ to start it.
2. **Add some photos** (an empty emulator has none):
   - Open the emulator's **Camera** app and take pictures (the virtual scene works), **or**
   - **Drag image files** from Windows onto the emulator window, **or**
   - Use adb:
     ```powershell
     adb push photo.jpg /sdcard/Pictures/
     adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/photo.jpg
     ```
3. In Android Studio pick the emulator in the device drop-down and press ▶ **Run**, or:
   ```powershell
   flutter run
   ```

### On a real phone
1. On the phone: *Settings → About phone* → tap **Build number** 7 times → *Developer options* → turn on **USB debugging**.
2. Connect by USB and accept the "Allow USB debugging?" prompt.
3. Check it is seen: `flutter devices`, then `flutter run` (or press ▶).

### Build an installable APK
```powershell
flutter build apk --release
# result: build\app\outputs\flutter-apk\app-release.apk
```

---

## 6. What to test

| Test | Expected |
|---|---|
| First launch | System permission prompt for photos |
| **Allow all** | Photos grid fills, newest first |
| **Select photos** (Android 14+) | Only chosen photos, plus a banner with **Manage** |
| **Don't allow** | "Allow access to your photos" screen. **Allow access** asks again; **Open settings** opens the app's settings page. Grant access there and come back: photos load automatically |
| Tap a photo | Full-screen viewer; swipe left/right; pinch or double-tap to zoom; tap once to hide/show controls |
| **Details** | Name, date, resolution, size, folder |
| **Delete** | Confirmation, then the Android system confirmation (Android 11+) |
| Albums tab | Grid of folders with covers and counts |
| Palette icon (top right) | System / Light / Dark; survives restarting the app |
| Pull down on the grid | Refreshes the list |

Reset permissions between tests:
```powershell
adb shell pm clear com.example.gallery
```

## 7. Troubleshooting

- **Grid is empty on the emulator**: the emulator has no photos yet, or they were not indexed. Take a photo with its Camera app, or re-run the `MEDIA_SCANNER_SCAN_FILE` command above.
- **"Allow access" does nothing**: Android stops showing the prompt after two denials. Use **Open settings → Permissions → Photos and videos → Allow**.
- **Glide warnings or version conflicts during the Android build**: in `android/build.gradle(.kts)` force Glide 4.16.0, as recommended on the [photo_manager page](https://pub.dev/packages/photo_manager).
- **Release build shows missing thumbnails**: try `flutter build apk --release --no-shrink` once to confirm it is a code-shrinking issue.
- **Gradle / SDK errors**: run `flutter doctor -v` and fix whatever it flags; this is almost always a missing Android SDK component or license.
