# In-Class 09 / Fall Festival Roster + Card Catalogue (Part II builds on Part I)

Student / course / pathway: [LastName, FirstName] / [Course + Section] / Undergraduate
Flutter / Dart versions: [fill in from `flutter --version`]
Device / OS: [e.g. Pixel 7 API 34 emulator / Android 14]

This project extends my Part I guest roster instead of replacing it. The Guests
tab is the original Part I screen and table, and the new Folders tab adds a
small parent/child catalogue on top of the same database file.

Setup/run commands:

```sh
flutter pub get
flutter run
```

A full restart (not hot reload) is needed after adding native plugins such as
`sqflite`, since those touch platform code.

## Storage notes

- **Database file and version.** The app still opens `MyDatabase.db`, now at
  version 2. `onConfigure` runs `PRAGMA foreign_keys = ON` on every connection,
  because SQLite will not enforce the foreign key or the cascade rule without
  it. `onCreate` builds both the Part I table and the new catalogue tables for
  a fresh install, while `onUpgrade` only calls `createCatalogueTables()` when
  `oldVersion < 2`. That split is what lets an existing version-1 install keep
  every guest row while gaining the new tables. The callbacks already run
  inside the plugin's transaction, so no extra `db.transaction()` is started
  there.

- **Tables.** `my_table(_id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER
  NOT NULL)` is unchanged from Part I. The new tables follow the assignment
  schema: `folders(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL
  UNIQUE, created_at TEXT NOT NULL)` and `cards(id INTEGER PRIMARY KEY
  AUTOINCREMENT, title TEXT NOT NULL, suit TEXT NOT NULL, notes TEXT NOT NULL
  DEFAULT '', image_ref TEXT, folder_id INTEGER NOT NULL, FOREIGN KEY(folder_id)
  REFERENCES folders(id) ON DELETE CASCADE)`, plus `CREATE INDEX
  idx_cards_folder_id ON cards(folder_id)`. The index exists because the app
  almost always looks up cards one folder at a time. Folder names are UNIQUE
  with SQLite's default case-sensitive comparison, so "Harbor" and "harbor"
  count as different names. `created_at` is stored as an ISO-8601 string from
  `DateTime.now().toIso8601String()`.

- **Models.** `lib/folder.dart` (`Folder.fromMap`/`toMap`) and
  `lib/card_record.dart` (`CardRecord.fromMap`/`toMap`) keep the UI from
  handling raw maps. The card class is called `CardRecord` on purpose so it
  never collides with Flutter's Material `Card` widget. A missing image is
  represented as SQL `NULL`, and missing notes are stored as `''`, so a row
  stays useful even with no artwork or notes.

- **Repository.** All SQL lives in `lib/database_helper.dart`: `insertFolder`,
  `getFoldersWithCounts`, `getCards`, `insertCard`, `updateCard`, `deleteCard`,
  and `deleteFolder`. `getFoldersWithCounts` uses a `LEFT JOIN` with
  `COUNT(cards.id)` so empty folders still appear with count 0. `getCards`
  filters with `where: 'folder_id = ?'` and `whereArgs: [folderId]` and sorts
  with `orderBy: 'title COLLATE NOCASE ASC'`, which means user input is bound
  rather than concatenated and titles sort A–Z regardless of case. Updates and
  deletes target the integer `id` only and return the affected-row count, so 1
  means success and 0 means the row was already gone. Read-only helpers expose
  `PRAGMA user_version`, `PRAGMA foreign_keys`,
  `PRAGMA foreign_key_list(cards)`, and `PRAGMA index_list(cards)` for the T1
  evidence.

- **UI.** `lib/catalogue_screen.dart` (the `Folders` bottom tab) shows each
  folder's name and card count, opens one folder's cards by its ID, reuses a
  single Add/Edit card form, and asks for confirmation naming the folder or
  card before any delete. It has explicit loading, empty, and error states, a
  busy flag that blocks double-taps while an async write is pending, `mounted`
  checks after every `await`, and it preserves typed input when a write fails
  instead of clearing the form. A whitespace-only title or folder name is
  rejected in the UI, since `NOT NULL` alone would not catch `"   "`.
  Duplicate folder names surface the UNIQUE error as visible feedback, and
  `ConflictAlgorithm.replace` is deliberately never used because replacing a
  parent row could cascade-delete its cards.

- **Image references.** `image_ref` is nullable by design. Null or empty shows
  a stable suit-symbol fallback (Hearts ♥, Diamonds ♦, Clubs ♣, Spades ♠), so
  the card's identity never depends on artwork. An `http(s)` reference tries
  `Image.network` with loading and error fallbacks, while anything else tries
  `Image.asset` with an error fallback. A reference is only a pointer, not the
  image bytes, so a passing database query never proves the file or URL still
  exists. No gallery picker or file-copy flow is included, since those are
  listed as optional extensions.

