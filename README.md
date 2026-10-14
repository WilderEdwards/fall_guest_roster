# In-Class 09 / Fall Festival Roster + Card Catalogue (Part II builds on Part I)

Student / course / pathway: [LastName, FirstName] / [Course + Section] / Undergraduate
Flutter / Dart versions: [fill in from `flutter --version`]
Device / OS: [e.g. Pixel 7 API 34 emulator / Android 14]

Setup/run commands:

```sh
flutter pub get
flutter run
```

## Storage notes

- DB: `MyDatabase.db`, version 2. `onConfigure` runs `PRAGMA foreign_keys = ON`.
  `onCreate` builds Part I + catalogue tables; `onUpgrade` adds catalogue tables
  only when `oldVersion < 2`, so Part I rows survive.
- Tables: `my_table(_id, name, age)` (Part I, unchanged) plus
  `folders(id PK AUTOINCREMENT, name UNIQUE, created_at)` and
  `cards(id PK, title, suit, notes DEFAULT '', image_ref NULL, folder_id FK CASCADE)`,
  plus `CREATE INDEX idx_cards_folder_id ON cards(folder_id)`.
- Models: `lib/folder.dart` and `lib/card_record.dart` (`fromMap`/`toMap`).
  `CardRecord` avoids clashing with Material `Card`.
- Repository (`lib/database_helper.dart`): `insertFolder`, `getFoldersWithCounts`
  (LEFT JOIN + COUNT, empty folders = 0), `getCards` (`where: folder_id = ?`,
  `whereArgs`, `orderBy: title COLLATE NOCASE ASC`), `insertCard`, `updateCard`,
  `deleteCard`, `deleteFolder` (cascade). Diagnostics: `PRAGMA user_version`,
  `foreign_keys`, `foreign_key_list(cards)`, `index_list(cards)`.
- UI (`lib/catalogue_screen.dart`, tab `Folders`; `Guests` tab keeps Part I):
  folder counts, tap-to-open by ID, shared Add/Edit card form, deletes confirm
  by name, empty/loading/error states, busy guard, input kept on failure.
  Duplicate folder names show an error (no `replace` — it could wipe cards).
- Image: nullable `image_ref`. Null/empty shows a suit symbol (♥ ♦ ♣ ♠).
  URLs use `Image.network` with fallback; anything else tries `Image.asset`
  with fallback. No picker.
- Delete rule: `ON DELETE CASCADE` (folder owns its cards). A clinic/billing app
  would use RESTRICT/archive instead — see DOCX prompt 2.

## Actual tests (Part II T1–T6 — fill with your real IDs/counts)

| Test | Action/input | Expected | Observed IDs/values/counts | Pass/fail |
| --- | --- | --- | --- | --- |
| T1a upgrade | Open v1 install with new helper; record PRAGMAs + Part I rows | Part I IDs/values kept, new tables + index exist | user_version=[ ], fk=[ ], Part I before=[ ] after=[ ] | [ ] |
| T1b fresh | Launch v2 on separate disposable target | All tables created; empty folder opens clean | target=[ ] | [ ] |
| T2 create | Create Atlas + Harbor; add Compass x2 in Atlas, Signal (image NULL) in Harbor | 3 distinct card IDs; Atlas 2, Harbor 1 | Atlas ID=[ ], Harbor ID=[ ], card IDs=[ ] | [ ] |
| T3 edit | Edit one Compass by ID → Compass revised + notes, Save; edit other, Cancel | Save = 1 row, only chosen card changes; Cancel writes nothing | edited ID=[ ], affected=[ ] | [ ] |
| T4 restart | Record IDs/counts, Force-stop (no Clear), relaunch same install | Same folders/IDs/counts, no reseed | before=[ ] after=[ ] | [ ] |
| T5 delete | Cancel card delete, confirm it; Cancel folder delete, confirm Atlas delete | Cancels change nothing; card delete = 1; folder delete = 1 parent + its cards, Harbor kept | deleted card=[ ], deleted folder=[ ] | [ ] |
| T6 validation | Open Signal (NULL image) → fallback; try whitespace title, blank folder, duplicate Harbor | Fallback shows; all invalid give feedback, counts unchanged | counts=[ ] | [ ] |

T4 method: [fill exact — Android: stop debug → App info → Force stop → relaunch / iOS: stop → app-switcher kill → `flutter run -d <id>` + target]
Release smoke test: [build cmd/result, install target, create/read/edit/delete + fallback + restart — observed]
Evidence: `evidence/T1_before.png` (before upgrade!), `evidence/T2_cards.png`, `evidence/T4_after.png`, `evidence/analysis_output.txt`

Analyzer: `dart analyze lib` → No issues found (see `evidence/analysis_output.txt`).

Known limitations: [fill, e.g. none / URL images need network]

## Attribution

- Starter: course Part I schema + `sqflite`/`path_provider`/`path` deps; Flutter counter template replaced.
- My additions: v2 migration, models, catalogue UI, validation, fallback.
- References: Flutter SQLite cookbook, sqflite docs, SQLite foreign-keys docs.
- AI assistance: OpenCode for scaffolding.
