# رسوخ (Rusookh)

A Flutter app for making lessons stick. You finish a lesson, pull out its core,
turn that into questions, and review the questions on a spaced schedule,
mixed across lessons. The method is in [`requirements.txt`](requirements.txt).

## How it works

1. **Extract the core (اللُّب):** principles, rules, warnings and practical steps.
2. **Turn it into questions:** definition, why, application and common-mistake
   questions. Each has a written answer and, optionally, multiple-choice options.
3. **Spaced review:** a question comes back after 1 → 3 → 7 → 14 → 30 → 90 days,
   then the gap keeps doubling. Forgetting sends it back to the start.
4. **Interleaving:** each review session mixes questions from different lessons.

**AI step (copy/paste, no API key):** copy the prompt from the app, send it with
the lesson to any chat AI (ChatGPT, Claude, Gemini), copy the JSON reply, and
switch back to the app. It reads the reply from the clipboard, shows a preview
and saves with one tap. Content is in Fusha (فصحى).

**Reminders:** one local notification per day at a chosen time, only on days
with questions due, showing the count.

## Running

```sh
flutter pub get
flutter test
flutter run --release        # on a connected device
```

> `shared_preferences_android` is pinned to 2.4.28 in `pubspec.yaml`. Version
> 2.5.0 (Pigeon JNI) crashes at startup with `NoSuchMethodError`. Remove the
> override once a fixed release ships.

## Code layout

| Path | Purpose |
| --- | --- |
| `lib/models/models.dart` | `Lesson`, `CorePoint`, `StudyCard`, `ReviewLog` |
| `lib/logic/scheduler.dart` | Spaced-repetition ladder and due dates |
| `lib/logic/interleave.dart` | Mixes cards so neighbours come from different lessons |
| `lib/ai/ai_prompt.dart` | The AI prompt and a tolerant JSON parser |
| `lib/data/repository.dart` | `Repository` interface + SQLite implementation |
| `lib/services/notification_service.dart` | Daily review reminders |
| `lib/state/app_state.dart` | App state, import/merge, stats, backup |
| `lib/ui/` | Screens |

## Roadmap

### 1. App icon

Replace the default Flutter icon with a Rusookh icon on Android and iOS (e.g.
via `flutter_launcher_icons`), including an Android adaptive icon and the
notification icon.

### 2. Shareable web version

Share a lesson with a link that anyone can open in a browser to study it.

- **Web build:** a Flutter web build of the same codebase, hosted (e.g. Firebase
  Hosting). It needs a web `Repository` implementation, since `sqflite` and
  local notifications don't run on the web.
- **Share link:** a "Share" action on a lesson publishes a read-only copy (core
  points + questions) and returns a link like `https://<host>/l/<lessonId>`.
- **The shared lesson page has two parts:**
  - **Summary in points:** the lesson's core as a clean, readable list, grouped
    by kind (principles, rules, warnings, practical steps). Works as a quick
    reference you can read in a minute.
  - **Interactive questions page:** one question at a time, same flow as the
    app: the question first, then tappable options with instant right/wrong
    feedback, then the written answer on demand. Shows progress, a score at the
    end, and an option to retry the questions you got wrong.
  - No reminders and no spaced schedule on the web (free practice only).
- **Install invitation:** a banner inviting visitors to install the app. Tapping
  "Add to my lessons" opens the app via a deep link (Android App Links / iOS
  Universal Links) and imports the lesson into the visitor's library, with
  reminders. If the app isn't installed, the link goes to the store; after
  installing, the visitor can find the lesson by link or code.
- **Open questions:** where shared lessons are stored (Firestore is the natural
  fit, see item 3), whether shared copies update when the author edits the
  lesson, and whether a link can be revoked.

> **Dependency:** publishing a lesson needs a backend to host it. Doing item 3's
> Firestore setup first (or at least the shared-lessons collection with
> anonymous auth) makes this item straightforward.

### 3. Accounts and sync with Firestore

- **Login:** Firebase Auth with Google sign-in (plus Apple sign-in for iOS), or
  email if needed. Using the app without an account stays possible.
- **Sync:** lessons, cards and review logs stored under
  `users/{uid}/...` in Firestore, with offline persistence so the app keeps
  working without internet. Behind the existing `Repository` interface.
- **Migration:** on first sign-in, upload the existing local data. Merge rules
  for conflicts (e.g. a card's latest review wins).
- **Multi-device:** the review schedule follows the user across devices.
  Reminders are still scheduled locally on each device from the synced data.
- **Security rules:** each user can read and write only their own data. Shared
  lessons (item 2) are publicly readable, writable only by their author.
- **Backups:** an account removes the "uninstall = lose everything" risk.

### Backlog

- **Reminders beyond 14 days:** reminders are scheduled only 14 days ahead, so
  they stop if the app isn't opened for 2 weeks. Schedule further ahead and add
  "it's been a while" nudges (after 3 days, 1 week, 2 weeks).
- **Question count:** the prompt tends to yield ~12 questions per lesson. Let
  the count follow the lesson's size instead (at least one per core point).
- **Share-to-app:** receive the AI reply through Android's share sheet, skipping
  the copy-and-switch step.
- **Backup to file:** export/import a backup file through the share sheet
  (Drive, Telegram...), instead of only the clipboard.
- **Fusha UI:** the app's own labels are in Egyptian Arabic; content is in Fusha.
- **API-based AI:** when an API key is available, send the prompt directly and
  feed the reply into the existing parser.
- **iOS:** build and test on a real iPhone (notifications included).