- **Delete rule.** `ON DELETE CASCADE` fits this lab because the spec defines a
  folder's cards as belonging to that folder — deleting Atlas should remove
  the leftover Atlas cards while leaving Harbor and Signal alone. In a clinic
  or billing system that rule would be dangerous, since deleting a patient
  must not silently erase audit records; there a RESTRICT, reassign, or
  archive policy plus a UI safeguard would be better. That comparison is
  defended with the observed Atlas/Harbor counts in DOCX prompt 2.

## Actual tests (Part II T1–T6 — fill with your real IDs/counts)

Run these in order with fictional sample data. Record the returned insert ID
or affected-row count for every write, and compare Part I IDs and values (not
just the count) before and after T1.

| Test | Action/input | Expected | Observed IDs/values/counts | Pass/fail |
| --- | --- | --- | --- | --- |
| T1a upgrade | Open v1 install with new helper; record PRAGMAs + Part I rows | Part I IDs/values kept, new tables + index exist | Part I before=[fill] after=[fill]; user_version=[fill], fk=[fill] | [ ] |
| T1b fresh | Launch v2 on separate disposable target | All tables created; empty folder opens clean | target=[fill] | [ ] |
| T2 create | Create Atlas + Harbor; add Compass x2 in Atlas, Signal (image NULL) in Harbor | 3 distinct card IDs; Atlas 2, Harbor 1 | Atlas ID=1, Harbor ID=2; Signal ID=1 (Harbor), Compass revised ID=2 + Compass ID=3 (Atlas); Atlas 2, Harbor 1 — see `evidence/T2_cards.png` | Pass |
| T3 edit | Edit one Compass by ID → Compass revised + notes, Save; edit other, Cancel | Save = 1 row, only chosen card changes; Cancel writes nothing | Edited ID=2 → "Compass revised" (Diamonds, "Notes for T3"), 1 row affected; ID=3 "Compass" (Clubs, no notes) unchanged; Cancel step not shown in screenshots | Pass (Save part; Cancel still needs a witnessed run) |
| T4 restart | Record IDs/counts, Force-stop (no Clear), relaunch same install | Same folders/IDs/counts, no reseed | before=[fill] after=[fill] — no post-restart screenshot yet | [ ] |
| T5 delete | Cancel card delete, confirm it; Cancel folder delete, confirm Atlas delete | Cancels change nothing; card delete = 1; folder delete = 1 parent + its cards, Harbor kept | deleted card=[fill], deleted folder=[fill] — not shown in screenshots | [ ] |
| T6 validation | Open Signal (NULL image) → fallback; try whitespace title, blank folder, duplicate Harbor | Fallback shows; all invalid give feedback, counts unchanged | Signal ID=1 shows heart fallback with "no notes" — see `evidence/T6_fallback.png`; invalid-input attempts not shown in screenshots | Partial (fallback shown; validation attempts still need recording) |

T4 method: [fill exact — Android: stop debug → App info → Force stop → relaunch / iOS: stop → app-switcher kill → `flutter run -d <id>` + target]
Release smoke test: [build cmd/result, install target, create/read/edit/delete + fallback + restart — observed]
Evidence: `evidence/T2_cards.png` (Atlas: Compass ID=3 + Compass revised ID=2), `evidence/T6_fallback.png` (Harbor: Signal ID=1 with suit fallback), `evidence/analysis_output.txt`. Still missing: `evidence/T1_before.png` (must be captured before upgrade — cannot reuse a later screenshot) and `evidence/T4_after.png` (post-restart).

Rubric map: schema + preservation → `database_helper.dart` + T1 rows; models/repo +
CRUD → models + helper + T2–T5; image + usability → fallback + T6; tests +
evidence → table above + `evidence/`; delivery → repo URL, APK, DOCX below.

Analyzer: `dart analyze lib` → No issues found (see `evidence/analysis_output.txt`).
Note: plain `flutter analyze` needs Windows Developer Mode for plugin symlinks,
so the recorded run uses `dart analyze lib`.

Known limitations: T1/T4/T5 and the invalid-input half of T6 are not yet evidenced — see blanks above. Screenshots also caught a UI text bug ("Updated card ID null (1 row)" — the row count was right but the ID printed null because the form was cleared before reading it); fixed in `catalogue_screen.dart` after the screenshots, needs one re-test to confirm the message now shows ID 2.

## Submission files (each student uploads all three to iCollege)

- `github_link.txt` with this repository URL (complete source + README + evidence).
- `Activity09_Lastname_Firstname.apk` built from `flutter build apk --release` and smoke-tested on a disposable target.
- `Lastname_Firstname_CriticalThinking.docx` with name, ID, pathway, prompts 1–3 plus two U-pool AI Lab answers (graduates: prompts 1–4 plus two G-pool answers), evidence references, and AI-use disclosure.

## Attribution

- Starter: course Part I schema + `sqflite`/`path_provider`/`path` deps; Flutter counter template replaced.
- My additions: v2 migration, models, catalogue UI, validation, fallback.
- References: Flutter SQLite cookbook, sqflite docs, SQLite foreign-keys docs.
- AI assistance: OpenCode for scaffolding.
