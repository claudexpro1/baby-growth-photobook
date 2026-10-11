# Baby Growth Photobook - Product Spec (v1 draft for review)

Status: draft for owner review, last checked against the code on 2026-10-11. "Built" means it exists in the code today: profiles, 4-step onboarding with Google Drive sign-in, schedule builder, home screen, baby page (take photo / from gallery, timeline, photo viewer), settings, local reminders, Google Drive upload / delete / restore of missing photos, PDF photobook and Drive share link. Everything marked "planned" or "not built" does not exist yet. See [PLAN.md](PLAN.md) for the technical plan.

## 1. Goals

- Help parents keep a small, meaningful set of baby photos instead of thousands lost in the gallery.
- Make it easy to remember: a gentle reminder on a schedule the parent chose.
- Keep the photos in the parent's own storage (their Google Drive today; iCloud Drive is planned, not built), named so they stay useful without the app.
- Be private by design: no server of ours, no account with us, no analytics, no ads.

Non-goals for v1: social features, a web viewer, AI features, editing tools, sharing between two parents' accounts inside the app.

## 2. Personas

| Persona | Needs |
|---|---|
| New parent (main user) | Simple, calm, one-handed use, often tired. Wants a nudge, not a chore. |
| Second parent / grandparent (viewer) | Wants to see the photos. Receives a PDF or a Drive link. Does not install the app. |
| Parent of several children | Separate profile, schedule and folder per child. |
| Privacy-conscious parent | Wants to know exactly where photos go and be able to delete everything. |

## 3. User stories

1. As a parent, I add my baby and choose how often to take photos as they grow, so it is not a daily burden forever.
2. As a parent, I get a reminder at a time I picked, and I can turn reminders off.
3. As a parent, I take a photo and it is filed in my own Drive (iCloud is planned) with a clear name, without extra steps.
4. As a parent, I can browse a timeline of my baby growing, with age labels like "3 weeks, 2 days".
5. As a parent, I can add a photo for a day I missed, with the right date.
6. As a parent, I can export a PDF photobook and share it with family.
7. As a parent, if I get a new phone, I reconnect and my timeline comes back. (Built: the profile is saved to Drive as `profile.json`; on a new phone or browser, tap the cloud icon on the home screen and the babies and photos come back. Not tested against a real Google account yet.)
8. As a parent, I can decline cloud storage and still use the app, understanding the risk.
9. As a parent, I can add a second child later.
10. As a parent, I can delete everything the app holds, whenever I want. (Partly built: I can remove one baby and the photos cached on the phone, and delete single photos. There is no "delete all my data" button.)

## 4. Design principles

- **Light, calm, warm.** Soft off-white paper, gentle colours, rounded shapes. Scrapbook / photo-booth feel: photos as slightly tilted prints with a caption strip, tape corners, small hand-drawn touches. No red badges, no streak counters.
- **Large touch targets** (at least 48 dp / 44 pt) and one main action per screen.
- **Accessible contrast** (WCAG AA minimum, 4.5:1 for text), supports system font scaling, screen-reader labels on every control, never colour alone to carry meaning.
- **Dark mode** follows the system setting; same warm feel with deep brown-grey instead of pure black. Built as a basic dark theme only; no polish pass or contrast check yet.
- **Soft theme per baby** (girl / boy / neutral palette; onboarding offers Girl / Boy / Skip, Skip gets neutral). Built.
- Not built yet: the tilted prints, tape corners and hand-drawn touches. The app uses plain rounded cards and a photo grid. Accessibility has not been audited (large touch targets are used on the main buttons; screen-reader labels and contrast are not checked).
- **Copy tone:** plain, kind, never guilt. Say "Missed a day? That's fine. Add it when you like." Never "You failed" or "overdue". No jargon (say "your Google Drive", not "OAuth"). Short sentences. English first.

## 5. Screens

