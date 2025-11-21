class TodoList {
  final String id;
  final String title;
  final String ownerId;
  final List<String> memberIds;
  final DateTime createdAt;

  TodoList({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TodoList.fromMap(Map<String, dynamic> map) {
    return TodoList(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Ny Liste',
      ownerId: map['ownerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}