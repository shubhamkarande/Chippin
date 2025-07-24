class Group {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final String createdBy;
  final List<String> memberIds;
  final String? inviteCode;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    required this.memberIds,
    this.inviteCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'createdBy': createdBy,
      'memberIds': memberIds.join(','),
      'inviteCode': inviteCode,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      createdBy: map['createdBy'],
      memberIds: map['memberIds']
          .toString()
          .split(',')
          .where((id) => id.isNotEmpty)
          .toList(),
      inviteCode: map['inviteCode'],
    );
  }
}
