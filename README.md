# In-Class 09 / Fall Festival Roster + Card Catalogue (Part II builds on Part I)

Student / course / pathway: [LastName, FirstName] / [Course + Section] / Undergraduate
Flutter / Dart versions: [fill in from `flutter --version`]
Device / OS: [e.g. Pixel 7 API 34 emulator / Android 14]

This app keeps my Part I guest roster and adds a folder/card catalogue in the
same database. The Guests tab is Part I. The Folders tab is new.

Setup/run:

```sh
flutter pub get
flutter run
```

Do a full restart (not hot reload) after adding plugins like `sqflite`.

## Storage notes

- **Database.** Same file `MyDatabase.db`, now version 2. `onConfigure` turns on
  `PRAGMA foreign_keys = ON`, or the foreign key and cascade will not work.
  `onCreate` builds all tables for fresh installs. `onUpgrade` only adds the
  new tables when `oldVersion < 2`, so old guest rows are kept. No extra
  transactions inside these callbacks — they already run in one.

- **Tables.** Part I `my_table(_id, name, age)` is unchanged. New tables:
  `folders(id AUTOINCREMENT, name UNIQUE, created_at)` and `cards(id, title,
  suit, notes DEFAULT '', image_ref NULL, folder_id FK CASCADE to
  folders(id))`, plus index `idx_cards_folder_id`. Names are case-sensitive
  UNIQUE ("Harbor" ≠ "harbor"). `created_at` is an ISO-8601 string.

- **Models.** `lib/folder.dart` and `lib/card_record.dart` with
  `fromMap`/`toMap`. `CardRecord` is named to avoid Flutter's `Card` widget.
  Missing image = SQL `NULL`. Missing notes = `''`.

- **Repository.** All SQL is in `lib/database_helper.dart`: `insertFolder`,
  `getFoldersWithCounts`, `getCards`, `insertCard`, `updateCard`, `deleteCard`,
  `deleteFolder`. Folder list uses LEFT JOIN + COUNT so empty folders show 0.
  Card lookup uses `whereArgs` and sorts A–Z case-insensitive. Edits/deletes use
  the integer id and return 1 (done) or 0 (already gone). PRAGMA helpers are
  included for T1 evidence.

- **UI.** `lib/catalogue_screen.dart` (Folders tab): folder names + counts,
  tap to open by id, one shared Add/Edit card form, delete confirms with the
  name, plus loading/empty/error states. A busy flag blocks double-taps.
  `mounted` is checked after awaits. Failed writes keep your input. Blank or
  spaces-only titles/names are rejected. Duplicate folder names show an error.
  `replace` is never used since it could wipe a folder's cards.

- **Images.** `image_ref` is optional. Empty shows a suit symbol (♥ ♦ ♣ ♠).
  URLs load with `Image.network`, others try `Image.asset`; both fall back to
  the symbol on error. A reference is not the image itself — a good query does
  not mean the file or link still works. No picker (optional per spec).

- **Delete rule.** Folders use CASCADE: deleting Atlas removes its cards but
  leaves Harbor alone. That fits here since cards belong to their folder. A
  clinic/billing app should not do this — use RESTRICT or archive instead
  (see DOCX prompt 2).

## Actual tests (T1–T6)

| Test | Action/input | Expected | Observed | Pass/fail |
| --- | --- | --- | --- | --- |
| T1a upgrade | Open v1 install with new code; check PRAGMAs + guest rows | Guest IDs/values kept, new tables exist | Before: River 1/21, River 2/35, count 2 (`T1_before.png`); after: same 2 Rivers (`T4_after.png`); PRAGMAs=[fill] | Partial |
| T1b fresh | Fresh v2 on separate target | All tables built, empty folder opens | target=[fill] | [ ] |
| T2 create | Add Atlas + Harbor; add Compass x2 in Atlas, Signal (no image) in Harbor | 3 card IDs; Atlas 2, Harbor 1 | Atlas=1, Harbor=2; Signal=1, Compass revised=2, Compass=3 (`T2_cards.png`) | Pass |
| T3 edit | Edit one Compass to revised + notes, Save; edit other, Cancel | Save = 1 row, only that card changes; Cancel writes nothing | ID 2 → revised (Diamonds, Notes for T3), 1 row; ID 3 unchanged; Cancel not in shots | Pass (Save part) |
| T4 restart | Note IDs/counts, Force-stop (no Clear), relaunch | Same data, no duplicates | Guests after: same 2 Rivers (`T4_after.png`); Folders after shot still needed | Partial |
| T5 delete | Cancel card delete, confirm it; Cancel folder delete, confirm Atlas | Cancels change nothing; card=1, folder=1 + its cards, Harbor kept | IDs=[fill] — not in shots | [ ] |
| T6 validation | Open Signal (no image); try blank title, blank folder, duplicate Harbor | Fallback shows; invalid attempts blocked, counts same | Signal 1 shows heart fallback (`T6_fallback.png`); invalid attempts=[fill] | Partial |

T4 method: [fill — Android Force stop → relaunch / iOS kill → `flutter run -d <id>` + target]
Release test: [build cmd/result, target, create/read/edit/delete + fallback + restart]
Evidence: `T1_before.png`, `T2_cards.png`, `T4_after.png`, `T6_fallback.png`, `analysis_output.txt`. Note: `T4_after.png` shows Guests — one Folders shot after restart will finish T4.

Rubric map: schema → `database_helper.dart` + T1; models/CRUD → models + helper + T2–T5; image → fallback + T6; tests → table + `evidence/`; delivery → repo URL, APK, DOCX.

Analyzer: `dart analyze lib` → No issues found (`evidence/analysis_output.txt`). Plain `flutter analyze` needs Windows Developer Mode, so `dart analyze` is recorded.

Known limitations: T1 PRAGMAs, T1b, T5, T6 invalid attempts, and Folders-after-restart shot are still open. Fixed after shots: "Updated card ID null" now shows the real id — needs one re-test.

## Submission (upload all three to iCollege)

- `github_link.txt` with this repo URL.
- `Activity09_Lastname_Firstname.apk` from `flutter build apk --release`, tested on a spare target.
- `Lastname_Firstname_CriticalThinking.docx` with name, ID, pathway, prompts 1–3 + two U answers (grads: 1–4 + two G answers), evidence refs, AI disclosure.

## Attribution

- Starter: Part I schema + `sqflite`/`path_provider`/`path`; counter template replaced.
- Mine: v2 migration, models, catalogue UI, validation, fallback.
- Refs: Flutter SQLite cookbook, sqflite docs, SQLite foreign-keys docs.
- AI: OpenCode for scaffolding.
