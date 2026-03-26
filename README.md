# Flow Math — Anti-Scroll Focus App

A calm, immersive math experience designed to replace mindless scrolling with deep focus.

---

## Quick Start

### Prerequisites
- Flutter SDK ≥ 3.0.0 ([install](https://docs.flutter.dev/get-started/install))
- Dart SDK ≥ 3.0.0 (bundled with Flutter)
- Android Studio or Xcode for device/emulator

### 1. Copy project files

Place all files into a folder called `flow_math/` matching this structure:

```
flow_math/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── math_problem.dart
│   │   └── session_stats.dart
│   ├── services/
│   │   ├── session_service.dart
│   │   └── difficulty_service.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── flow_screen.dart
│   │   ├── results_screen.dart
│   │   └── stats_screen.dart
│   ├── widgets/
│   │   ├── animated_background.dart
│   │   ├── problem_display.dart
│   │   ├── session_hud.dart
│   │   ├── numpad_widget.dart
│   │   └── feedback_overlay.dart
│   └── utils/
│       └── app_theme.dart
```

### 2. Install dependencies

```bash
cd flow_math
flutter pub get
```

### 3. Run

```bash
# iOS simulator
flutter run -d "iPhone 15"

# Android emulator
flutter run -d emulator-5554

# Physical device (USB)
flutter run
```

### 4. Build release APK / IPA

```bash
# Android
flutter build apk --release

# iOS
flutter build ipa --release
```

---

## Architecture

| Layer | Files | Responsibility |
|---|---|---|
| Models | `math_problem.dart`, `session_stats.dart` | Data structures, math generation, error explanations |
| Services | `session_service.dart`, `difficulty_service.dart` | Business logic, adaptive difficulty, local persistence (Hive) |
| Screens | `home_screen.dart`, `flow_screen.dart`, `results_screen.dart`, `stats_screen.dart` | Navigation and page layout |
| Widgets | `animated_background.dart`, `problem_display.dart`, `session_hud.dart`, `numpad_widget.dart`, `feedback_overlay.dart` | Reusable UI components |
| Utils | `app_theme.dart` | Colors, text styles, gradients |

---

## Features (MVP)

| Feature | Status |
|---|---|
| Adaptive difficulty (1–10) | ✅ |
| Anti-Scroll mode (starts easy, ramps up) | ✅ |
| Flow State mode | ✅ |
| Per-problem & session timers | ✅ |
| Streak tracking | ✅ |
| Focus Score (speed + accuracy + consistency) | ✅ |
| Rule-based error explanations | ✅ |
| Local persistence (Hive) | ✅ |
| Session history screen | ✅ |
| Immersive full-screen UI | ✅ |
| Animated nature background | ✅ |
| Swipe-down to end session | ✅ |

---

## Roadmap

### Version 2
- [ ] Audio system (rain / forest / ambient loops via `audioplayers`)
- [ ] Haptic patterns tuned to correct/incorrect
- [ ] Longer explanation modal with worked example

### Version 3
- [ ] Algebra problems (solve for x)
- [ ] Multi-step operations
- [ ] Time-pressure mode (shrinking timer bar)
- [ ] Home screen widget (quick-launch focus session)

---

## Adding Audio (V2 guide)

1. Add `.mp3` loop files to `assets/audio/rain.mp3`, `forest.mp3`, `ambient.mp3`
2. Declare them in `pubspec.yaml` under `flutter: assets:`
3. In `session_service.dart`, inject `AudioPlayer` and call:

```dart
final _player = AudioPlayer();

void _startAudio(String mode) async {
  await _player.setReleaseMode(ReleaseMode.loop);
  await _player.play(AssetSource('audio/$mode.mp3'));
}
```

---

## Design Tokens

| Token | Value | Usage |
|---|---|---|
| `deepNight` | `#080D18` | Primary background |
| `primary` | `#6EC6AA` | Accents, correct states |
| `gold` | `#D4A853` | Streak, Anti-Scroll mode |
| `incorrect` | `#E57373` | Soft error colour |
| Problem font size | 64px, weight 200 | Ultra-light for calm feel |

---

## Philosophy

> This is not a math app.  
> It is a focus tool disguised as a math experience.

The design avoids punishment, embraces silence, and keeps the user in the flow zone — not bored, not overwhelmed.
