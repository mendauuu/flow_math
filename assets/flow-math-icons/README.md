# Flow Math app icons

There are 4 icon designs here. **A (Moon divide) is my pick.**
Open `preview.png` to see them side by side.

Every folder has the same files, so choose one design and use only that folder.

## What's in each folder

| File or folder | What it's for |
|---|---|
| `play-store-icon-512.png` | Upload this as the app icon on your Play Console store listing |
| `android/app/src/main/res/` | Ready-made launcher icons for the phone's home screen |
| `assets/icon/` | Big source images, only needed for Way 2 below |

---

## Way 1: copy and paste (easiest, no packages)

1. Open the folder of the design you chose, for example `A-moon-divide`.
2. Copy its `android` folder into the root of your Flutter project.
   When your computer asks, choose **Replace** / **Overwrite**.
3. Open `android/app/src/main/AndroidManifest.xml` and check it says
   `android:icon="@mipmap/ic_launcher"`. New Flutter projects already have this.
4. Uninstall the old app from your phone, then run `flutter run`.
   (Android remembers old icons, so a fresh install shows the new one.)

Done. On Android 8 and newer the icon is an adaptive icon, so it fits every phone shape
(circle, rounded square, squircle). Older phones get a rounded-square version.

---

## Way 2: flutter_launcher_icons package

Use this instead of Way 1, not together with it.

1. Copy the `assets` folder of your chosen design into the root of your project,
   so you have `assets/icon/icon-1024.png` and the two `adaptive-*.png` files.
2. Add this to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon-1024.png"
  min_sdk_android: 21
  adaptive_icon_background: "assets/icon/adaptive-background.png"
  adaptive_icon_foreground: "assets/icon/adaptive-foreground.png"
  adaptive_icon_foreground_inset: 0
```

3. Run:

```
flutter pub get
dart run flutter_launcher_icons
```

4. Uninstall the old app from your phone, then run `flutter run`.

`adaptive_icon_foreground_inset: 0` matters: the foreground images already have the right
padding, and the package would otherwise shrink them by another 16%.

---

## Sizes, for reference

- Play Store icon: 512 × 512 PNG, square corners. Google Play rounds the corners itself.
- `icon-1024.png`: 1024 × 1024 master image.
- `adaptive-foreground.png` / `adaptive-background.png`: 1024 × 1024 layers (108 dp canvas).
- Launcher icons: mdpi 48 px up to xxxhdpi 192 px, adaptive layers 108 px up to 432 px.