### 5.1 Onboarding (built, 4 steps)
1. **About your baby:** name, girl / boy / prefer not to say, birth date, birth time, birth place (optional).
2. **Where should photos live?** Three choices: Google Drive, iCloud Drive (iPhone only), or "Only in this app". Choosing app-only shows a confirm dialog: "Keep photos only in the app? They live only on this phone. If the phone is lost, reset, or the app is deleted, the photos are gone." Buttons: "Go back" / "Keep in the app only". Choosing Google Drive signs in **immediately** (Google's own consent screen, `drive.file` scope only); if it fails the parent sees a message and can try again or pick app-only. **iCloud Drive is shown greyed out as "Coming soon" and is not built.**
3. **Photo schedule:** the parent builds phases (start age + how often). No forced defaults; one-tap presets are optional. Daily is the most often allowed.
4. **Reminders:** on/off (the switch starts **on**), time of day (default 18:00), changeable any time in Settings. The phone's notification permission is asked when the parent taps Finish with reminders on; if refused, a note says notifications are off and the app works without them.

### 5.2 Home (built)
- One card per baby: latest photo as thumbnail (a placeholder icon before the first photo), name, current age, and either a "Today's photo" chip or "Next photo: <date>".
- "Only on this phone" warning (in red) for app-only babies; "N waiting to upload" for Drive babies with photos not yet uploaded.
- Tapping a card opens the baby page. "Add a baby" button. Friendly empty state ("Start with your baby") when there are no babies.

### 5.3 Baby page and timeline (built, simple version)
- Top: current age and a "photo day" card ("It's photo day!", "Today's photo is saved", or the next photo date) with **Take photo** (camera) and **From gallery** buttons. If today already has a photo, the camera button reads **Retake**.
- "Where are my photos" card (see 5.7).
- Timeline: a 3-column grid of photos grouped under age sections ("First month", "Month 2", "Year 2" ...), each photo with its age label ("3 weeks, 2 days") on it. Photos waiting to upload show a small upload-cloud icon (Drive babies only).
- Tap a photo for the full-screen viewer: swipe between photos, pinch to zoom, age + number + date, **Share** and **Delete** (see 5.6).
- Menu: Share photobook (PDF), Get a share link and Restore photos from Drive (Drive babies only), Settings.
- **Not built:** milestone cards (1 month, 100 days, 1 year), the "birth story" card, month grid view, slideshow, soft empty frames for missed slots (missed days are simply not shown), photo number on the grid.

### 5.4 Capture (built, simple version)
- **Take photo** opens the phone's own camera app (through the image picker). Date is today. There is no in-app camera and **no ghost overlay (not built)**.
- **From gallery** opens the system photo picker, then asks "Which day is this photo for?" (defaults to the photo's date, cannot be before birth or in the future), so a missed day can be added.
- There is no Retake/Keep step after shooting: the photo is filed straight away and "Photo saved" is shown.
- One photo per day maximum. If that day already has a photo, the app asks "Replace the photo for this day?" (Keep old / Replace). Replacing keeps the same number and file name, overwrites the phone copy and re-uploads under the same name; no hidden duplicate is kept.
- If the camera or photos cannot be opened, a message points to the phone's app permissions.

### 5.5 Settings (built for one baby; global settings not built)
- Per baby (menu > Settings): name, colours (Girl / Boy / Neutral), schedule editor, reminders (on/off, time of day), and **Remove <name>**. Removing first switches off any share link (if that fails nothing is removed), refuses while photos are still waiting to upload (asks the parent to Sync first), and then deletes the profile and the photos cached on the phone; it does **not** delete photos in Drive (the dialog says so). App-only photos cannot be recovered after removal. Birth date, birth time and birth place cannot be edited after onboarding.
- Storage: there is no storage screen. An app-only baby shows a "Your photos are only on this phone" card on the baby page with a **Connect Google Drive** button; connecting signs in and uploads the existing photos.
- Not built: snooze, "Disconnect Drive", "Delete all data from this phone", theme switch (the app follows the phone's light/dark setting), privacy policy link, app version, Android battery hint, "Reminders are blocked" note.

### 5.6 Export and share (built)
- **PDF photobook** (menu > Share photobook (PDF)): builds a PDF on the phone with a cover (name, birth date, place, photo count) and 6 photos per page with age and date, then opens the system share sheet. All photos are included; there is no date range or layout choice.
- **Share a single photo:** the share button in the full-screen viewer sends that photo through the share sheet.
- **Share link (Drive babies only, off until the parent taps it):** "Get a share link" builds the same PDF, puts it in `BabyPhotobook/<Baby>/Shared/` in the parent's Drive and gives that **folder** an "anyone with the link can view" permission. The sheet explains that anyone with the link can view it and that the photobook contains all the photos plus the baby's name, birth date and place (the original photo folder stays private). The sheet shows "Sharing is currently ON" with a Stop sharing button whenever a link exists. Buttons: Send link, Copy, **Stop sharing** (removes the public permission). The link points to a folder containing the PDF, because Drive does not display HTML pages. The shared PDF is a snapshot from the moment the link was created; creating the link again uploads a fresh PDF. Stopping the share removes public access but leaves the PDF in the Shared folder.
- iPhone/iCloud sharing is not built (iCloud is not built).
- Delete in the viewer: asks "Delete this photo?" and removes it from the phone and, for Drive babies, from the Drive folder. If the phone is offline at that moment the Drive copy stays, and a later "Restore photos from Drive" would bring it back.
- Video timelapse: later (see 13).

### 5.7 Finding your Drive folder and photos (built)
- The baby page has an always-visible **"Where are my photos"** card. For Drive babies it shows "Google Drive > BabyPhotobook > <name>", a line such as "12 photos safe in your Drive" or "2 photos waiting to upload", an **Open in Drive** button and a **Sync** button (uploads anything waiting). The folder is created when the first upload happens; before that Open in Drive is greyed out. The page also quietly tries to upload waiting photos each time it opens.
- Folder layout, in the parent's own Drive:

```
My Drive/
  BabyPhotobook/
    Mia/
      00001_2026-10-10.jpg
      00002_2026-10-11.jpg
      Shared/        (only if the parent shares; holds the PDF)
```
- `profile.json` is saved in each baby's Drive folder on every sync and on every profile change; if you change the profile on two devices, the last one to sync wins.
- With the narrow `drive.file` permission the app can only see files it created. Photos the parent adds to the folder by hand in Drive are **not visible to the app** (not restored, not shown). If the parent deletes the folder in Drive the app creates a new one on the next upload; if it is only moved or renamed the app keeps using it by id. The app does not yet explain this on screen.

## 6. Data model

| Entity | Fields |
|---|---|
| Baby | id, name, gender (girl/boy/neutral), birth date+time, birth place, storage mode (googleDrive / iCloud / appOnly; iCloud is in the code but not usable), Drive folder id, Drive Shared folder id, reminder settings, phases |
| Phase | start age (number + day/week/month), frequency (every N day/week/month) |
| ReminderSettings | enabled, hour, minute (snooze planned) |
| Photo (built, not a stored record) | Derived from the file name `NNNNN_YYYY-MM-DD.jpg` in the baby's photo folder on the phone: number, date, file. "Uploaded" is a list of file names in a hidden `.synced.json` next to the photos. |

Storage as built: all baby profiles are one JSON file, `babies.json`, in the app's private support folder on the phone (written via a temp file so a crash cannot corrupt it). Photos are in `photos/<baby id>/` in the same private folder. This relies on the phone's app sandbox; the app adds no encryption of its own. There is no database (drift/SQLite was dropped), no thumbnails cache and no upload-queue table: photos not listed in `.synced.json` are simply uploaded on the next sync. `profile.json` is also saved in the baby's Drive folder (since 2026-10-11); the browser build keeps the same files in IndexedDB instead of a folder.

## 7. File naming and numbering

- Pattern: `NNNNN_YYYY-MM-DD.jpg`, number zero-padded to 5 digits, e.g. `00001_2026-10-10.jpg`.
- One photo per day maximum. A second photo for the same day replaces the first and keeps its number.
- Number = highest existing number + 1 at filing time; existing photos are never renumbered (if a missed day is added later it gets the next number but keeps its real date; the timeline and the PDF are sorted by date, then number). If the newest photo is deleted its number can be used again.
- Date = the day the photo is for: today for the camera, the day the parent picks for the gallery.
- Capacity: 99,999 photos per baby with 5 digits, far more than a schedule that thins out can produce.
- Folder per baby: `BabyPhotobook/<Baby name>/`, with an optional `Shared/` inside. The name is used as typed; characters Drive dislikes are not cleaned, and two babies with the same name would share one Drive folder. (Not handled yet.) Renaming a baby in Settings does not rename the Drive folder.

## 8. Schedule rules (built, in `lib/domain/schedule.dart`)

- A schedule is an ordered list of phases chosen by the parent. Each phase starts at an age and repeats at a frequency until the next phase starts. The last phase continues forever.
- Frequency is "every N days / weeks / months". The smallest is every 1 day, so **at most one photo is ever due per day**.
- Phase starts must strictly increase; the first phase starts at birth.
- Month steps are counted from the phase start and do not drift. If a month is too short, the last day of that month is used (a photo due on the 31st is due on 30 April, then back to 31 May).

Example: baby born 2026-01-31.

| Phase | Starts | Frequency | Photos due |
|---|---|---|---|
| 1 | birth | every 1 day | 31 Jan, 1 Feb, 2 Feb ... up to 27 Feb |
| 2 | 1 month (28 Feb) | every 1 week | 28 Feb, 7 Mar, 14 Mar ... |
| 3 | 6 months | every 1 month | monthly on the 31st, shortened in short months |

Rules for the parent's edits: changing a schedule only affects future dates; past photos are never deleted or renamed. Missed days are not "owed" and do not pile up.

## 9. Reminders

Built:
- Local notifications only, per baby, at the chosen time of day ("Time for <name>'s photo" with the age as text). Optional; can be turned off per baby in Settings. Nothing leaves the phone.
- **Rolling window:** at most 30 upcoming reminders per baby (fewer if there are 3 or more babies, so the total stays about 60). Days that already have a photo are skipped. The whole window is re-planned when the app opens, when a photo is added or deleted, and when a baby is added, changed or removed. If the parent does not open the app for a long time on a daily schedule, reminders can run out. The app does not yet show a note about this.
- **Inexact scheduling:** reminders use Android's inexact mode, so they can arrive a little after the chosen time. The app does **not** ask for the exact-alarm permission and does not declare it.
- **Permission:** the notification permission is requested when the parent taps Finish in onboarding with reminders on, and when reminders are switched on in Settings. If refused, the app still works and reminders do nothing.
- Android: `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` are declared and the notification plugin's boot receiver is registered, so scheduled reminders are restored after a restart.

Not built:
- Tapping a notification only opens the app; it does not jump to the baby.
- Snooze ("Remind me in 1 hour").
- Battery-optimisation hint on Android, and a "Reminders are blocked by your phone" note with a button to system settings.
- Background refresh to top up the window without opening the app.
- iOS: the 64-pending-notification limit still applies; 30 per baby is the app's own cap (there is no iOS build tested yet).

## 10. Offline behaviour

- Camera, gallery, timeline and capture work with no connection (the timeline reads the full photos saved on the phone; there are no separate thumbnails).
- New photos are saved on the phone first, then uploaded right away if possible. If not, they show a small upload icon and "N waiting to upload" and stay on the phone. Waiting photos are retried when the baby page opens and when the parent taps Sync.
- There is no back-off schedule and no background upload while the app is closed. The phone copy is never removed because of an upload failure.
- A photo deleted while offline is removed from the phone only; the Drive copy stays.
- Share links, Open in Drive and Restore need a connection.

## 11. Restore flow (partly built)

Built: menu > **Restore photos from Drive** (Drive babies only) looks in `BabyPhotobook/<Baby>/`, and downloads every correctly named photo that is missing on the phone. It tells the parent how many were restored. It works for a baby profile that already exists in the app (for example after the phone cache was cleared).

Not built (planned): full new-phone restore.
1. Install app on the new phone, choose "I already use this app".
2. Sign in to Google.
3. App reads `BabyPhotobook/` for folders and a `profile.json`, and rebuilds babies, schedules and timeline. The profile (schedule, reminder time, settings) comes back with the photos. Reminders are scheduled again from the restored profile.
4. Parent confirms each baby found. Reminders need to be allowed again.
- Limit: app-only photos cannot be restored. Photos not created by the app are not visible with `drive.file` (see 5.7); this is a known trade-off for privacy.

## 12. Error states

| Situation | What the parent sees | Status |
|---|---|---|
| No camera / photo access | "Could not open the camera or photos. Check the app permissions in your phone settings." | Built (no button to settings) |
| Notification permission denied | Snackbar at the end of onboarding; app works without reminders | Partly built (no note in Settings) |
| Drive sign-in cancelled or failed | "We could not connect to Google Drive. Please try again, or keep photos in the app for now." Can pick app-only with the warning. | Built |
| Drive access revoked / token expired | Sync says "Google Drive is not connected" or "Could not reach Google Drive. Your photos are saved on this phone and will upload later." Photos keep saving on the phone. | Partly built (no "Reconnect" banner) |
| Drive full | Not handled specially; shows the general upload message | Not built |
| Upload failing | Upload icon, "N photo(s) waiting to upload. We will try again.", Sync button | Built (no details screen) |
| Folder deleted/moved in Drive | Deleted or binned: the app creates a new folder on the next sync. Moved/renamed: still used by id. No message. | Partly built |
| Phone storage low | Not handled | Not built |
| Export fails | PDF: no specific message. Share link: "Could not create the link. Check your connection and try again." | Partly built |

## 13. What is in v1 and what comes later

| Area | v1 | Later |
|---|---|---|
| Babies, profiles, schedule builder, reminder settings | Built | Snooze |
| Onboarding with storage choice and Drive sign-in | Built | |
| Camera (system camera) / gallery capture, filing, naming, replace | Built | Ghost overlay, in-app camera |
| Home, baby page, age-grouped timeline, full-screen viewer, share, delete | Built | Milestones, birth-story card, month grid, slideshow, empty frames |
| Google Drive upload, retry, delete, restore missing photos | Built | — (profile restore built; real-account test pending) |
| iCloud Drive sync | Not built ("Coming soon" in the app; needs Mac / CI) | |
| PDF export, share sheet, Drive Shared link | Built (PDF only, no options) | Date range / layout options, photo selection |
| Video timelapse | No | Yes |
| Dark mode | Basic theme follows the system | Polish and contrast check |
| Accessibility, more languages | Not audited; English only | Yes (English first) |
| In-app "delete all my data", "Disconnect Drive" | Not built (remove one baby only) | Yes |
| Web story page | No | Out of scope (needs hosting) |
| Photo editing, filters, cloud backup of the database | No | Maybe |

## 14. Open questions for the owner

1. Folder name and app name: the developer chose `BabyPhotobook/` and the display name "Baby Photobook" (see section 16). Confirm or change.
2. Is video timelapse really out of v1? (It is heavy and adds a large library.)
3. Should the app ever offer a one-tap default schedule, or only user-built phases with optional presets?
4. Are there languages besides English wanted for launch?
5. Free app, or paid / one-off unlock? (Affects store forms.)
6. Who is the legal publisher (company or you personally)? Needed for store accounts and privacy policy.
7. Do you want a simple support email address published in the stores?
8. Restore limit: accept that photos added by hand to the Drive folder do not appear in the app (due to the narrow Drive permission)?
9. Reminders: accept approximate (inexact) times, or ask for the Android exact-alarm permission?
10. Reminders start switched on in onboarding. Keep it that way, or start off? (See COMPLIANCE.md.)

## 15. v1 acceptance checklist

Ticked = verified in the code or the automated tests (`flutter test`). Unticked = not built, or needs a device check that has not been done.

- [x] Add, edit and remove several babies, each with own schedule, reminders and Drive folder.
- [x] Schedule builder enforces max one photo per day; unit tests cover phase changes, month ends, last phase endless.
- [ ] Reminders fire at the chosen time on Android and iOS; can be turned off; survive restart; stay under the 64 limit. (Built with inexact times and a 30-per-baby window; planner is unit tested; not yet checked on devices.)
- [ ] Capture works with camera and gallery on real devices; ghost overlay works. (Ghost overlay not built.) Files are named `NNNNN_YYYY-MM-DD.jpg` with correct numbering: [x] tested.
- [x] Photos upload to `BabyPhotobook/<Baby>/` in Google Drive using only the `drive.file` scope. (iCloud not built.) Real-device check with a production OAuth setup still to do.
- [x] Offline capture queues and uploads later without loss (tested with a fake cloud).
- [x] App-only mode shows the warning and can later connect Google Drive and upload its photos. (iCloud not built.)
- [ ] Reinstall + sign-in restores babies and timeline. (Only missing photos for an existing baby; profile restore not built.)
- [ ] PDF export, share sheet and the optional Drive link (create and revoke): built, not yet checked on devices.
- [ ] Timeline shows age labels (built), milestones and soft missed slots (not built).
- [ ] Dark mode, large font, screen reader and contrast checks pass. (Basic dark theme only.)
- [ ] "Delete all data" removes local data and revokes Drive access. (Not built.)
- [x] No analytics, ads or network calls other than Google Drive (by code review of the package list; iCloud not built).
- [ ] Privacy policy, store listings and data-safety/privacy forms are complete and match the app. (Drafts updated to match the code; placeholders and legal review remain.)
- [ ] `flutter analyze` clean, `flutter test` green, tested on a real iPhone via TestFlight and an Android device.

## 16. What I (the developer) decided without asking

These choices were made while building, to keep moving. Tell me if any should change.

- **Folder name `BabyPhotobook`** (the plan said `BabyPhotobooth`). Layout is `BabyPhotobook/<Baby name>/` and `.../Shared/`.
- **5-digit numbering** in file names (`00001_2026-10-10.jpg`).
- **One photo per day.** A second photo for the same day replaces the first (after a confirmation) and keeps its number.
- **Inexact reminders.** No exact-alarm permission; a reminder can arrive a little late. This keeps the Play Store declaration and the permission prompt away.
- **JSON storage instead of a database.** Profiles live in `babies.json`; photos are found from their file names. drift/SQLite was dropped as too heavy for this amount of data.
- **iCloud deferred.** Shown as "Coming soon"; needs a Mac / cloud CI and an Apple developer account.
- **PDF-only share link.** The Drive link opens a folder containing the PDF, because Drive does not display HTML pages.
- **App name "Baby Photobook"** as the display name on the phone and in the app bar (the project and docs still say "Baby Growth Photobook").


## Fixes made after the internal code review (2026-10-11)

These were found by an independent read-through of the code and fixed before this review:

- A retake while an upload is running can no longer be wrongly marked "safe in Drive" (the photo stays queued until its newest version is uploaded).
- Only one sync per baby runs at a time, which prevents duplicate Drive folders or duplicate files.
- A retaken photo now shows the new picture straight away.
- Photos deleted from Drive go to the Drive bin (recoverable for 30 days) instead of being erased.
- Removing a baby first switches off any public share link; it refuses while photos are still waiting to upload.
- The share sheet shows the real sharing state with a Stop sharing button, and says plainly that the whole photobook is shared.
- Saving settings or finishing a sync no longer overwrites a newer change (for example the Drive folder).
- The timeline and PDF are sorted by date.
- Android automatic cloud backup is switched off for the app.
- The PDF and its file name work with Greek and other non-Latin names (Noto Sans font bundled, SIL Open Font License).
- Safer date picker for gallery photos, clearer messages if notifications are denied, and safer handling when a sheet is closed mid-action.

Still open (known limits): iPhone Google sign-in needs the reversed client id added to the iOS settings once the Google ids exist; two babies with the same name would share one Drive folder; a photo deleted while offline stays in Drive until the next time you delete it again or remove it by hand.
