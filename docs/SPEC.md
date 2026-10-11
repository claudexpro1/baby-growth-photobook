# Baby Growth Photobook - Product Spec (v1 draft for review)

Status: draft for owner review. "Built" means it exists in the code today (profiles, onboarding with storage choice, schedule builder, reminder settings, schedule engine). Everything else is planned and not yet built. See [PLAN.md](PLAN.md) for the technical plan.

## 1. Goals

- Help parents keep a small, meaningful set of baby photos instead of thousands lost in the gallery.
- Make it easy to remember: a gentle reminder on a schedule the parent chose.
- Keep the photos in the parent's own storage (their Google Drive or iCloud Drive), named so they stay useful without the app.
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
3. As a parent, I take a photo and it is filed in my own Drive/iCloud with a clear name, without extra steps.
4. As a parent, I can browse a timeline of my baby growing, with age labels like "3 weeks, 2 days".
5. As a parent, I can add a photo for a day I missed, with the right date.
6. As a parent, I can export a PDF photobook and share it with family.
7. As a parent, if I get a new phone, I reconnect and my timeline comes back.
8. As a parent, I can decline cloud storage and still use the app, understanding the risk.
9. As a parent, I can add a second child later.
10. As a parent, I can delete everything the app holds, whenever I want.

## 4. Design principles

- **Light, calm, warm.** Soft off-white paper, gentle colours, rounded shapes. Scrapbook / photo-booth feel: photos as slightly tilted prints with a caption strip, tape corners, small hand-drawn touches. No red badges, no streak counters.
- **Large touch targets** (at least 48 dp / 44 pt) and one main action per screen.
- **Accessible contrast** (WCAG AA minimum, 4.5:1 for text), supports system font scaling, screen-reader labels on every control, never colour alone to carry meaning.
- **Dark mode** follows the system setting; same warm feel with deep brown-grey instead of pure black.
- **Soft theme per baby** (girl / boy / neutral palette; "Prefer not to say" gets neutral). Neutral is always available.
- **Copy tone:** plain, kind, never guilt. Say "Missed a day? That's fine. Add it when you like." Never "You failed" or "overdue". No jargon (say "your Google Drive", not "OAuth"). Short sentences. English first.

## 5. Screens

### 5.1 Onboarding (built, 4 steps)
1. **About your baby:** name, girl / boy / prefer not to say, birth date, birth time, birth place (optional).
2. **Where should photos live?** Three choices: Google Drive, iCloud Drive (iPhone only), or "Only in this app". Choosing app-only shows a confirm dialog: "Keep photos only in the app? They live only on this phone. If the phone is lost, reset, or the app is deleted, the photos are gone." Buttons: "Go back" / "Keep in the app only". The actual Drive/iCloud sign-in is **not built yet**.
3. **Photo schedule:** the parent builds phases (start age + how often). No forced defaults; one-tap presets are optional. Daily is the most often allowed.
4. **Reminders:** on/off, time of day (default 18:00), changeable any time.

### 5.2 Home (partly built: baby list)
- List of babies (card per baby with name, age, next photo date). "Add another baby" button.
- Planned: tapping a baby opens the timeline. A friendly empty state when there are no babies.

### 5.3 Baby timeline (planned)
- Scrapbook scroll: one card per photo, age label, date, number.
- Milestone cards (1 month, 100 days, 1 year) and a first "birth story" card (name, date, time, place).
- Month grid view and a play-through slideshow.
- Missed slots shown as soft empty frames with "Add photo", never as errors.
- Photos not yet uploaded show a small cloud-with-clock icon.

### 5.4 Capture (planned)
- In-app camera, optional ghost overlay of the previous photo for matching framing (toggle).
- Gallery picker as fallback; the date defaults to today and can be changed for a missed day.
- After shooting: Retake / Keep. "Keep" files the photo immediately.
- Max one photo per day is a **schedule** rule (see 6). The parent may still replace the day's photo (asks to confirm; old one is kept as a hidden duplicate only until upload finishes, then replaced).

### 5.5 Settings (planned, per baby and global)
- Per baby: profile edit, schedule edit, reminders (on/off, time, snooze length), storage (shows connected account name, "Connect Drive/iCloud", "Move in-app photos to Drive/iCloud").
- Global: theme (light / dark / system), "Delete all data from this phone", "Disconnect Drive", privacy policy link, app version.
- Battery hint on Android (see 8).

