# How to build the Project Time APK (Windows)

Building an Android app turns the code into an `.apk` file you can install on a phone.
It needs two free tools installed once, then a few commands. Plan ~30–60 min the first
time (mostly downloads), a couple of minutes after that.

---

## Part A — One-time setup (skip if you already have Flutter + Android Studio)

### 1. Install Flutter
- Go to https://docs.flutter.dev/get-started/install/windows/mobile
- Download the Flutter SDK zip, extract it to a simple path like `C:\src\flutter`
  (avoid spaces and `C:\Program Files`).
- Add `C:\src\flutter\bin` to your Windows **Path**:
  - Press Start → type "environment variables" → "Edit the system environment variables"
    → "Environment Variables…" → under *User variables* select **Path** → **Edit** → **New**
    → paste `C:\src\flutter\bin` → OK everything.

### 2. Install Android Studio (this provides the Android SDK)
- Get it from https://developer.android.com/studio and install with defaults.
- Open it once and let it finish "downloading components".
- In Android Studio: **More Actions → SDK Manager** → make sure an **Android SDK** and
  **Android SDK Command-line Tools** are checked → Apply.

### 3. Verify and accept licenses
Open a **new** PowerShell or Command Prompt window and run:
```
flutter doctor
flutter doctor --android-licenses
```
Type `y` to accept the licenses. `flutter doctor` should show green checks for
"Flutter" and "Android toolchain". (Ignore anything about Visual Studio / Chrome —
not needed for an Android APK.)

---

## Part B — Build the APK

Open a terminal **inside the project folder**. Easiest way: open the
`Project Time` folder in File Explorer, click the address bar, type `cmd`, press Enter.

Then run these four commands one at a time:

```
flutter create . --org com.projecttime --project-name project_time --platforms=android
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

- The 1st creates the Android project files (safe — it won't touch the app code).
- The 3rd generates the database code (required — wait for it to finish).
- The 4th builds the APK. First run is slow; later runs are fast.

When it finishes you'll see a line like `✓ Built build\app\outputs\flutter-apk\app-release.apk`.

**Your APK is here:**
```
Project Time\build\app\outputs\flutter-apk\app-release.apk
```

---

## Part C — Put it on your phone

**Option 1 — phone plugged in via USB (simplest):**
1. On the phone: Settings → About phone → tap "Build number" 7 times to enable
   Developer options → then enable **USB debugging**.
2. Plug the phone into the PC, tap **Allow** on the phone.
3. In the same terminal run:
   ```
   flutter install
   ```
   This installs the app directly.

**Option 2 — copy the file:**
- Copy `app-release.apk` to the phone (USB, Google Drive, email to yourself, etc.).
- Tap it on the phone to install. You'll need to allow "Install from unknown sources"
  when prompted.

---

## Notes

- **Just want to try it without making an APK?** Plug in a phone (or start an emulator
  from Android Studio) and run `flutter run`. It launches the app live.
- **Smaller APKs:** `flutter build apk --split-per-abi` makes 3 smaller files; install
  the one ending in `arm64-v8a` on most modern phones.
- **Signing:** this build is signed with a debug key so it installs fine for personal
  use. It is *not* set up for publishing to the Google Play Store — that needs a release
  signing key, which is a separate step if you ever want it.
- **If `dart run build_runner` errors about versions**, run `flutter pub get` again then
  retry it. See `CONSISTENCY_REPORT.md` → "Expected errors" for the full list.
```
