# Compliance Review (draft, not legal advice)

> **Update 2026-10-14: the app is now web-only (a PWA for every phone and laptop).** Sections below that talk about Android/iOS builds, Android permissions, alarms, TestFlight, an Apple Developer account or iCloud describe the earlier native plan and are kept for history only. What is current: the web app, Google Drive (`drive.file`), Google Calendar reminders (`calendar.app.created`), profile in `BabyPhotobook/_App data/`. See README.md and the changelog.


Status key: **Done** = in place today. **To do** = we must build/write it. **Needs owner action** = only the owner can do it (accounts, legal, forms).
Reality check (checked against the code on 2026-10-11): the app now has onboarding with Google Drive sign-in, schedule, local reminders, camera/gallery capture, Drive upload/delete/restore of missing photos, PDF export and a Drive share link. iCloud, a full profile restore, "delete all my data" and "Disconnect Drive" are not built. Items below are marked by what the code does today. A lawyer should review the privacy policy before launch.

## 1. Where data goes (the core privacy argument)

- Data stays on the parent's phone and in the parent's own Google Drive / iCloud Drive.
- The developer runs no server and receives no data, no analytics, no crash reports, no ads.
- The only network traffic is to Google (sign-in and Drive API), initiated by the parent. iCloud is not built, so there is no Apple traffic.
- The code contains no analytics, ads, crash-reporting or backend (see the package list in section 10).

## 2. GDPR (EU/UK)

