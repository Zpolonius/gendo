class TodoList {
  final String id;
  final String title;
  final String ownerId;
  final List<String> memberIds;
  final List<String> pendingEmails;
  final DateTime createdAt;
  final int order; // NYT FELT: Til sortering

  TodoList({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.memberIds,
    this.pendingEmails = const [],
    required this.createdAt,
    this.order = 0, // Default værdi
  });

  TodoList copyWith({
    String? id,
    String? title,
    String? ownerId,
    List<String>? memberIds,
    List<String>? pendingEmails,
    DateTime? createdAt,
    int? order,
  }) {
    return TodoList(
      id: id ?? this.id,
      title: title ?? this.title,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      pendingEmails: pendingEmails ?? this.pendingEmails,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'pendingEmails': pendingEmails, 
      'createdAt': createdAt.millisecondsSinceEpoch,
      'order': order,
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
      order: map['order'] ?? 0,
    );
  }
}