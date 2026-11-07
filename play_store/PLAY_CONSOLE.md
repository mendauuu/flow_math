# Flow Math on Google Play

Everything to paste into Play Console, plus how to build and upload.

---

## 1. Files to upload

| What | File | Size Play wants |
|---|---|---|
| App bundle | `build/app/outputs/bundle/release/app-release.aab` | — |
| App icon | `assets/flow-math-icons/A-moon-divide/play-store-icon-512.png` | 512×512 |
| Feature graphic | `play_store/feature-graphic-sakura.png` (or `-lanterns` / `-starfall`) | 1024×500 |
| Phone screenshots | take 4–8 on your phone (see below) | 2–8, portrait |

**Screenshots worth taking** (Settings → pick a pretty background first):
1. Home with the three modes
2. Flow State mid-problem with the flow meter glowing "IN FLOW"
3. Focus timer: candle style, portrait
4. Focus in landscape: the flip clock
5. Meditation breathing orb
6. Settings → Background grid showing all 15 scenes
7. Practice screen with the skill map

---

## 2. Store listing

**App name** (max 30):
```
Flow Math: Calm Focus & Math
```

**Short description** (max 80):
```
Calm math practice, a cozy focus timer and slow breathing — all offline.
```

**Full description** (max 4000):
```
Flow Math is a quiet place to sharpen your mind, get deep work done and breathe.

FLOW STATE: MATH THAT SHARPENS YOUR MIND
• Flow, Sprint (60 seconds) and a Daily challenge
• Pick your topics: adding & subtracting, times tables & division, powers, percentages, multi-step problems
• Difficulty adapts to you as you play
• Fast answers fill the flow meter. Fill it to enter flow for double XP
• Earn XP and grow your Mind level from Seedling to Galaxy
• A skill map shows your strongest and weakest topics
• Skip when stuck and see a hint; review your mistakes after each session

FOCUS: A POMODORO THAT HELPS YOU GO DEEP
• Built for homework, studying, coding and any deep work
• Timer styles: burning candle, hourglass, campfire, moon phases and minimal
• Turn your phone sideways for a big flip clock on your desk
• Deep mode hides everything but the timer
• Start with one tiny first step, the easiest way past procrastination
• Gentle "still with it?" check-ins for daydreamers
• Park distracting thoughts for later without losing focus

MEDITATION
• A big, calm breathing orb that is easy to follow
• Several breathing patterns and session lengths

MADE TO FEEL COZY
• 15 living backgrounds: sakura, storm, snowfall, autumn leaves, rainy city, sky lanterns, deep sea, meadow, starfall and more
• Buttons and colours change style with the scene, or pick your own
• Ambient sounds: rain, river, forest, birds, wind and more
• Choose from four app icons

PRIVATE BY DESIGN
• No account, no ads, no tracking
• Works fully offline. Your data never leaves your phone
• Optional, gentle reminders
```

**Category:** Education  ·  **Tags:** Math, Productivity, Meditation
**Contact email:** your email (required; it is shown publicly on the listing)
**Privacy policy URL:** see section 4

---

## 3. App content: answers for each form

| Form | Answer |
|---|---|
| **Privacy policy** | URL of the hosted `privacy-policy.html` |
| **Ads** | No, the app does not contain ads |
| **App access** | All functionality is available without special access |
| **Content rating** (IARC questionnaire) | Category: *Reference, News, or Educational*. Answer **No** to every violence / fear / sexuality / language / drugs / gambling / user-interaction / location-sharing / purchases question → rated Everyone / PEGI 3 |
| **Target audience** | **13–15, 16–17 and 18+**. Don't tick under-13 unless you want to follow the stricter Families policy |
| **Appeals to children?** | No |
| **News app** | No |
| **Data safety** | *Does your app collect or share any required user data types?* → **No**. (Everything is stored only on the device; Google does not count on-device-only data as "collected".) |
| **Government app** | No |
| **Financial features** | None |
| **Health apps** | Tick only the meditation / relaxation / stress-management option the form offers; nothing medical |

---

## 4. Privacy policy hosting

Play needs a public web link. Easiest free options:
- **GitHub Pages**: make a public repo, upload `privacy-policy.html` as `index.html`, turn on Pages.
- **Google Sites**: paste the text into a new site and publish.

First replace `YOUR_CONTACT_EMAIL` (it appears twice) with the email you want people to use.

---

## 5. Signing: your upload key ⚠️

| | |
|---|---|
| Keystore | `C:\Users\HP\flow-math-upload.jks` |
| Passwords + alias | `android\key.properties` |
| SHA-256 | `90:63:3E:56:3A:C4:19:65:13:44:FB:04:10:95:07:D2:99:4C:A1:28:B3:81:FC:27:C8:00:AC:07:BB:BA:4D:AB` |

**Back up both files now** (USB stick + private cloud folder). Every future
update must be signed with this key. Never commit them to git or share them.
When Play asks, keep **Play App Signing** on (the default): Google holds the
real signing key, and if this upload key is ever lost, Play support can reset it.

---

## 6. Building a release

```powershell
# 1. Bump the version in pubspec.yaml for every upload:
#    version: 1.0.1+2   ← the number after + must always go up
# 2. Build the bundle
flutter build appbundle --release
# → build\app\outputs\bundle\release\app-release.aab
```

This PC is low on memory. If the build fails, run `cd android; .\gradlew --stop; cd ..` and build again.

Regenerate the feature graphics any time: `flutter test tool/store_graphics_test.dart`

---

## 7. Publishing steps

1. Play Console → **Create app** → name *Flow Math*, App, Free.
2. Fill in **App content** (section 3) and **Store listing** (section 2).
3. **Testing → Closed testing** → create a track, upload the `.aab`, add testers.
   *New personal developer accounts must run a closed test with at least
   12 testers for 14 days in a row before Production unlocks.*
4. Then **Production → Create release** → upload the `.aab` → roll out.

Free apps can't be changed to paid later; paid apps can go free.
