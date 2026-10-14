// A parent folder. One folder holds many cards.
class Folder {
  final int? id;
  final String name;
  final String createdAt; // ISO-8601 string from the database.
  final int cardCount; // From LEFT JOIN COUNT, 0 when empty.

  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  // Reads a row from getFoldersWithCounts().
  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      name: (map['name'] ?? '').toString(),
      createdAt: (map['created_at'] ?? '').toString(),
      cardCount: (map['card_count'] as int?) ?? 0,
    );
  }

  // Writes a folder (id is auto-assigned, so it is left out).
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'created_at': createdAt,
    };
  }
}
