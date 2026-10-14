# In-Class 08 / Fall Festival Roster

Student / course / pathway: [LastName, FirstName] / [Course + Section 2] / Undergraduate
Flutter / Dart versions: [e.g. Flutter 3.x.x / Dart 3.6.x — fill in from `flutter --version`]
Device / OS: [e.g. Pixel 7 API 34 emulator / Android 14 — fill in actual target]

Setup/run commands:

```sh
flutter pub get
flutter run
```

> Pre-lab was done outside the timebox: blank project created, sample
> dependency lines merged, `flutter pub get`, launched on Android/iOS target.
> Fully restart (not hot reload) after adding native plugins.

## Storage notes

- Schema and initialization: `MyDatabase.db`, version 1, `onCreate` makes
  `my_table(_id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL)`.
  One `DatabaseHelper()` instance is created in `main()`, `await helper.init()`
  joins the documents directory with `MyDatabase.db` before `runApp()`.
  First load runs from `RosterScreen.initState()`, never from `build()`.
- Input policy, IDs, CRUD source locations:
  - Name must be trimmed and non-empty; age must be `int.tryParse` integer
    0–130 inclusive. Blank names, decimals (`1.5`), non-numbers (`abc`), and
    out-of-range ages show field errors and write nothing.
  - SQLite auto-assigns `_id` on insert (omit `_id`); update/delete target the
    integer `_id` only, never name or list position. Both return affected-row
    counts (1 = success, 0 = row gone).
  - CRUD lives in `lib/database_helper.dart` (`insert`, `queryAllRows`,
    `queryRowCount`, `update`, `delete`); interaction/rendering lives in
    `lib/main.dart` (`_loadRows`, `_onSave`, `_onEdit`, `_onCancelEdit`,
    `_onDelete`).
- Memory example: current text-field input, `_rows` list, `_loading`/`_busy`
  flags — rebuilt every process start, not durable.
- Preference example (not implemented in this app): a theme or sort-order
  setting would suit key-value preferences; this roster needs relational rows,
  so it uses SQLite instead.
- SQLite example: a saved guest row such as `{_id: A, name: River, age: 21}`
  survives a genuine stop/relaunch via `queryAllRows()`.

## Actual tests

| Test | Action/input | Expected | Observed IDs/ages/count | Pass/fail |
| --- | --- | --- | --- | --- |
| T1 | Refresh lab roster with no rows | Count 0, empty-state message | count = 0 
| T2 | Add River, 21 then River, 34 | Count 2; distinct IDs A and B | A = [ ], B = [ ], count = 2

| T3 | Edit B to 99 then Cancel; edit B again, Save 35 | Cancel leaves B at 34; Save returns 1; A = 21, B = 35, count 2 | A age = 34, B age = 35, updated = 1 row
| T4 | Stop app process, relaunch same install without clearing data | Same IDs, names, ages, count; no reseeding 
| T5 | Cancel delete of A, then confirm; Refresh | Cancel leaves count 2; confirm returns 1; only B remains, count 1 | deleted = A, remaining = B, count = 1
| T6 | Invalid: (1) space-only name + 21; (2–5) Maple + abc / 1.5 / -1 / 131; valid: Acorn 0, Oak 130 | Each invalid shows feedback, count stays 1/B; Acorn + Oak accepted with distinct IDs; final count 3 | rejects = 1 (5 rows unchanged); Acorn ID = 3; Oak ID = 4; final count = 3

T4 stop/relaunch method: [Android: stop debug session → App info → Force stop (not Clear storage) → launcher icon / iOS: stop debugging → app-switcher kill → `flutter run -d <device-id>` — fill in exact method + target]

Evidence: `evidence/T4_before.png`, `evidence/T4_after.png`,
`evidence/T6_invalid.png`, `evidence/analysis_output.txt`

Analyzer command/result: `flutter analyze` →
Analyzing fall_guest_roster...                                  

   info • Use of 'return' in a 'finally' clause. Try restructuring the code • lib/main.dart:101:21 • control_flow_in_finally
   info • Use of 'return' in a 'finally' clause. Try restructuring the code • lib/main.dart:193:21 • control_flow_in_finally
   info • Use of 'return' in a 'finally' clause. Try restructuring the code • lib/main.dart:320:21 • control_flow_in_finally

3 issues found. (ran in 1.5s)


Known limitations: none found

## Reflections / Critical Thinking

1. Prediction (write BEFORE T4), then actual result/interpretation: Before T4 I
   predicted both River rows would survive relaunch because `main()` reopens
   the same `MyDatabase.db` via `helper.init()` and `RosterScreen.initState()`
   repopulates the list with `queryAllRows()`/`queryRowCount()` — memory is
   rebuilt, but the SQLite file persists. After a genuine stop/relaunch via
   [FILL: exact Force-stop / app-switcher method + device], the roster showed
   [FILL: IDs A/B, River 21/34-or-35, count] matching `evidence/T4_before.png`
   in `evidence/T4_after.png` with no reseeding. The path is
   `init()` → open/create `MyDatabase.db` → first query → `setState` renders
   rows/count. The SQLite-restore claim would be disproven if the after
   screenshot showed count 0, missing IDs, or required re-adding the Rivers.
2. My two IDs and update result; why identity matters: T2 created A = 1
   (River, 21) and B = 2 (River, 34); T3 Cancel left B at 34, and
   Save on B returned 1 row with count 2 (note: README currently lists A as
   35
   `lib/main.dart` (`_onSave` → `helper.update`) targets `where _id = ?` with
   the stored `_editingId`, so the integer key — not the shared name — picks
   the row. A name cannot distinguish two Rivers, and renaming one changes
   nothing about its key. Had I selected by list position after a sort (e.g.,
   tapping index 0 after ordering by age and editing the wrong River), the
   write would hit the unintended ID; storing the ID avoids that.
3. My self-walkthrough observation and proposed improvement: Walking
   Add/Edit/Cancel/Delete in T2–T5, I observed [FILL: one concrete UI moment,
   e.g., the Save/Delete confirmations naming the ID made the affected row
   unambiguous, though busy periods only grey out buttons]. One small
   improvement would be,  whose trade-off is clearer
   confirmation versus extra state/text to maintain — left unimplemented per
   scope. T6 proves validation because each rejected attempt (space-only name;
   Maple with abc, 1.5, -1, 131) showed field feedback and left the count at
   1 (B only), while Acorn 0 (ID 3) and Oak 130 (ID 4) were accepted for a
   final count of 3 (`evidence/T6_invalid.png`). No functional bug was found;
   limitation: none beyond the single-table, single-user local scope.

## Attribution

- Starter source: course `database_helper.txt` schema/API + sample `pubspec.yaml`
  lines (sqflite ^2.4.1, path_provider ^2.1.5, path ^1.9.0); generated Flutter
  counter template replaced; obsolete `test/widget_test.dart` removed per lab
  Step 1 (no replacement automated test required).
- My additions: `lib/main.dart` roster screen, validation, busy guards,
  feedback states; `lib/database_helper.dart` ordering (`_id ASC`) and
  instance-based init as specified.
- References: Flutter SQLite cookbook, sqflite docs, SQLite CREATE TABLE docs
  (consulted only as needed).
- AI assistance: OpenCode for scaffolding / testing assistance.
