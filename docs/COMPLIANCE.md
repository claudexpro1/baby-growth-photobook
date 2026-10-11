# Compliance Review (draft, not legal advice)

Status key: **Done** = in place today. **To do** = we must build/write it. **Needs owner action** = only the owner can do it (accounts, legal, forms).
Reality check: the app is early (profiles, onboarding, schedule, reminder settings). Cloud sync, camera, notifications and export are not built, so most items below are To do. A lawyer should review the privacy policy before launch.

## 1. Where data goes (the core privacy argument)

- Data stays on the parent's phone and in the parent's own Google Drive / iCloud Drive.
- The developer runs no server and receives no data, no analytics, no crash reports, no ads.
- The only network traffic is to Google (Drive API) or Apple (iCloud), initiated by the parent.

## 2. GDPR (EU/UK)

| Item | Status | Notes |
|---|---|---|
| Role: the parent is the controller of their own data (household use); developer does not process or receive data | Done (by design) | Say it plainly in the policy. If we ever add any server or telemetry, this changes completely. |
| Data minimisation: only name, birth date/time, optional birth place, photos | Done | Birth place and time are optional-feeling extras; consider making time and place clearly optional in UI. |
| Child data is special in practice (photos of identifiable children; no health data collected) | To do | Do not collect weight/length unless truly needed; PLAN lists optional weight/length. Keep it local and optional. |
| Lawful basis / consent for notifications and camera | To do | Use system permission prompts with a pre-explanation screen. |
| Right of access/portability | To do | Photos are plain JPGs in the parent's Drive; add "Export profile data" (profile.json). |
| Right to erasure | To do | "Delete all data on this phone" + "Disconnect Drive" in Settings; explain Drive files must be deleted in Drive. |
| Privacy policy | To do | Draft in [PRIVACY_POLICY.md](PRIVACY_POLICY.md). |
| No processor agreements needed with Google/Apple for the developer (they are the parent's own providers) | Done (by design) | Confirm with legal. |
| EU representative / DPO | Needs owner action | Probably not required when no data is processed; confirm with legal. |
| Sharing links: parent makes photos public by link | To do | Explicit warning, off by default, revocable. |

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
| Scope: only `https://www.googleapis.com/auth/drive.file` (non-sensitive; app sees only files it created or the user opens with it) | To do | Use no other scope. Not even `drive.readonly`. |
| Google Cloud project + OAuth consent screen (app name, support email, logo, authorised domain) | Needs owner action | Production status, not "Testing" (testing tokens expire in 7 days). |
| OAuth client IDs: one Android (package + SHA-1), one iOS (bundle id) | Needs owner action | Client IDs are not secrets but keep them in config. |
| Privacy policy URL (public, on a domain you control) and homepage | Needs owner action | Host PRIVACY_POLICY.md as a web page. |
| Limited Use / API Services User Data Policy | To do | Policy must state: we do not transfer Google data to anyone, do not use it for ads, and use it only to provide the user-facing features. Since we receive no data at all, this is easy, but it must be written. |
| Verification | Needs owner action | Non-sensitive scopes normally need only the consent-screen basics and brand check, not the sensitive-scope review or security assessment. Verify current Google rules at submission time. |
| Public "anyone with the link" permission via API | To do | Allowed for files the app created. Always an explicit user action. |
| Token handling: refresh tokens in secure storage; "Disconnect" revokes | To do | See security. |

## 5. Apple App Store

| Item | Status | Notes |
|---|---|---|
| Apple Developer Program membership | Needs owner action | About US$99/year; required for iCloud entitlement and TestFlight. |
| App Privacy "nutrition label" | To do | Expected answer: **Data Not Collected** (developer receives nothing). Re-check if any SDK collects data. |
| `NSCameraUsageDescription` in Info.plist | To do | E.g. "Baby Growth Photobook uses the camera so you can take your baby's photo." |
| `NSPhotoLibraryUsageDescription` (picking from gallery) | To do | Prefer the system photo picker (no permission needed). If saving to library, also `NSPhotoLibraryAddUsageDescription`. |
| Notifications: ask permission in context | To do | No Info.plist string, runtime prompt only. |
| iCloud entitlement (iCloud Documents / container) and capability | Needs owner action | Created in the Apple Developer portal; needs a Mac or cloud CI to build. |
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
| Exact alarm permission (`SCHEDULE_EXACT_ALARM`) | To do | Justification: user-set reminder at a specific time is a core function. Alternatively use inexact alarms and skip the permission (decision pending). `USE_EXACT_ALARM` is for alarm/calendar apps only; do not use it unless Play approves the declaration. |
| Other permissions: `POST_NOTIFICATIONS` (13+), `RECEIVE_BOOT_COMPLETED` (re-schedule), `CAMERA`, `INTERNET` | To do | Declare only what is used. |
| Photo/media permissions policy | To do | Use the system Photo Picker; do NOT request `READ_MEDIA_IMAGES` / broad storage access (restricted by Play policy). |
| Target API level requirement | To do | Keep targetSdk current. |
| Content rating questionnaire, target audience "adults/parents" (not children) | Needs owner action | |
| Privacy policy URL | Needs owner action | |
| Account deletion disclosure | Done (by design) | No in-app accounts. |

## 7. Notification consent

- Reminders are off until the parent turns them on in onboarding (current default in code is on; **change or ask first**). Status: To do.
- Pre-explain, then the system prompt. If denied, never nag. Easy off switch per baby. Wording contains no baby photos or sensitive details (lock screens show text). Status: To do.

## 8. Data deletion and export

| Item | Status |
|---|---|
| In-app "Delete all data on this phone" (profiles, cache, queue, tokens) | To do |
| "Disconnect Google Drive" (revoke token) | To do |
| Deleting Drive photos: done by the parent in Drive; app explains how | To do |
| Photos are normal JPGs in the parent's Drive/iCloud = portable | Done (by design) |
| Remove the public link (revoke) | To do |
| Uninstalling the app removes in-app-only photos; warn in advance | Done (warning in onboarding) |

## 9. Security

| Item | Status | Notes |
|---|---|---|
| No secrets in the repo (client IDs in config only, no API keys, no keystores) | To do | Add `.gitignore` entries for keystores, `google-services`, `key.properties`; scan before pushing. |
| OAuth tokens in Keychain / Android Keystore (via secure storage) | To do | Never in plain SharedPreferences. |
| Local database/photos in app-private storage | To do | Exclude from OS auto-backup if it would copy tokens; let photos back up only if the parent wants. |
| HTTPS only | To do | Default for Google APIs. |
| Shared links | To do | Unguessable Drive links, revocable; warn they are public to anyone holding the link. |
| Logs contain no names or photo content | To do | |
| Dependency updates and review | To do | Pin versions, check licences. |
| Optional app lock (PIN/biometric) | Later | |

## 10. Third-party SDKs and plugins (planned)

| Package | What it does | Data leaves phone? |
|---|---|---|
| Flutter / Dart SDK | App framework | No |
| flutter_riverpod | State management | No |
| drift (SQLite) | Local database | No |
| flutter_local_notifications + timezone | Reminders on the device | No |
| camera | In-app camera | No |
| image_picker | Gallery picker (system picker) | No |
| google_sign_in | Google sign-in to get the drive.file token | Yes, to Google, at parent's request |
| googleapis (Drive v3) | Upload, list, share Drive files | Yes, to Google Drive |
| icloud_storage (or similar) | Read/write iCloud Drive container | Yes, to Apple iCloud |
| pdf | Builds the PDF photobook on the phone | No |
| ffmpeg_kit (video, later; check maintenance status) | Timelapse | No |
| share_plus | Native share sheet | Only to the app the parent picks |
| flutter_secure_storage | Token storage | No |

Rule: no analytics, ads, crash-reporting or remote-config SDK. Check each plugin's own network use and privacy manifest. Status: To do.

## 11. Summary of owner actions

1. Choose the legal publisher name and support email.
2. Create Apple Developer and Google Play accounts; Google Cloud project and OAuth consent screen.
3. Host the privacy policy on a public URL.
4. Have a lawyer review the privacy policy and the children's-privacy position.
5. Decide the Android exact-alarm approach.
6. Provide access to a Mac or cloud CI for iOS builds.
