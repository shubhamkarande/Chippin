import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database_helper.dart';
import '../../models/group.dart';
import '../../models/user.dart';

/// Repository for Group CRUD operations in local SQLite database.
class GroupRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  /// Get all groups for current user
  Future<List<Group>> getGroups(String userId) async {
    final db = await _dbHelper.database;
    
    // Get groups where user is a member
    final groupIds = await db.rawQuery('''
      SELECT group_id FROM group_members WHERE user_id = ?
    ''', [userId]);

    if (groupIds.isEmpty) return [];

    final ids = groupIds.map((g) => g['group_id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(',');

    final results = await db.query(
      'groups',
      where: 'id IN ($placeholders) AND is_active = 1',
      whereArgs: ids,
      orderBy: 'updated_at DESC',
    );

    final groups = <Group>[];
    for (final row in results) {
      final members = await _getGroupMembers(row['id'] as String);
      groups.add(Group.fromMap(row).copyWith(members: members));
    }

    return groups;
  }

  /// Get single group by ID
  Future<Group?> getGroup(String groupId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );

    if (results.isEmpty) return null;

    final members = await _getGroupMembers(groupId);
    return Group.fromMap(results.first).copyWith(members: members);
  }

  /// Get group by invite code
  Future<Group?> getGroupByInviteCode(String inviteCode) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'groups',
      where: 'invite_code = ? AND is_active = 1',
      whereArgs: [inviteCode],
    );

    if (results.isEmpty) return null;

    final members = await _getGroupMembers(results.first['id'] as String);
    return Group.fromMap(results.first).copyWith(members: members);
  }

  /// Create new group
  Future<Group> createGroup({
    required String name,
    required String ownerId,
    String description = '',
    String currency = 'INR',
    String? imageUrl,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final groupId = _uuid.v4();
    final inviteCode = _generateInviteCode();

    final group = Group(
      id: groupId,
      name: name,
      description: description,
      ownerId: ownerId,
      inviteCode: inviteCode,
      currency: currency,
      imageUrl: imageUrl,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      synced: false,
    );

    await db.insert('groups', group.toMap());

    // Add owner as member
    await addMember(
      groupId: groupId,
      userId: ownerId,
      role: 'owner',
    );

    // Add pending sync
    await _dbHelper.addPendingSync(
      entityType: 'group',
      entityId: groupId,
      operation: 'create',
      data: group.toJson(),
    );

    return group.copyWith(members: await _getGroupMembers(groupId));
  }

  /// Update group
  Future<Group> updateGroup(Group group) async {
    final db = await _dbHelper.database;
    final updatedGroup = group.copyWith(
      updatedAt: DateTime.now(),
      synced: false,
    );

    await db.update(
      'groups',
      updatedGroup.toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );

    // Add pending sync
    await _dbHelper.addPendingSync(
      entityType: 'group',
      entityId: group.id,
      operation: 'update',
      data: updatedGroup.toJson(),
    );

    return updatedGroup;
  }

  /// Delete group (soft delete)
  Future<void> deleteGroup(String groupId) async {
    final db = await _dbHelper.database;
    await db.update(
      'groups',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [groupId],
    );

    // Add pending sync
    await _dbHelper.addPendingSync(
      entityType: 'group',
      entityId: groupId,
      operation: 'delete',
      data: {'id': groupId},
    );
  }

  /// Add member to group
  Future<void> addMember({
    required String groupId,
    required String userId,
    String role = 'member',
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      'group_members',
      {
        'id': _uuid.v4(),
        'group_id': groupId,
        'user_id': userId,
        'role': role,
        'joined_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Remove member from group
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final db = await _dbHelper.database;
    await db.delete(
      'group_members',
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
  }

  /// Get group members
  Future<List<GroupMember>> _getGroupMembers(String groupId) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT 
        gm.id, gm.group_id, gm.user_id, gm.role, gm.joined_at,
        u.display_name, u.email, u.avatar_url
      FROM group_members gm
      LEFT JOIN users u ON gm.user_id = u.id
      WHERE gm.group_id = ?
    ''', [groupId]);

    return results.map((row) {
      return GroupMember(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        user: row['display_name'] != null
            ? User(
                id: row['user_id'] as String,
                email: row['email'] as String? ?? '',
                displayName: row['display_name'] as String? ?? '',
                avatarUrl: row['avatar_url'] as String?,
                createdAt: DateTime.now(),
              )
            : null,
        role: row['role'] as String? ?? 'member',
        joinedAt: DateTime.parse(row['joined_at'] as String),
      );
    }).toList();
  }

  /// Save/update user in local database
  Future<void> saveUser(User user) async {
    final db = await _dbHelper.database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Sync groups from server
  Future<void> syncGroups(List<Group> groups, String currentUserId) async {
    final db = await _dbHelper.database;

    for (final group in groups) {
      // Save group
      await db.insert(
        'groups',
        group.copyWith(synced: true).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Save members
      for (final member in group.members) {
        if (member.user != null) {
          await saveUser(member.user!);
        }
        await addMember(
          groupId: group.id,
          userId: member.userId,
          role: member.role,
        );
      }
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (i) => chars[(random + i * 7) % chars.length]).join();
  }
}
