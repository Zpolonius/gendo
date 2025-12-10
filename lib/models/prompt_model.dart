class PromptModel {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromptModel({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory PromptModel.fromMap(Map<String, dynamic> map, String docId) {
    return PromptModel(
      id: docId, // Vi bruger dokumentets ID fra Firestore
      title: map['title'] ?? 'Uden titel',
      content: map['content'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  // Helper til at lave en kopi med ændringer (Immutability)
  PromptModel copyWith({
    String? title,
    String? content,
    List<String>? tags,
  }) {
    return PromptModel(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(), // Opdater altid timestamp ved ændring
    );
  }
}