### 5.6 Export and share (planned)
- **PDF photobook:** pick baby, date range, layout (grid or one per page with captions). Produces a PDF on the phone.
- **Share sheet:** send the PDF or chosen photos with the system share sheet.
- **Drive "Shared" folder (optional, off by default):** copies chosen items to `BabyPhotobook/<Baby>/Shared/` and makes an "anyone with the link" link. Always an explicit tap with a clear warning ("Anyone with this link can see these photos"). Link can be revoked in the app. On iPhone/iCloud the app opens the system share sheet instead, because apps cannot make public iCloud links.
- Video timelapse: later (see 12).

### 5.7 Finding your Drive folder and photos (planned)
- Settings > Storage shows the folder path and an "Open in Drive" button (or "Open in Files" for iCloud).
- Folder layout, in the parent's own Drive:

```
My Drive/
  BabyPhotobook/
    Mia/
      00001_2026-10-10.jpg
      00002_2026-10-11.jpg
      profile.json
      Shared/        (only if the parent shares)
```
- Important to explain in plain words: with the narrow `drive.file` permission the app can only see files it created. If the parent moves, renames or deletes the folder in Drive, or adds photos by hand, the app may not see them. The Settings screen says so.

## 6. Data model

| Entity | Fields |
|---|---|
| Baby | id, name, gender (girl/boy/neutral), birth date+time, birth place, storage mode (googleDrive / iCloud / appOnly), reminder settings, phases |
| Phase | start age (number + day/week/month), frequency (every N day/week/month) |
| ReminderSettings | enabled, hour, minute (snooze planned) |
| Photo (planned) | id, baby id, number, date, local path, thumbnail, cloud file id, upload state (pending / uploaded / failed) |
| UploadQueue (planned) | photo id, attempts, last error |

Stored on the phone in a local database (planned: SQLite via drift). `profile.json` next to the photos holds the baby profile and schedule so a restore can rebuild everything. It contains no tokens.

## 7. File naming and numbering

- Pattern: `NNNNN_YYYY-MM-DD.jpg`, number zero-padded to 5 digits, e.g. `00001_2026-10-10.jpg`.
- Number = next free number for that baby, in order of **photo date** at filing time; numbers are never reused and never renumbered (if a missed day is added later it gets the next number but its real date; the timeline sorts by date).
- Date = the date the photo is for (local date of the phone).
- Capacity: 99,999 photos per baby, far more than a schedule that thins out can produce.
- Folder per baby: `BabyPhotobook/<Baby>/`. Names are cleaned of characters Drive/iCloud dislike (`/ \ : * ? " < > |`); two babies with the same name get " (2)".

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

- Local notifications only, per baby, at the chosen time of day. Fully optional; can be turned off per baby or entirely.
- Tapping a notification opens Capture for that baby.
- Snooze (planned): "Remind me in 1 hour".
- **iOS limit:** at most 64 pending local notifications per app. The app schedules only the next ~50 across all babies and tops up every time the app opens and on background refresh. If the parent does not open the app for a long time on a daily schedule, reminders can run out; the app shows a note about this.
- **Android:** reminders at an exact time need the "exact alarm" permission (Android 12+; special access on 13+/14+). The app asks only when the parent turns reminders on, explains why, and falls back to approximate times if declined. Battery optimisation on some phones (Samsung, Xiaomi, etc.) can delay or drop reminders; Settings shows a hint and a button to the system battery page. Reminders are re-scheduled after phone restart.
- Permission denied: the app still works; Settings shows "Reminders are blocked by your phone" with a button to system settings.

## 10. Offline behaviour

- Camera, timeline (from cached thumbnails) and capture work with no connection.
- New photos are saved on the phone first, then uploaded in the background when online. They show a "waiting to upload" icon and are never discarded until confirmed uploaded.
- Retries with back-off; a failed upload can be retried by hand.
- Sharing links and Drive restore need a connection.

## 11. Restore flow (planned)

