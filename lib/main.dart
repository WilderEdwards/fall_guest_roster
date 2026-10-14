import 'package:flutter/material.dart';

import 'catalogue_screen.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Could not open local storage. Restart the app and check the logs.',
          ),
        ),
      ),
    ));
    return;
  }
  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;

  const DirectoryApp({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Festival Roster',
      home: HomeShell(helper: helper),
    );
  }
}

class HomeShell extends StatefulWidget {
  final DatabaseHelper helper;

  const HomeShell({super.key, required this.helper});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      RosterScreen(helper: widget.helper),
      CatalogueScreen(helper: widget.helper),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Guests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Folders',
          ),
        ],
        onTap: (value) {
          setState(() {
            _index = value;
          });
        },
      ),
    );
  }
}

class RosterScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const RosterScreen({super.key, required this.helper});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  bool _loading = true;
  bool _busy = false;
  String? _readError;
  String? _feedback;
  String? _nameError;
  String? _ageError;
  int? _editingId;

  bool get _isBusy => _busy || _loading;
  bool get _isEditing => _editingId != null;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadRows() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _readError = null;
    });
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _count = count;
      });
    } catch (error, stackTrace) {
      debugPrint('Read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _readError =
            'Could not read the roster. Check the logs and try Refresh.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Validates the form. Returns null when invalid (and sets field errors).
  /// Invalid input must never reach the database.
  ({String name, int age})? _validate() {
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();

    String? nameError;
    String? ageError;

    if (name.isEmpty) {
      nameError = 'Enter a non-empty name.';
    }

    final age = int.tryParse(ageText);
    if (age == null) {
      ageError = 'Enter a whole number from 0 to 130.';
    } else if (age < 0 || age > 130) {
      ageError = 'Age must be 0–130 inclusive.';
    }

    if (!mounted) return null;
    setState(() {
      _nameError = nameError;
      _ageError = ageError;
    });

    if (nameError != null || ageError != null) return null;
    return (name: name, age: age!);
  }

  Future<void> _onSave() async {
    if (_isBusy) return;
    final valid = _validate();
    if (valid == null) {
      if (mounted) {
        setState(() {
          _feedback = 'Fix the highlighted fields; nothing was saved.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      if (_isEditing) {
        final updated = await widget.helper.update({
          DatabaseHelper.columnId: _editingId,
          DatabaseHelper.columnName: valid.name,
          DatabaseHelper.columnAge: valid.age,
        });
        if (updated == 0) {
          if (!mounted) return;
          setState(() {
            _feedback =
                'That record no longer exists (0 rows updated). Reloading.';
          });
          await _reloadAfterWrite(
              successMessage: null, notFound: true);
          return;
        }
        await _reloadAfterWrite(
          successMessage: 'Updated ID $_editingId (1 row).',
          clearForm: true,
        );
      } else {
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: valid.name,
          DatabaseHelper.columnAge: valid.age,
        });
        await _reloadAfterWrite(
          successMessage: 'Added ${valid.name} with ID $id.',
          clearForm: true,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        // Preserve user input on a failed write.
        _feedback = 'Save failed. Check the logs and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  /// Re-queries after a successful write. Never repeats the write itself.
  Future<void> _reloadAfterWrite(
      {String? successMessage,
      bool clearForm = false,
      bool notFound = false}) async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _count = count;
        _readError = null;
        if (successMessage != null) _feedback = successMessage;
        if (clearForm) _clearForm();
      });
    } catch (error, stackTrace) {
      debugPrint('Refresh after write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _feedback = notFound
            ? 'Record not found. Saved state is unclear — press Refresh.'
            : 'Saved, but refresh failed. Press Refresh to reload.';
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    _ageController.clear();
    _editingId = null;
    _nameError = null;
    _ageError = null;
  }

  void _onEdit(Map<String, dynamic> row) {
    if (_isBusy) return;
    final id = row[DatabaseHelper.columnId] as int;
    if (!mounted) return;
    setState(() {
      _editingId = id;
      _nameController.text = (row[DatabaseHelper.columnName] ?? '').toString();
      _ageController.text = (row[DatabaseHelper.columnAge] ?? '').toString();
      _nameError = null;
      _ageError = null;
      _feedback = 'Editing ID $id. Save applies, Cancel discards.';
    });
  }

  void _onCancelEdit() {
    if (_isBusy) return;
    if (!mounted) return;
    setState(() {
      // Cancel writes nothing.
      _clearForm();
      _feedback = 'Edit cancelled; nothing was written.';
    });
  }

  Future<void> _onDelete(Map<String, dynamic> row) async {
    if (_isBusy) return;
    final id = row[DatabaseHelper.columnId] as int;
    final name = (row[DatabaseHelper.columnName] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete ID $id ($name)? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    // Cancel writes nothing.
    if (confirmed != true) {
      if (!mounted) return;
      setState(() {
        _feedback = 'Deletion cancelled; nothing was deleted.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      final deleted = await widget.helper.delete(id);
      if (deleted == 0) {
        if (!mounted) return;
        setState(() {
          _feedback = 'ID $id was already gone (0 rows deleted). Reloading.';
        });
        await _reloadAfterWrite(successMessage: null, notFound: true);
        return;
      }
      await _reloadAfterWrite(
        successMessage: 'Deleted ID $id (1 row).',
        clearForm: _editingId == id,
      );
      // If the deleted row was being edited, the edit selection is cleared.
      if (_editingId == id && mounted) {
        setState(() {
          _editingId = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _feedback = 'Delete failed. Check the logs and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_isBusy,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Guest name',
                hintText: 'e.g. River',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              enabled: !_isBusy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Guest age (0–130)',
                hintText: 'e.g. 21',
                errorText: _ageError,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isBusy ? null : _onSave,
                  child: Text(_isEditing ? 'Save' : 'Add'),
                ),
                OutlinedButton(
                  onPressed:
                      (_isEditing && !_isBusy) ? _onCancelEdit : null,
                  child: const Text('Cancel edit'),
                ),
                OutlinedButton(
                  onPressed: _isBusy ? null : _loadRows,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Records: $_count'),
            if (_feedback != null) ...[
              const SizedBox(height: 4),
              Text(_feedback!),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_readError != null) {
      return Center(
        child: Text(_readError!),
      );
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text(
          'No festival guests yet — the cider stand is waiting for its first guest!',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final row = _rows[index];
        final id = row[DatabaseHelper.columnId];
        final name = (row[DatabaseHelper.columnName] ?? '').toString();
        final age = row[DatabaseHelper.columnAge];
        return ListTile(
          title: Text(name),
          subtitle: Text('ID: $id • Age: $age'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit),
                onPressed: _isBusy ? null : () => _onEdit(row),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete),
                onPressed: _isBusy ? null : () => _onDelete(row),
              ),
            ],
          ),
        );
      },
    );
  }
}
