class TodoList {
  final String id;
  final String title;
  final String ownerId;
  final List<String> memberIds;
  final List<String> pendingEmails;
  final DateTime createdAt;
  final bool showCompleted; // NYT FELT

  TodoList({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.memberIds,
    this.pendingEmails = const [],
    required this.createdAt,
    this.showCompleted = false, // Standard: Skjul færdige (false = vis ikke)
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'pendingEmails': pendingEmails, 
      'createdAt': createdAt.millisecondsSinceEpoch,
      'showCompleted': showCompleted, // Gem indstilling
    };
  }

  factory TodoList.fromMap(Map<String, dynamic> map) {
    return TodoList(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Ny Liste',
      ownerId: map['ownerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      pendingEmails: List<String>.from(map['pendingEmails'] ?? []), 
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      showCompleted: map['showCompleted'] ?? false, // Default til false for eksisterende lister
    );
  }

  // Helper til at kopiere objektet med ændringer
  TodoList copyWith({
    String? title,
    List<String>? memberIds,
    List<String>? pendingEmails,
    bool? showCompleted,
  }) {
    return TodoList(
      id: id,
      title: title ?? this.title,
      ownerId: ownerId,
      memberIds: memberIds ?? this.memberIds,
      pendingEmails: pendingEmails ?? this.pendingEmails,
      createdAt: createdAt,
      showCompleted: showCompleted ?? this.showCompleted,
    );
  }
}