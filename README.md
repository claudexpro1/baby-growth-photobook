# Baby Photobook (Baby Growth Photobook)

A privacy-first mobile app (Flutter, Android now, iPhone build pending) that helps parents keep a small, meaningful set of baby photos instead of thousands lost in the gallery.

The parent chooses how often to take a photo (for example daily in month 1, weekly to month 6, then monthly). The app reminds them, files each photo as `NNNNN_YYYY-MM-DD.jpg` (e.g. `00001_2026-10-10.jpg`) in their own Google Drive folder `BabyPhotobook/<Baby>/`, and builds a timeline inside the app. There is **no server of ours**: no account, no analytics, no ads.

Documents for review: [docs/SPEC.md](docs/SPEC.md) (product + UX), [docs/COMPLIANCE.md](docs/COMPLIANCE.md), [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) (draft), [docs/STORE_LISTING.md](docs/STORE_LISTING.md), [docs/PLAN.md](docs/PLAN.md) (technical plan).

## What works in this version

- Several babies, each with its own colours, schedule, reminders and Drive folder
- Schedule you define yourself (phases: start age + every N days/weeks/months, max one photo a day)
- Local reminders at a time you choose (can be off)
- Camera or gallery capture (gallery asks which day), one photo per day, retake replaces
- Google Drive: connect during setup, automatic upload, retry when offline, "Open in Drive" button
- Timeline grouped by age, full-screen viewer, share and delete
- PDF photobook, plus an optional Drive "Shared" folder link you can stop at any time
- Photos kept only in the app if you decline Drive (with a clear warning)

Not yet: iCloud (iPhone), restoring a whole profile on a new phone, milestone/birth-story cards, slideshow. See the spec.

## Setup (developers)

Requirements: Flutter (stable), JDK 17, Android SDK. iPhone builds need a Mac.

```bash
git clone git@github.com:claudexpro1/baby-growth-photobook.git
cd baby-growth-photobook
flutter pub get
flutter test          # unit + widget tests
flutter run           # on a connected Android phone/emulator
flutter build apk     # APK in build/app/outputs/flutter-apk/
```

### Google Drive setup (needed once, by the app owner)

Drive sign-in only works after a Google Cloud OAuth setup. Without it the app still works, but choosing Drive shows "could not connect".

1. In [Google Cloud Console](https://console.cloud.google.com), create a project and enable the **Google Drive API**.
2. Configure the OAuth consent screen (External). Add the scope `.../auth/drive.file` only. Add your privacy policy link.
3. Create OAuth clients: **Android** (package `com.claudexpro1.baby_growth_photobook` + your signing SHA-1) and a **Web** client (its ID is the "server client id"). For iPhone also create an **iOS** client.
4. Build with the ids:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com \
            --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com
```

While the consent screen is in "Testing", add your testers' Google accounts as test users.

## Usage

1. Open the app, tap **Start with your baby**, and follow four short steps (about you, where photos live, how often, reminders).
2. When the reminder comes (or any time), open the baby and tap **Take photo**.
3. Find your photos any time: the baby page shows **Google Drive › BabyPhotobook › name** with an **Open in Drive** button.
4. Menu (top right): share a PDF photobook, get a share link, restore photos from Drive, settings.

## Changelog

- 2026-10-11: First version: reminders, camera/gallery capture and numbering, timeline and viewer, Google Drive sync, PDF photobook and share link, review documents
- 2026-10-11: Baby profiles (several babies), onboarding with storage choice, schedule builder and reminder settings
- 2026-10-10: Project created with the design plan; schedule engine
