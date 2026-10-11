# Baby Growth Photobook

A privacy-first mobile app (Flutter, iOS + Android) that helps parents keep a small, meaningful set of baby photos instead of thousands lost in the gallery. The user picks a photo schedule that thins out over time (e.g. daily in month 1, weekly to month 6, then monthly). The app reminds them, files each photo as `NNNNN_YYYY-MM-DD.jpg` in their own Google Drive or iCloud folder, and builds a timeline/story inside the app. There is no backend and no server of ours.

Full design: [docs/PLAN.md](docs/PLAN.md)

## Setup

Status: early development. Profiles and onboarding work; camera, reminders and cloud sync are still to come.

Requirements (planned): Flutter SDK (stable), Android Studio or Xcode, a Google Cloud OAuth client for Drive.

```bash
git clone git@github.com:claudexpro1/baby-growth-photobook.git
cd baby-growth-photobook
flutter pub get
flutter run
```

## Usage

Planned flow: create a baby profile, connect Drive/iCloud, set the schedule and reminders, take photos when reminded, and browse the timeline.

## Changelog

- 2026-10-11: Baby profiles (several babies), onboarding with storage choice, schedule builder and reminder settings
- 2026-10-10: Project created with the design plan
