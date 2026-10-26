# Baby Photobooth — Plan

> **Superseded 2026-10-26:** the product is web-only with Google Drive as the only storage (no native apps, no stores, no iCloud). This document describes the earlier native-app plan and is kept for history only. See README.md.

## Context
Phone galleries hold thousands of photos and the baby's growth gets lost. This app asks the parent for one photo on a schedule that thins out over time (daily, then weekly, then monthly). It files each photo by number and date into the parent's own cloud storage and turns the set into a timeline/story inside the app. Hard requirement: **privacy-first**. There is no backend and no server of ours. Everything runs on the phone, and cloud storage is the user's own Drive or iCloud.

## Decisions (from Q&A)
- Platform: native cross-platform, **Flutter** (iOS + Android). Chosen because reliable local reminders with no server need a real app on iOS.
- Storage: **cloud-first**. The app asks the user to connect storage **immediately during onboarding**, before the first photo.
  - Android: Google Drive.
  - iPhone: Google Drive **or** iCloud Drive.
  - Photos go straight to the user's folder. The phone keeps only a small cache (thumbnails and pending uploads) so the timeline is fast and works offline.
  - If the user declines to connect: a clear message explains that photos will then live **only inside the app on this phone** and can be lost if the phone is lost, reset or the app is deleted. The user must confirm ("Keep photos in the app only"), and the Settings screen keeps a "Connect Drive/iCloud" prompt and can migrate the existing photos later.
- Sharing: the timeline lives in the app. No server of ours. Two ways to share:
  - Exports (video, PDF) plus the native share sheet.
  - **Optional Drive share link in a separate folder**: the app copies the chosen photos and/or an exported PDF photobook or video into `BabyPhotobooth/<Baby>/Shared/` and creates an "anyone with the link" permission through the Drive API (allowed under `drive.file`, since the app created those files). The link goes to the user to send to anyone. Sharing is off by default and always the user's explicit action, and it can be revoked in the app.
  - Caveat: Drive no longer renders HTML pages in the browser, so the link points to a **folder of curated copies** (a Drive gallery with slideshow) or to the **PDF/video** (both preview in the browser). A styled web "story page" would need hosting, which is out of scope.
  - iCloud: apps cannot create public iCloud links, so on iPhone the app opens the system share sheet for the Shared folder and the user creates the iCloud link there.
- Scope v1: **multiple babies/siblings**, each with its own profile, schedule and folder.
- Filenames: `NNNNN_YYYY-MM-DD.jpg` (5-digit zero padding), e.g. `00001_2026-10-10.jpg`. Folder per baby: `BabyPhotobooth/<BabyName>/`.

## Assumptions (questions left unanswered, easy to change)
- Export options: video timelapse, PDF photobook/poster, native share sheet, plus the optional Drive share folder above.
- Baby profile uses gender/name/birth date+time/place for: soft theme per baby (with a neutral option), age labels on photos ("3 weeks, 2 days"), a birth-story first card, and milestone cards (1 month, 100 days, 1 year).

## Core features
1. **Onboarding / baby profile**: gender, name, birth date, time, place, optional weight/length, then **connect Drive/iCloud** (or accept the in-app-only warning), then set schedule and reminders. Add siblings later.
2. **Schedule builder**: fully **user-chosen**, with no imposed defaults. Ordered phases per baby, where the user sets each phase's start (age) and frequency (e.g. daily, every N days, weekly, monthly). Example only: "month 1 daily → months 2–6 weekly → then monthly". The user can edit it year by year, and the last phase continues indefinitely. The **only hard limit is max one photo per day**, so the finest frequency is daily. Offer optional one-tap presets, but never force one.
3. **Reminders**: **set entirely by the user**. Local notifications, per baby, with an on/off switch, a chosen time of day and a snooze, and they can be turned off completely. Only the next ~50 are scheduled, and they are topped up on every app open and background refresh. This works around iOS's 64 pending-notification limit.
4. **Capture**: in-app camera with an optional ghost overlay of the previous photo for consistent framing. Gallery picker as a fallback, with the date set manually for missed days.
5. **Filing**: assign the next number and the date, then upload to the cloud folder (or save in-app if the user chose that). If offline, the photo is held in a pending queue and uploaded when the connection returns.
6. **Timeline / story view**: the main screen, a scrapbook/photobooth style. A card per photo with the age label, milestone cards, a month grid, a play-through slideshow, and a "missed slot" indicator that doesn't shame.
7. **Export/share**: video, PDF, share sheet, and the Drive `Shared/` folder link (manage and revoke).
8. **Restore**: reinstalling or switching phones re-reads the Drive/iCloud folder and rebuilds the timeline (parse the filenames, plus a small `profile.json` stored next to the photos).

## Architecture
- Flutter + Dart. State: Riverpod. Local DB: drift (SQLite) for babies, phases, photos and the upload queue.
- Notifications: `flutter_local_notifications` + `timezone`. Android needs the exact-alarm permission. iOS uses calendar/one-shot triggers.
- Camera: `camera`. Gallery: `image_picker`.
- Google Drive: `google_sign_in` + `googleapis` with the **`drive.file`** scope only (non-sensitive, so no heavy Google verification, and the app sees only files it created).
- iCloud (iOS): iCloud Drive container via a plugin such as `icloud_storage`, with a thin `CloudStore` interface so Drive, iCloud and local are interchangeable.
- Video/PDF: `ffmpeg_kit` (or a lighter native encoder) and the `pdf` package.
- Folder layout:
  - `lib/domain/` — schedule engine (pure Dart, heavily unit-tested)
  - `lib/data/` — drift DB, `CloudStore` + Drive/iCloud/Local implementations, upload queue
  - `lib/features/` — onboarding, schedule, capture, timeline, export, settings
  - `lib/notifications/`

## Milestones
1. Scaffold project, README, repo, LightBacklog project.
2. Domain: schedule engine plus tests (next-due-date calculation across phases).
3. Baby profile + local DB + local photo storage.
4. Reminders.
5. Capture + filing + naming.
6. Timeline UI.
7. Google Drive sync, then iCloud sync, then restore.
8. Export (PDF, video) and share.
9. Polish: themes, milestones, empty states, accessibility, localization (EN first).

## Project setup (when execution starts)
- Create `~/projects/baby-photobooth/` and `git init`. Remote: `git@github.com:claudexpro1/baby-photobooth.git`, SSH only.
- `README.md` with overview, setup, usage, and a changelog (newest first).
- Create the LightBacklog project "Baby Photobooth" with the description ending "Directory: `/home/claude/projects/baby-photobooth`". Search before creating items, use stable `external_ref`s, and add one item per milestone.
- Commit and push regularly.

## Risks / things you need to provide
- This Linux VPS cannot build or run the iOS app. iOS builds need a Mac or cloud CI (e.g. Codemagic). Android builds can be verified here.
- Store accounts: Apple Developer (US$99/yr, also required for iCloud entitlement), Google Play (one-time US$25). A Google Cloud OAuth client is needed for Drive.
- Android battery optimization can delay reminders on some phones. Add an in-app hint.

## Verification
- `flutter test`: schedule engine (phase transitions, indefinite last phase, edits mid-year), filename numbering, rolling notification window.
- `flutter analyze` clean.
- Android emulator: onboarding, schedule, a reminder fires, capture files `00001_YYYY-MM-DD.jpg`, offline queue then upload to a test Drive account, reinstall then restore.
- iOS: on a real device or CI via TestFlight (iCloud and notifications cannot be tested in a simulator).
