# Baby Photobook (Baby Growth Photobook)

A privacy-first web app (Flutter web, installs on any phone from the browser: no App Store, no Play Store) that helps parents keep a small, meaningful set of baby photos instead of thousands lost in the gallery.

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
- Profile saved to Drive too (`BabyPhotobook/_App data/profile_<id>.json`, apart from the photos; old `profile.json` files are moved automatically); on a new phone, tap the cloud icon / "I already registered my baby" to restore babies and photos
- Plain-language Drive consent screen before the Google sign-in; same-name babies get separate Drive folders
- Reminder status in each baby's settings (calendar added or not; on a phone app: notifications on or blocked, and a test reminder)
- Slideshow of all photos; "Disconnect Google Drive" and "Delete all data on this device" in the start page menu
- Birth date can be set up to ten months ahead (due date)
- A Google account and a connected Google Drive are required: photos are saved in your own Drive, and every baby lives there from the start

## Using it on a phone: the web app

There is one app for everyone: a web app (PWA). On an iPhone: open the app's address in **Safari**, tap **Share > Add to Home Screen**. No App Store and no Apple Developer account needed.

Reminders go into your **Google Calendar** (baby menu > *Add reminders to Google Calendar*): the app makes its own calendar "Baby Photobook - <name>" with a notification on each photo day, so every device that has Google Calendar notifies you (browsers cannot schedule notifications without a server). A `.ics` file download remains for other calendar apps; photos are cached in the browser (IndexedDB), so Google Drive matters even more; no iCloud.

```bash
flutter build web --release --base-href /<path>/ --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

`.github/workflows/web.yml` builds and publishes it to GitHub Pages (needs a public repo or a paid plan, Pages source = GitHub Actions, repo variable `GOOGLE_WEB_CLIENT_ID`). Add the Pages address as an *Authorized JavaScript origin* on the Web OAuth client.

Product decisions: the app is web-only (no native phone app, no App Store or Play Store) and Google Drive is the only storage (no iCloud, no device-only mode). Not built: milestone cards. See the spec.

## Setup (developers)

Requirements: Flutter (stable) with web enabled.

```bash
git clone git@github.com:claudexpro1/baby-growth-photobook.git
cd baby-growth-photobook
flutter pub get
flutter test          # unit + widget tests
flutter run -d chrome # run in the browser
flutter build web     # output in build/web/
```

### Google Drive setup (needed once, by the app owner)

Drive sign-in only works after a Google Cloud OAuth setup. Without it the app still works, but choosing Drive shows "could not connect".

1. In [Google Cloud Console](https://console.cloud.google.com), create a project and enable the **Google Drive API**.
2. Also enable the **Google Calendar API**. Configure the OAuth consent screen (External). Add only the scopes `.../auth/drive.file` and `.../auth/calendar.app.created` (the app can make its own calendar and the events in it; it cannot read your other calendars). Add your privacy policy link.
3. Create one OAuth client of type **Web application**, with the authorized JavaScript origin of the site (for example `https://claudexpro1.github.io`).
4. Build with the ids:

```bash
flutter run -d chrome --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

While the consent screen is in "Testing", add your testers' Google accounts as test users.

## Usage

1. Open the app, tap **Start with your baby**, and follow four short steps (about you, where photos live, how often, reminders).
2. When the reminder comes (or any time), open the baby and tap **Take photo**.
3. Find your photos any time: the baby page shows **Google Drive › BabyPhotobook › name** with an **Open in Drive** button.
4. Menu (top right): share a PDF photobook, get a share link, restore photos from Drive, settings.

## Changelog

- 2026-10-28: Safety limits in the schedule: ages (a step start, the finish line) up to 18 years, a photo every N up to one year, at most 8 steps; the + buttons stop at the limit, a unit change keeps the value inside the new limit, and the reminder planner has a hard loop stop
- 2026-10-27: Fewer "Reconnect to Google Drive" banners: when Google's one-hour sign-in has lapsed, it is renewed inside the tap that opens a baby or starts a photo (Google only allows renewing from a tap)
- 2026-10-27: One photo per day is now kept everywhere: restoring from Drive loads only one photo per day, and a new photo replaces the Drive file of the same day (before, a phone that did not know the Drive photos could create a second file for one day)
- 2026-10-27: Sync result stays on the Drive card ("Last sync: ...") and a failed download now says why, instead of "waiting to upload"
- 2026-10-27: Fixed photos missing after reconnecting: "Sync now" now also downloads photos that are in Drive but not on the phone (it used to only upload); photos in a second Drive folder with the same name are found too; the sync message says how many photos Drive has and warns about files the app cannot read; "I already registered my baby" also fills in photos for babies already on the phone
- 2026-10-27: Welcome screen on a phone: "Step 1: Add it to your phone" card above "Start with your baby" (skippable); the install sheet says which phone and browser it detected
- 2026-10-27: Install on phone: the app now recognises the phone and browser (Safari or Chrome on iPhone, Chrome/Samsung/Firefox on Android, in-app browsers, computers) and shows only the matching steps with a short looping animation; one-tap "Install now" where the browser offers it; the welcome screen has a clear "Add to your phone's home screen" button
- 2026-10-27: Fixed desktop scrolling: the mouse wheel now scrolls the page from anywhere in the window, not only over the centred white column
- 2026-10-26: Install instructions for iPhone (Safari: Share > Add to Home Screen) and Android (Chrome: menu > Install app): an "Install on your phone" link on the welcome screen, a one-time dismissible banner on the home screen, and a menu entry; hidden once the app runs from the home-screen icon
- 2026-10-26: Simplified to web + Google Drive only: removed the leftover device-only/iCloud storage modes (every baby is stored in Drive), the unused native notification and file-storage code and their packages; docs updated
- 2026-10-16: First-time flow: a gentle starting schedule (weekly, then monthly from 6 months) is pre-filled, each onboarding step says "Step n of 4", and after Finish you land on your baby's page where the next steps (Drive, Calendar reminders, first photo) are waiting
- 2026-10-16: Baby page: new "Backup and reminders" card with one short line each for Google Drive and Reminders that open in place (replaces the big Drive box); a step that is not done yet (connect Drive, reconnect, add reminders to Google Calendar) shows open with its button and a "One step left" note; reminders on/off and time can be changed right there; a gear next to the three dots opens Settings
- 2026-10-16: Fixed Google's sign-in window flashing open on its own after login: only a tap you make can open it now; background uploads that need a new sign-in show a "Reconnect" button instead
- 2026-10-16: Drive folders now say "do not edit or delete" in their names (`BabyPhotobook (app folder - do not edit or delete)`, `_App data (do not delete)`) and in their Drive description; folders made earlier are renamed in place on first use (same folder, nothing moved); the app also explains it where the folder is shown
- 2026-10-16: A photo file name with an impossible date (like `00002_2026-13-45.jpg`) is no longer taken as one of ours; tests now cover extra files in the Drive folder
- 2026-10-16: Baby page: the birth line ("Our story begins: born … (a Monday)") is shown once in the header; the duplicate card in the timeline is gone, which saves space on phones
- 2026-10-15: Layout audit at 13 window sizes (phones, tablets, laptops, landscape): fixed the landing page alignment on narrow windows, long baby names on the home cards, and the photo buttons on very narrow phones; a test now checks every main screen at all those sizes
- 2026-10-15: Timelapse video: "Make timelapse video" turns all photos into one MP4/WebM in the browser (speed, optional age on each photo) and downloads it; nothing leaves the device
- 2026-10-15: In-app camera with a ghost overlay: the last (or first) photo shows see-through over the live view so every photo lines up; falls back to the camera app. Also fixed the alignment of the "Private by design" cards
- 2026-10-15: Google Drive is now required: onboarding no longer offers "only in this app", and the start screens say you need a Google account
- 2026-10-15: Removed "Disconnect Google Drive" (it also cut Calendar off); Log out replaces it. The Delete-everything dialog now says it deletes the app's Google Calendars too
- 2026-10-15: Google's sign-in window now opens straight away inside the tap (no waiting first), and a browser-blocked window is explained ("allow pop-ups for this site")
- 2026-10-15: Fix: the calendar-list check could make Google answer "401 Invalid Credentials" and the app wrongly said the sign-in had expired; it is now optional, and a 401 names the request Google refused
- 2026-10-15: Desktop polish: Settings as section cards, onboarding as a centred card, photo viewer with arrow buttons and arrow/Esc keys; Save turns into a filled button once there are unsaved changes
- 2026-10-15: Desktop web design: top bar with breadcrumb, grid of baby cards, two-pane baby page (side panel with actions, timeline on the right), centred forms, and a landing page with hero, how it works and privacy; phone layout unchanged
- 2026-10-15: Tapping Check now / Update calendar first asks Google whether the saved sign-in still works and renews it inside the tap; if renewal fails the message says why
- 2026-10-14: Log out (menu on the main page): signs out of Google and clears this device's copy; Drive photos and Calendar reminders stay, and "I already registered my baby" brings everything back. Blocked while photos exist only on this device or are not uploaded yet
- 2026-10-14: An expired or refused Google sign-in token (401) is now renewed automatically and the request retried once, for Drive and Calendar, instead of asking for a second tap
- 2026-10-14: Settings: with unsaved edits the calendar box offers "Save and update calendar" (saves first, then updates Google Calendar). The box also says how far ahead the calendar is filled ("Reminders are in Calendar until ...")
- 2026-10-14: Saving Settings now updates the baby's Google Calendar right away (a schedule change used to leave the calendar on the old plan); the calendar box asks you to Save first when there are unsaved edits
- 2026-10-14: A calendar deleted by hand in Google Calendar is now detected (the app checks your calendar list, not only the calendar itself), so it shows "Calendar missing" and "Fix it" recreates it
- 2026-10-14: On wide screens the Drive consent and share-link sheets open as a centred dialog instead of a phone-style bottom sheet
- 2026-10-14: Timeline shows an "Our story begins" birth card and milestone cards (1 week, 1 month, 100 days, 3 months ... each birthday)
- 2026-10-14: Everything entered at registration (name, colours, birth date and time, place of birth) can be changed in Settings; a new name renames the Drive folder and the Google Calendar, a new birth date asks first and moves the photo days
- 2026-10-14: Schedule settings show real dates (per step, next photo days, finish-line day); baby page shows "born ... · N days old"; friendlier empty-photo avatar; "Bring back babies from Google Drive" moved to the menu; orange favicon with cache-busting
- 2026-10-14: Google Calendar status: each baby card and the Settings box show whether the calendar really exists (green "Calendar ✓" with reminder count and next reminder, red "Calendar missing" with a "Fix it" button, amber "Tap to check"); "Update calendar" always answers and reads the calendar back before saying Done
- 2026-10-14: Every Google Calendar reminder now carries a link that opens the app (in the event description and as the event source); existing events get it the next time the calendar is updated
- 2026-10-14: Finish line is now just one row (age with - / + and a unit dropdown); years added to the dropdown (saved as months)
- 2026-10-14: Finish line in the schedule settings (stop at an age, with one last photo that day); the photo-day calendar shows which days already have a photo and which are photo days; orange theme for the neutral colour (girl pink and boy blue stay), light and dark mode; Google Calendar errors now say what is actually wrong; start screen adapts to short windows
- 2026-10-13: New start screen look (warm background with baby doodles, big headline, pill buttons, DM Sans font)
- 2026-10-13: Drive consent screen before sign-in; start page explains the app and says "I already registered my baby"; profile moved to `_App data` folder (auto-migration) and same-name babies get separate folders; reminder status per baby; slideshow; Disconnect Drive and Delete all data; birth date up to ten months ahead
- 2026-10-11: Reminders are written straight into the user's own Google Calendar (own calendar per baby, popup on each photo day, kept up to date); scope calendar.app.created
- 2026-10-11: Dropped the separate Android/iOS app projects: the web app is the one app for every phone and laptop (the Dart code is unchanged; native projects can be regenerated with `flutter create` if ever needed)
- 2026-10-11: Whole profile is saved to Drive (`profile.json`) and can be restored on a new phone or browser
- 2026-10-11: Web app (installs on iPhone from Safari): storage layer works in the browser (IndexedDB), reminders as Calendar file, app icons, Pages build workflow
- 2026-10-11: Screen previews in docs/screenshots (generated by test/screenshots_test.dart)
- 2026-10-11: Fixes after internal code review: safer sync (no duplicate folders, retake race), share link switched off when a baby is removed, Drive bin instead of erase, Greek/Unicode names in PDF, Android auto-backup off
- 2026-10-11: First version: reminders, camera/gallery capture and numbering, timeline and viewer, Google Drive sync, PDF photobook and share link, review documents
- 2026-10-11: Baby profiles (several babies), onboarding with storage choice, schedule builder and reminder settings
- 2026-10-10: Project created with the design plan; schedule engine
