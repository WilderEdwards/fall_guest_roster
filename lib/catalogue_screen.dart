import 'package:flutter/material.dart';

import 'card_record.dart';
import 'database_helper.dart';
import 'folder.dart';

/// Folders + cards screen (Part II).
/// Uses only DatabaseHelper methods — no SQL strings live here.
class CatalogueScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const CatalogueScreen({super.key, required this.helper});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  static const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

  final TextEditingController _folderController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

  List<Folder> _folders = [];
  List<CardRecord> _cards = [];
  int? _openFolderId;

  String _chosenSuit = 'Hearts';
  int? _chosenFolderId; // Folder picked in the card form.
  int? _editingCardId;

  bool _loading = true;
  bool _busy = false;
  String? _readError;
  String? _feedback;
  String? _folderError;
  String? _titleError;

  bool get _isBusy => _busy || _loading;
  bool get _isEditingCard => _editingCardId != null;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _folderController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  // Converts a suit name to a stable text symbol for the fallback.
  String _suitSymbol(String suit) {
    switch (suit) {
      case 'Hearts':
        return '♥';
      case 'Diamonds':
        return '♦';
      case 'Clubs':
        return '♣';
      case 'Spades':
        return '♠';
      default:
        return '•';
    }
  }

  Future<void> _loadFolders() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _readError = null;
    });
    try {
      final rows = await widget.helper.getFoldersWithCounts();
      final folders = rows.map(Folder.fromMap).toList();
      List<CardRecord> cards = [];
      if (_openFolderId != null) {
        final cardRows = await widget.helper.getCards(_openFolderId!);
        cards = cardRows.map(CardRecord.fromMap).toList();
        // If the open folder was deleted elsewhere, close it.
        if (!folders.any((f) => f.id == _openFolderId)) {
          _openFolderId = null;
          cards = [];
        }
      }
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _cards = cards;
      });
    } catch (error, stackTrace) {
      debugPrint('Catalogue read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _readError = 'Could not read folders. Check logs and try Refresh.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openFolder(int folderId) async {
    if (_isBusy) return;
    if (!mounted) return;
    setState(() {
      _openFolderId = folderId;
      _loading = true;
      _readError = null;
    });
    try {
      final rows = await widget.helper.getCards(folderId);
      if (!mounted) return;
      setState(() {
        _cards = rows.map(CardRecord.fromMap).toList();
      });
    } catch (error, stackTrace) {
      debugPrint('Open folder failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _readError = 'Could not open that folder. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _onCreateFolder() async {
    if (_isBusy) return;
    final name = _folderController.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      setState(() {
        _folderError = 'Enter a non-empty folder name.';
        _feedback = 'Folder not created; fix the name first.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _folderError = null;
      _feedback = null;
    });
    try {
      final id = await widget.helper.insertFolder(name);
      _folderController.clear();
      if (!mounted) return;
      setState(() {
        _feedback = 'Created folder "$name" with ID $id.';
      });
      await _loadFolders();
    } catch (error, stackTrace) {
      debugPrint('Insert folder failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        // UNIQUE is case-sensitive: "Harbor" and "harbor" are different.
        // Never use replace to bypass it — that could wipe child cards.
        _feedback = 'Could not create folder. That name may already exist.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _onDeleteFolder(Folder folder) async {
    if (_isBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete "${folder.name}" (ID ${folder.id}) and its '
          '${folder.cardCount} card(s)? This cannot be undone.',
        ),
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
    if (confirmed != true) {
      if (!mounted) return;
      setState(() {
        _feedback = 'Folder deletion cancelled; nothing was deleted.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      final deleted = await widget.helper.deleteFolder(folder.id!);
      if (deleted == 0) {
        if (!mounted) return;
        setState(() {
          _feedback = 'Folder was already gone (0 rows deleted).';
        });
        await _loadFolders();
        return;
      }
      if (_openFolderId == folder.id && mounted) {
        setState(() {
          _openFolderId = null;
          _cards = [];
        });
      }
      if (!mounted) return;
      setState(() {
        _feedback =
            'Deleted folder "${folder.name}" (1 row) and its cards (cascade).';
      });
      await _loadFolders();
    } catch (error, stackTrace) {
      debugPrint('Delete folder failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _feedback = 'Folder delete failed. Check the logs.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  bool _validateCard() {
    final title = _titleController.text.trim();
    String? titleError;
    if (title.isEmpty) {
      // Whitespace-only titles are rejected here; NOT NULL alone
      // would not catch "   ".
      titleError = 'Enter a non-empty card title.';
    }
    if (!mounted) return false;
    setState(() {
      _titleError = titleError;
    });
    if (titleError != null) return false;
    if (_chosenFolderId == null) {
      if (!mounted) return false;
      setState(() {
        _feedback = 'Pick an existing folder for this card.';
      });
      return false;
    }
    return true;
  }

  Future<void> _onSaveCard() async {
    if (_isBusy) return;
    if (!_validateCard()) {
      if (mounted) {
        setState(() {
          _feedback = 'Fix the highlighted fields; nothing was saved.';
        });
      }
      return;
    }
    final title = _titleController.text.trim();
    // Notes are optional: store '' when omitted.
    final notes = _notesController.text.trim();
    // Image is optional: store NULL when omitted, not an empty string.
    final rawImage = _imageController.text.trim();
    final String? imageRef = rawImage.isEmpty ? null : rawImage;
    final folderId = _chosenFolderId!;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      if (_isEditingCard) {
        final affected = await widget.helper.updateCard(
          id: _editingCardId!,
          title: title,
          suit: _chosenSuit,
          notes: notes,
          imageRef: imageRef,
          folderIdValue: folderId,
        );
        if (affected == 0) {
          if (!mounted) return;
          setState(() {
            _feedback = 'That card no longer exists (0 rows updated).';
          });
          await _loadFolders();
          return;
        }
        final int editedId = _editingCardId!;
        _clearCardForm();
        if (!mounted) return;
        setState(() {
          _feedback = 'Updated card ID $editedId (1 row).';
        });
        await _loadFolders();
      } else {
        final id = await widget.helper.insertCard(
          title: title,
          suit: _chosenSuit,
          notes: notes,
          imageRef: imageRef,
          folderIdValue: folderId,
        );
        _clearCardForm();
        if (!mounted) return;
        setState(() {
          _feedback = 'Added "$title" with ID $id.';
        });
        await _loadFolders();
      }
    } catch (error, stackTrace) {
      debugPrint('Save card failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        // Keep what the user typed so nothing is lost on failure.
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

  void _clearCardForm() {
    _titleController.clear();
    _notesController.clear();
    _imageController.clear();
    _editingCardId = null;
    _titleError = null;
    _chosenSuit = 'Hearts';
    // Keep _chosenFolderId so adding several cards to one folder is fast.
  }

  void _onEditCard(CardRecord card) {
    if (_isBusy) return;
    if (!mounted) return;
    setState(() {
      _editingCardId = card.id;
      _titleController.text = card.title;
      _notesController.text = card.notes;
      _imageController.text = card.imageRef ?? '';
      _chosenSuit = suits.contains(card.suit) ? card.suit : 'Hearts';
      _chosenFolderId = card.folderId;
      _titleError = null;
      _feedback = 'Editing card ID ${card.id}. Save applies, Cancel discards.';
    });
  }

  void _onCancelCardEdit() {
    if (_isBusy) return;
    if (!mounted) return;
    setState(() {
      // Cancel writes nothing to the database.
      _clearCardForm();
      _feedback = 'Card edit cancelled; nothing was written.';
    });
  }

  Future<void> _onDeleteCard(CardRecord card) async {
    if (_isBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text(
          'Delete "${card.title}" (ID ${card.id})? This cannot be undone.',
        ),
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
    if (confirmed != true) {
      if (!mounted) return;
      setState(() {
        _feedback = 'Card deletion cancelled; nothing was deleted.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      final deleted = await widget.helper.deleteCard(card.id!);
      if (deleted == 0) {
        if (!mounted) return;
        setState(() {
          _feedback = 'Card was already gone (0 rows deleted).';
        });
        await _loadFolders();
        return;
      }
      if (_editingCardId == card.id && mounted) {
        setState(() {
          _clearCardForm();
        });
      }
      if (!mounted) return;
      setState(() {
        _feedback = 'Deleted card ID ${card.id} (1 row).';
      });
      await _loadFolders();
    } catch (error, stackTrace) {
      debugPrint('Delete card failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _feedback = 'Card delete failed. Check the logs.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // Shows artwork when the reference works, else a suit symbol.
  // A path/URL is only a reference — it proves nothing about the file.
  Widget _cardImage(CardRecord card) {
    final ref = card.imageRef;
    if (ref == null || ref.trim().isEmpty) {
      return _fallbackAvatar(card.suit);
    }
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      return Image.network(
        ref,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallbackAvatar(card.suit);
        },
        errorBuilder: (context, error, stackTrace) {
          return _fallbackAvatar(card.suit);
        },
      );
    }
    // Bundled asset or file path: try it, fall back to the suit symbol.
    // Missing files must never crash the list.
    return Image.asset(
      ref,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _fallbackAvatar(card.suit);
      },
    );
  }

  Widget _fallbackAvatar(String suit) {
    return CircleAvatar(
      child: Text(
        _suitSymbol(suit),
        style: const TextStyle(fontSize: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Catalogue')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading && _folders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadFolders,
                child: ListView(
                  children: [
                    // Folder creation.
                    TextField(
                      controller: _folderController,
                      enabled: !_isBusy,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'New folder name',
                        hintText: 'e.g. Atlas',
                        errorText: _folderError,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isBusy ? null : _onCreateFolder,
                      child: const Text('Add folder'),
                    ),
                    const SizedBox(height: 12),
                    Text('Folders: ${_folders.length}'),
                    if (_feedback != null) ...[
                      const SizedBox(height: 4),
                      Text(_feedback!),
                    ],
                    if (_readError != null) ...[
                      const SizedBox(height: 4),
                      Text(_readError!),
                      TextButton(
                        onPressed: _isBusy ? null : _loadFolders,
                        child: const Text('Retry'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_folders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No folders yet — create Atlas or Harbor to begin.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ..._folders.map((folder) {
                        final selected = folder.id == _openFolderId;
                        return Card(
                          color: selected ? Colors.amber.shade50 : null,
                          child: ListTile(
                            title: Text(folder.name),
                            subtitle: Text(
                              'ID: ${folder.id} • Cards: ${folder.cardCount}',
                            ),
                            selected: selected,
                            onTap: folder.id == null
                                ? null
                                : () => _openFolder(folder.id!),
                            trailing: IconButton(
                              tooltip: 'Delete folder',
                              icon: const Icon(Icons.delete),
                              onPressed: _isBusy
                                  ? null
                                  : () => _onDeleteFolder(folder),
                            ),
                          ),
                        );
                      }),
                    const Divider(height: 32),
                    // Cards in the open folder.
                    if (_openFolderId == null)
                      const Text(
                        'Tap a folder to see its cards.',
                        textAlign: TextAlign.center,
                      )
                    else ...[
                      Text(
                        'Cards in folder ID $_openFolderId: ${_cards.length}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_cards.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'This folder is empty — add its first card below.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._cards.map((card) {
                          return ListTile(
                            leading: _cardImage(card),
                            title: Text(card.title),
                            subtitle: Text(
                              'ID: ${card.id} • ${card.suit} • '
                              '${card.notes.isEmpty ? "no notes" : card.notes}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit),
                                  onPressed: _isBusy
                                      ? null
                                      : () => _onEditCard(card),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete),
                                  onPressed: _isBusy
                                      ? null
                                      : () => _onDeleteCard(card),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      Text(
                        _isEditingCard
                            ? 'Edit card ID $_editingCardId'
                            : 'Add a card',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextField(
                        controller: _titleController,
                        enabled: !_isBusy,
                        decoration: InputDecoration(
                          labelText: 'Card title',
                          hintText: 'e.g. Compass',
                          errorText: _titleError,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _chosenSuit,
                        decoration:
                            const InputDecoration(labelText: 'Suit'),
                        items: suits
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('$s ${_suitSymbol(s)}'),
                                ))
                            .toList(),
                        onChanged: _isBusy
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _chosenSuit = value;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _chosenFolderId,
                        decoration:
                            const InputDecoration(labelText: 'Folder'),
                        items: _folders
                            .where((f) => f.id != null)
                            .map((f) => DropdownMenuItem(
                                  value: f.id!,
                                  child: Text('${f.name} (ID ${f.id})'),
                                ))
                            .toList(),
                        onChanged: _isBusy
                            ? null
                            : (value) {
                                setState(() {
                                  _chosenFolderId = value;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        enabled: !_isBusy,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _imageController,
                        enabled: !_isBusy,
                        decoration: const InputDecoration(
                          labelText: 'Image ref (optional, URL or asset)',
                          hintText: 'Leave empty for suit fallback',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: _isBusy ? null : _onSaveCard,
                            child: Text(
                                _isEditingCard ? 'Save' : 'Add card'),
                          ),
                          OutlinedButton(
                            onPressed: (_isEditingCard && !_isBusy)
                                ? _onCancelCardEdit
                                : null,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