| Item | Status | Notes |
|---|---|---|
| Role: the parent is the controller of their own data (household use); developer does not process or receive data | Done (by design) | Say it plainly in the policy. If we ever add any server or telemetry, this changes completely. |
| Data minimisation: only name, birth date/time, optional birth place, photos | Done | Birth place is marked optional in the UI; birth time is asked but has a default (the current time), so it is not clearly optional. Consider making that clearer. |
| Child data is special in practice (photos of identifiable children; no health data collected) | Done (no weight/length collected) | The code collects no health data. If PLAN's optional weight/length is ever added, keep it local and optional. |
| Lawful basis / consent for notifications and camera | Partly done | Built: system prompts only. Notification prompt appears when onboarding is finished with reminders on (the switch starts on); the camera/photo prompt appears at first use. There is no pre-explanation screen. |
| Right of access/portability | Partly done | Photos are plain JPGs in the parent's Drive and the app can make a PDF. There is no `profile.json` and no "Export profile data". |
| Right to erasure | Partly done | Built: remove a baby (deletes the profile and phone copies, not Drive photos) and delete single photos (also from Drive). Not built: "Delete all data on this phone" and "Disconnect Drive". Drive files are deleted by the parent in Drive. |
| Privacy policy | Draft written | Updated to match the app in [PRIVACY_POLICY.md](PRIVACY_POLICY.md); placeholders and legal review remain. |
| No processor agreements needed with Google/Apple for the developer (they are the parent's own providers) | Done (by design) | Confirm with legal. |
| EU representative / DPO | Needs owner action | Probably not required when no data is processed; confirm with legal. |
| Sharing links: parent makes the Shared folder public by link | Done | A deliberate user action ("Get a share link" in the menu, then "Create link"), with an on-screen explanation that anyone with the link can view; off by default; "Stop sharing" removes the permission. The folder holds only a PDF of all the baby's photos (with name and birth date on the cover). Stopping the share leaves the PDF in the folder. |

## 3. COPPA and children's privacy

| Item | Status | Notes |
|---|---|---|
| App is for parents (adults); not directed to children and not aimed at under-13s | Done (by design) | State the age rating as 17+/adult-oriented usage in store forms where required, or "not for children". See below. |
| The app collects nothing from anyone, so COPPA "personal information collection from children" does not occur | Done (by design) | The baby is the subject of photos, not a user. |
| Apple Kids Category / Google Families Policy | Done | Do NOT opt in to these programs. |
| Store age-rating questionnaires | Needs owner action | Answer honestly: no user-generated sharing inside app, no ads, no tracking. |
| Legal view on photos of babies in shared links | Needs owner action | Ask legal whether the policy needs extra wording. |

## 4. Google OAuth / Drive API

| Item | Status | Notes |
|---|---|---|
| Scope: only `https://www.googleapis.com/auth/drive.file` (non-sensitive; app sees only files it created or the user opens with it) | Done in code | `DriveCloud` requests only `drive.file`. Consequence: photos or files added by hand to the folder in Drive are **not visible to the app**. |
| Google Cloud project + OAuth consent screen (app name, support email, logo, authorised domain) | Needs owner action | Production status, not "Testing" (testing tokens expire in 7 days). |
| OAuth client IDs: one Android (package + SHA-1), one iOS (bundle id) | Needs owner action | Client IDs are not secrets but keep them in config. |
| Privacy policy URL (public, on a domain you control) and homepage | Needs owner action | Host PRIVACY_POLICY.md as a web page. |
| Limited Use / API Services User Data Policy | To do | Policy must state: we do not transfer Google data to anyone, do not use it for ads, and use it only to provide the user-facing features. Since we receive no data at all, this is easy, but it must be written. |
| Verification | Needs owner action | Non-sensitive scopes normally need only the consent-screen basics and brand check, not the sensitive-scope review or security assessment. Verify current Google rules at submission time. |
| Public "anyone with the link" permission via API | Done | Set only on the `Shared` folder the app created, only after the parent taps Create link. Removed by Stop sharing. |
| Token handling: refresh tokens in secure storage; "Disconnect" revokes | Partly done | The app stores no tokens itself; they are handled by Google's sign-in library. There is no in-app "Disconnect" (the code has a sign-out method but no button); the parent can revoke at myaccount.google.com/permissions. |

## 5. Apple App Store

| Item | Status | Notes |
|---|---|---|
| Apple Developer Program membership | Needs owner action | About US$99/year; required for iCloud entitlement and TestFlight. |
| App Privacy "nutrition label" | To do | Expected answer: **Data Not Collected** (developer receives nothing). Re-check if any SDK collects data. |
| `NSCameraUsageDescription` in Info.plist | Done | Present: "Baby Photobook uses the camera to take your baby's photo. Photos are saved only to your own storage." |
| `NSPhotoLibraryUsageDescription` (picking from gallery) | Done | Present: "Choose an existing photo of your baby from your library." The app only reads photos the parent picks and never saves to the library, so no `NSPhotoLibraryAddUsageDescription`. |
| Notifications: ask permission in context | Done | Runtime prompt only, asked when onboarding is finished with reminders on. No Info.plist string. |
| iCloud entitlement (iCloud Documents / container) and capability | Not needed yet | iCloud is not built ("Coming soon" in the app). Needed only when it is. An iPhone build also needs a Mac or cloud CI. |
| Privacy policy URL in App Store Connect | Needs owner action | |
| Privacy manifest (`PrivacyInfo.xcprivacy`) with required-reason APIs from plugins | To do | Check each plugin ships one. |
| Review notes: demo account/instructions for Drive | To do | Reviewers need to test sign-in. |
| Encryption export compliance | To do | Uses only standard HTTPS: answer exempt. |
| Account deletion rule (5.1.1(v)) | Done (by design) | App has no accounts of its own. |

## 6. Google Play

| Item | Status | Notes |
|---|---|---|
| Play Console account | Needs owner action | One-time US$25; new personal accounts may need closed testing (e.g. 12 testers for 14 days) before production. Verify current rule. |
| Data safety form | To do | Expected: no data collected, no data shared. Answers in [STORE_LISTING.md](STORE_LISTING.md). |
| Exact alarm permission (`SCHEDULE_EXACT_ALARM`) | Decided: not used | Reminders are inexact, so the permission is neither requested nor declared. The cost: reminders can arrive a little late. Do not add `USE_EXACT_ALARM` (alarm/calendar apps only). |
| Other permissions | Done | Declared in the manifest: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` (so reminders return after a restart), `INTERNET`. `CAMERA` is **not** declared: the camera is the phone's own camera app, opened through the image picker. Re-check this on a real device before submitting. |
| Photo/media permissions policy | Done | The system photo picker is used; no `READ_MEDIA_IMAGES` or broad storage access is declared. |
| Target API level requirement | To do | Keep targetSdk current. |
| Content rating questionnaire, target audience "adults/parents" (not children) | Needs owner action | |
| Privacy policy URL | Needs owner action | |
| Account deletion disclosure | Done (by design) | No in-app accounts. |

## 7. Notification consent

- **Honest status:** reminders start **switched on** in onboarding (the switch is on by default and the parent can turn it off before tapping Finish). The system permission prompt appears only when the parent finishes onboarding with the switch on, or switches reminders on later in Settings. Decision for the owner: keep this, or start with the switch off. Status: open.
- If the permission is denied the app shows one short note and never nags. There is an on/off switch per baby in Settings. Notification text is "Time for <name>'s photo" plus an age label, with no photo, so a lock screen shows the baby's name. Status: Done; no pre-explanation screen (not built).

## 8. Data deletion and export

| Item | Status |
|---|---|
| In-app "Delete all data on this phone" (profiles, cache, queue, tokens) | Not built. Only "Remove <baby>" exists (profile + phone photos of that baby; Drive photos stay; this is stated in the dialog). |
| "Disconnect Google Drive" (revoke token) | Not built (parent can revoke at myaccount.google.com/permissions) |
| Deleting one photo | Done: removes it from the phone and the Drive folder (if offline, the Drive copy stays) |
| Deleting Drive photos in bulk: done by the parent in Drive; app explains how | Not built (no explanation in the app) |
| Photos are normal JPGs in the parent's Drive = portable | Done (by design) |
| Remove the public link (revoke) | Done ("Stop sharing"; the PDF stays in the Shared folder) |
| Uninstalling the app removes in-app-only photos; warn in advance | Done (warning in onboarding and on the baby page) |

## 9. Security

| Item | Status | Notes |
|---|---|---|
| No secrets in the repo (client IDs in config only, no API keys, no keystores) | To do | Client IDs are optional build-time settings (`--dart-define`), not in code. Still to do: `.gitignore` entries for keystores, `google-services`, `key.properties`; scan before pushing. |
| OAuth tokens in Keychain / Android Keystore | Done by the library | The app stores no tokens itself and has no secure-storage package; Google's sign-in library holds the authorisation. |
| Local profiles/photos in app-private storage | Done, with a caveat | `babies.json` and the photos are in the app's private folder and are protected only by the phone's app sandbox and screen lock; the app adds no encryption. Android automatic backup is not switched off in the manifest, so these files may be included in the parent's Google device backup. Decide whether to turn that off. |
| HTTPS only | Done | Google APIs only. |
| Shared links | Done | Drive link to a folder holding only a PDF, created on request, revocable; the screen says anyone with the link can view. |
| Logs contain no names or photo content | To do | Not audited; the code writes no logs of its own. |
| Dependency updates and review | To do | Versions are set with `^` ranges in `pubspec.yaml`; check licences. |
| Optional app lock (PIN/biometric) | Later | |

## 10. Third-party SDKs and plugins (as in `pubspec.yaml`)

| Package | What it does | Data leaves phone? |
|---|---|---|
| Flutter / Dart SDK | App framework | No |
| flutter_riverpod | State management | No |
| path_provider | Finds the app's private folders | No |
| flutter_local_notifications + timezone + flutter_timezone | Reminders on the device | No |
| image_picker | Opens the phone's camera app and the system photo picker | No |
| url_launcher | Opens the Drive folder in the browser / Drive app | Opens a Google page the parent asked for |
| share_plus | Native share sheet (photos, PDF, link text) | Only to the app the parent picks |
| pdf + image | Builds the PDF photobook on the phone and shrinks photos for it | No |
| google_sign_in | Google sign-in and the `drive.file` authorisation | Yes, to Google, at parent's request |
| googleapis (Drive v3) + http | Upload, list, download, delete and share Drive files | Yes, to Google Drive |

Not used (earlier plans, dropped or deferred): drift (SQLite), camera (in-app camera), icloud_storage, ffmpeg_kit, flutter_secure_storage.

Rule: no analytics, ads, crash-reporting or remote-config SDK. Nothing of that kind is in the package list. Still to do: check each plugin's own network use and privacy manifest.

## 11. Summary of owner actions

1. Choose the legal publisher name and support email.
2. Create Apple Developer and Google Play accounts; Google Cloud project and OAuth consent screen.
3. Host the privacy policy on a public URL.
4. Have a lawyer review the privacy policy and the children's-privacy position.
5. Confirm the Android reminder approach (inexact, no exact-alarm permission) and whether reminders should start switched off.
6. Provide access to a Mac or cloud CI for iOS builds.
7. Android automatic backup is now switched off in the app (done). Decide whether to add "Delete all my data" and "Disconnect Drive" before launch.
8. Confirm you accept that photos added by hand to the Drive folder are not visible to the app (`drive.file`).