1. Install app on the new phone, choose "I already use this app".
2. Sign in to Google (or pick iCloud). 
3. App reads `BabyPhotobook/` for folders and `profile.json` files it created, parses the file names, and rebuilds babies, schedules and timeline; thumbnails are downloaded as needed.
4. Parent confirms each baby found. Reminders need to be allowed again.
- Limit: app-only photos cannot be restored. Photos not created by the app may not be visible with `drive.file` (see 5.7); this is a known trade-off for privacy.

## 12. Error states

| Situation | What the parent sees |
|---|---|
| No camera permission | "We need the camera to take photos." Button to system settings; gallery picker still works. |
| Notification permission denied | Note in Settings; app works without reminders. |
| Drive sign-in cancelled | Back to storage choice; can pick app-only with the warning. |
| Drive token expired / access revoked | Banner "Reconnect Google Drive"; photos keep saving on the phone and upload after reconnecting. |
| Drive full | "Your Google Drive is full. Photos are safe on this phone." Link to Google storage. |
| Upload failing | Waiting icon, "Try again" button, details in Settings. |
| Folder deleted/moved in Drive | "We can't find the folder." Offer to recreate and re-upload from the phone. |
| Phone storage low | Warn before capture; suggest connecting Drive. |
| Export fails | Plain message, nothing is lost, retry. |

## 13. What is in v1 and what comes later

| Area | v1 | Later |
|---|---|---|
| Babies, profiles, schedule builder, reminder settings | Yes (built) | Snooze |
| Onboarding with storage choice | Yes (built, sign-in not yet) | |
| Capture with ghost overlay, filing, naming | Yes | |
| Timeline, milestones, month grid, slideshow | Yes | Share cards |
| Google Drive sync, offline queue, restore | Yes | |
| iCloud Drive sync | Yes (needs Mac / CI) | |
| PDF export, share sheet, Drive Shared link | Yes | |
| Video timelapse | No | Yes |
| Light/dark, accessibility | Yes | More languages (English first) |
| Web story page | No | Out of scope (needs hosting) |
| Photo editing, filters, cloud backup of the database | No | Maybe |

## 14. Open questions for the owner

1. Folder name: the plan said `BabyPhotobooth/`, this brief says `BabyPhotobook/`. Which one? (This spec uses `BabyPhotobook`.) Also, final app name: "Baby Growth Photobook" or "Baby Photobooth"?
2. Is video timelapse really out of v1? (It is heavy and adds a large library.)
3. Should the app ever offer a one-tap default schedule, or only user-built phases with optional presets?
4. Are there languages besides English wanted for launch?
5. Free app, or paid / one-off unlock? (Affects store forms.)
6. Who is the legal publisher (company or you personally)? Needed for store accounts and privacy policy.
7. Do you want a simple support email address published in the stores?
8. Restore limit: accept that photos added by hand to the Drive folder may not appear (due to the narrow Drive permission)?

## 15. v1 acceptance checklist

- [ ] Add, edit and delete several babies, each with own schedule, reminders and folder.
- [ ] Schedule builder enforces max one photo per day; unit tests cover phase changes, month ends, last phase endless.
- [ ] Reminders fire at the chosen time on Android (exact alarm granted and denied) and iOS; can be turned off; survive restart; stay under the 64 limit.
- [ ] Capture works with camera and gallery; ghost overlay works; files named `NNNNN_YYYY-MM-DD.jpg` with correct numbering.
- [ ] Photos upload to `BabyPhotobook/<Baby>/` in Google Drive (and iCloud on iPhone); app uses only the `drive.file` scope.
- [ ] Offline capture queues and uploads later without loss.
- [ ] App-only mode shows the warning and can later move photos to Drive/iCloud.
- [ ] Reinstall + sign-in restores babies and timeline.
- [ ] PDF export, share sheet and the optional Drive link (create and revoke) work.
- [ ] Timeline shows age labels, milestones, soft missed slots.
- [ ] Dark mode, large font, screen reader and contrast checks pass.
- [ ] "Delete all data" removes local data and revokes Drive access.
- [ ] No analytics, ads or network calls other than Google Drive/iCloud (checked).
- [ ] Privacy policy, store listings and data-safety/privacy forms are complete and match the app.
- [ ] `flutter analyze` clean, `flutter test` green, tested on a real iPhone via TestFlight and an Android device.
