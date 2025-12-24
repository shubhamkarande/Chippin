import 'user.dart';

/// Group model for expense sharing.
class Group {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final User? owner;
  final List<GroupMember> members;
  final String inviteCode;
  final String currency;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  Group({
    required this.id,
    required this.name,
    this.description = '',
    required this.ownerId,
    this.owner,
    this.members = const [],
    required this.inviteCode,
    this.currency = 'INR',
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      ownerId: json['owner'] ?? json['owner_id'] ?? '',
      owner: json['owner_details'] != null
          ? User.fromJson(json['owner_details'])
          : null,
      members: (json['memberships'] as List<dynamic>?)
              ?.map((m) => GroupMember.fromJson(m))
              .toList() ??
          [],
      inviteCode: json['invite_code'] ?? json['inviteCode'] ?? '',
      currency: json['currency'] ?? 'INR',
      imageUrl: json['image_url'] ?? json['imageUrl'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      synced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'owner': ownerId,
      'invite_code': inviteCode,
      'currency': currency,
      'image_url': imageUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'owner_id': ownerId,
      'invite_code': inviteCode,
      'currency': currency,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      ownerId: map['owner_id'],
      inviteCode: map['invite_code'],
      currency: map['currency'] ?? 'INR',
      imageUrl: map['image_url'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      synced: map['synced'] == 1,
    );
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    User? owner,
    List<GroupMember>? members,
    String? inviteCode,
    String? currency,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      owner: owner ?? this.owner,
      members: members ?? this.members,
      inviteCode: inviteCode ?? this.inviteCode,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  int get memberCount => members.length;
}

/// Group member with role.
class GroupMember {
  final String id;
  final User? user;
  final String userId;
  final String role;
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    this.user,
    required this.userId,
    this.role = 'member',
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      userId: json['user']?['id'] ?? json['user_id'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';
}
