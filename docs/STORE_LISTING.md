# Store Listing Drafts

Draft text for Apple App Store and Google Play, checked against the code on 2026-10-11. Features marked (planned) are not built yet: remove them or build them before submitting, and re-check that the text still matches the app. The first release works with Google Drive only; iCloud is "Coming soon" in the app and must not be advertised yet.

## Name and subtitle

| Field | Text | Limit |
|---|---|---|
| App name | Baby Photobook (the name the phone shows; the stores could use "Baby Growth Photobook" if the owner prefers) | 30 chars (both stores) |
| Subtitle (iOS) | One photo at a time, your way | 30 |
| Short description (Play) | Baby photos on a schedule you choose, kept in your own Google Drive. | 80 |

## Long description (both stores, max 4000)

Your phone is full of baby photos, and the ones that matter get lost. Baby Photobook helps you take a small, meaningful set instead: one photo on days you choose, thinning out as your child grows.

**You set the rhythm.** Daily in the first month, weekly for a while, then monthly. Or anything you like. At most one photo per day, never any pressure.

**A gentle reminder.** Pick a time of day, or turn reminders off completely. Reminders can arrive a few minutes late.

**Your photos stay yours.** Each photo is saved in your own Google Drive as a plain, tidy file such as 00001_2026-10-10.jpg, in a folder you can open from the app. No account with us. No ads. No tracking. We never receive your photos or your baby's details. (iCloud Drive: planned, do not mention until built.)

**A timeline that grows with your baby.** Photos are grouped by age, with labels like "3 weeks, 2 days", and open full screen. (Milestone cards, a birth-story card and a slideshow are planned, not built.)

**Add a day you missed.** Pick a photo from your gallery and choose which day it is for. One photo per day; a retake replaces it.

**Share when you want.** Make a PDF photobook and send it with your phone's share sheet, or create an optional link to a folder in your Drive with the PDF, for family. Anyone with the link can view it, and you can stop sharing at any time.

**More than one child.** Each baby has their own profile, schedule and folder.

**Works offline.** Take photos anywhere; they are kept on your phone and upload when you are back online (open the baby's page or tap Sync).

**New phone?** "Restore photos from Drive" brings back the photos for a baby you have set up again. (Restoring the whole profile automatically is planned.)

Don't want to connect cloud storage? You can keep photos only in the app, but we will remind you they can be lost if you lose or reset your phone.

## Keywords (iOS, 100 chars total, comma separated)

baby,photo,journal,milestone,growth,newborn,monthly,reminder,photobook,timeline,parenting,private

## Screenshots (6 to 8 per store)

1. Welcome / "One photo at a time" with scrapbook cards.
2. Your baby's profile (onboarding).
3. Choose where photos live (Google Drive, "iCloud: Coming soon", app only).
4. Build your schedule, phases thinning out.
5. Reminder time and on/off.
6. Baby page: photo day card, "Where are my photos" card and the timeline.
7. Full-screen photo with age label.
8. PDF export / share link sheet.
(Ghost overlay and milestone cards are not built; do not show them.) Capture light and dark mode; use sample (not real) baby photos; no personal data visible. Sizes: iPhone 6.9" and 6.5", iPad if supported; Play phone screenshots plus a 1024x500 feature graphic and 512x512 icon.

## Support and policy

Support email: [CONTACT EMAIL]. Privacy policy URL: [PUBLIC URL OF PRIVACY POLICY]. Category: Lifestyle (or Parenting). Age rating: all content suitable for everyone, but audience is adults/parents; do not join Kids or Families programs. Price: [FREE / PAID, owner decision].

## Apple App Privacy answers

Data collection: **Data Not Collected**. No tracking. (Re-check if any plugin collects data.)
Permissions text: camera and photo library (iOS strings are in Info.plist, see COMPLIANCE.md). The app only reads photos the parent picks.
Note for the form: the only data that leaves the phone goes to Google Drive, initiated by the parent, plus an optional public Drive link the parent creates.

## Google Play Data safety answers

| Question | Answer |
|---|---|
| Does the app collect or share user data? | No data collected, no data shared with third parties (data stays on device and the user's own Google Drive, initiated by the user; an optional public Drive link is created only if the user asks) |
| Is data encrypted in transit? | Yes (HTTPS) |
| Can users request data deletion? | We hold no data. In the app the parent can delete photos (also from their Drive) and remove a baby; there is no single "Delete all data" button yet. Do not claim one until it is built. |
| Ads | No |
| Independent security review | No |
| Families Policy | Not applicable, not designed for children |
| Permissions declared (as in the Android manifest today) | POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, INTERNET. No CAMERA permission (the phone's camera app is used) and no exact-alarm permission (reminders are approximate). Re-check on a release build. |

Note: Google may consider data sent to the user's own Drive as user-initiated transfer; confirm wording in the form at submission.
