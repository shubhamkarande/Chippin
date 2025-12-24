/// User model for Chippin app.
class User {
  final String id;
  final String? firebaseUid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isGuest;
  final DateTime createdAt;

  User({
    required this.id,
    this.firebaseUid,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isGuest = false,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      firebaseUid: json['firebase_uid'],
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      isGuest: json['is_guest'] ?? json['isGuest'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'is_guest': isGuest,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// For SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'is_guest': isGuest ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      firebaseUid: map['firebase_uid'],
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      avatarUrl: map['avatar_url'],
      isGuest: map['is_guest'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  User copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isGuest,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get initials {
    if (displayName.isEmpty) return '?';
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }
}
