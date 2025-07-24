class Member {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime joinedAt;

  Member({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      avatarUrl: map['avatarUrl'],
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt']),
    );
  }
}
