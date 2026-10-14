// A child card. Each card belongs to exactly one folder.
//
// Named CardRecord (not Card) so it never collides with
// Flutter's Material Card widget.
class CardRecord {
  final int? id;
  final String title;
  final String suit; // Hearts, Diamonds, Clubs, or Spades.
  final String notes; // '' when the user leaves notes empty.
  final String? imageRef; // Null means "no image" (shows fallback).
  final int folderId; // Parent folder id. Never 0 or missing.

  const CardRecord({
    this.id,
    required this.title,
    required this.suit,
    required this.notes,
    this.imageRef,
    required this.folderId,
  });

  factory CardRecord.fromMap(Map<String, dynamic> map) {
    final rawImage = map['image_ref'];
    return CardRecord(
      id: map['id'] as int?,
      title: (map['title'] ?? '').toString(),
      suit: (map['suit'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      imageRef: rawImage == null ? null : rawImage.toString(),
      folderId: (map['folder_id'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'suit': suit,
      'notes': notes,
      'image_ref': imageRef,
      'folder_id': folderId,
    };
  }
}
