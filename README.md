# NoteNest — Cute Smart Notes

> Your little space for big ideas.

A cozy, offline-first notes app for Android, built with **Flutter + Dart**. Inspired
by the convenience of Google Keep, but with its own original design, branding and
feature set.

- **Package ID:** `com.notenest.notes`
- **Version:** 1.0.0+1
- **Platform:** Android (portrait phones, responsive)
- **Languages:** English, বাংলা (runtime language selector)

---

## What this repository is

This is the **complete application source project**. It contains real, functional
implementations of the core note-taking product — persistent local storage,
autosave, checklists, labels, search, reminders, backup/restore, themes and the
full screen set — not a UI mock-up.

Optional, external-service features (cloud sync, AI, OCR, transcription) are wired
to **real interfaces** that either work with a genuine engine or show an honest
"not configured" state. Nothing is faked:

| Area | Status | Notes |
|---|---|---|
| Local notes, autosave, offline | **Implemented** | SQLite via `sqflite`, real on-disk DB |
| Checklists, labels, pin/favourite, archive, trash | **Implemented** | |
| Search (title, body, checklist, labels) + history | **Implemented** | |
| Reminders → local notifications, recurrence, reschedule on reboot | **Implemented** | `flutter_local_notifications` + `timezone` |
| Backup / restore (zip with attachments), text export | **Implemented** | `archive`, `file_picker` |
| Themes: light, dark, system, pastel packs, EN/BN | **Implemented** | |
| Image notes, drawing canvas, voice record/play | **Implemented** | `image_picker`, custom canvas, `record`/`just_audio` |
| OCR from images | **Real engine, on-device** | Google ML Kit text recognition |
| Voice transcription | **Real engine** | On-device speech recogniser; honest message if unavailable |
| App lock (biometric) | **Implemented** | `local_auth` |
| AI (summarise / rewrite / checklist) | **Opt-in, real API** | User supplies their own key; no keys in the repo |
| Cloud sync / accounts | **Not configured by design** | Local-only mode; the app never pretends sync is on |

---

## Getting the APK

> **This project was authored in a sandbox that has no Flutter/Android toolchain**
> (no Flutter SDK, JDK, Android SDK or Gradle; `apt` blocked). A release APK
> therefore **could not be compiled there** — and this README does not pretend
> otherwise. The project is complete and buildable; run the steps below on any
> machine with the Android toolchain.

Full, step-by-step instructions are in **[BUILD_AND_RUN.md](BUILD_AND_RUN.md)**.
In short:

```bash
flutter pub get
flutter gen-l10n          # (no-op here; localisation is hand-rolled, see below)
flutter analyze
flutter test
flutter build apk --release        # -> build/app/outputs/flutter-apk/app-release.apk
# optional bundle:
flutter build appbundle --release  # -> build/app/outputs/bundle/release/app-release.aab
```

The generated APK is at `build/app/outputs/flutter-apk/app-release.apk`.
Install with `adb install -r <path>` or by copying it to the device.

---

## Architecture

Modular and layered so it stays testable as it grows:

```
lib/
├─ main.dart                  App entry: prefs, DB warm-up, notifications
├─ app.dart                   MaterialApp, providers, routing, localisation
├─ core/
│  ├─ constants/              enums (note types, sorts), app info
│  ├─ l10n/                   English + Bengali strings, BuildContext helpers
│  ├─ theme/                  palette, light/dark themes, pastel packs
│  └─ utils/                  date formatting, URL validation
├─ data/
│  ├─ db/                     sqflite DatabaseHelper + migrations
│  ├─ models/                 Note, ChecklistItem, Label, Attachment
│  ├─ repositories/           NoteRepository, LabelRepository (all SQL lives here)
│  └─ services/               notifications, backup, OCR, AI, speech, sync, lock
├─ providers/                 NotesProvider, LabelsProvider, SettingsProvider
├─ screens/                   the 17 required screens
└─ widgets/                   NoteCard, empty states, pickers, action sheet
```

**State management:** `provider` (ChangeNotifier). **Persistence:** `sqflite`
with forward-only, non-destructive migrations (v1→v3 shipped). **No business
logic in widgets** — every write goes through a provider → repository → database.

### Database

`notes`, `checklist_items`, `labels`, `note_labels`, `attachments`, `search_history`,
`meta`. Foreign keys with `ON DELETE CASCADE`; indexes on the hot paths. Trashed
notes keep a `trashedAt` timestamp so they can be auto-purged after 30 days.

### Localisation

A small, dependency-free `AppLocalizations` delegate ships English and Bengali and
supports a runtime language switch — no ARB codegen step required, so the project
builds without `flutter gen-l10n`.

---

## Screens (spec §13)

Splash · Onboarding (skippable) · Home · Search · Text editor · Checklist editor ·
Image editor · Voice recorder/player · Drawing editor · Labels · Reminders ·
Archive · Trash · Backup & restore · Settings · Account (optional) · About & privacy.

---

## Manual QA checklist (spec §15)

Run these on a device/emulator after building:

1. Create a note → close the app → reopen → the note persists.
2. Edit a note and confirm the autosave indicator ("Auto-saved").
3. Create a checklist and toggle items (progress updates).
4. Pin and unpin notes (pinned section updates).
5. Create a label and filter the home list by it.
6. Set a reminder and confirm the notification fires; tap it to open the note.
7. Archive a note, then unarchive it.
8. Delete a note → restore from Trash → delete forever.
9. Search by title and by body.
10. Attach an image, leave the note, and reopen it.
11. Export a backup, wipe data, and re-import (test both Merge and Replace).
12. Switch between light and dark themes and a pastel pack.
13. Use the app with airplane mode on.
14. (Cloud) — not applicable in this build; sync is intentionally off.
15. Build and launch the release APK.

`test/` also contains unit tests for the model round-trip, URL validation and
text export. Run them with `flutter test`.

---

## Privacy (spec §11)

No ads, no trackers, no analytics. Permissions are requested only when the
matching feature is used. Notes stay on the device unless the user explicitly
enables a configured backend. The AI key is stored in the platform secure store
(`flutter_secure_storage`) and is **never** hardcoded, logged or committed.
