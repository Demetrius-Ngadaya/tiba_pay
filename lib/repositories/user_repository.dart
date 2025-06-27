import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/utils/database_helper.dart';

class UserRepository {
  final DatabaseHelper dbHelper;

  UserRepository({required this.dbHelper});

  Future<int> createUser(User user) async {
    final db = await dbHelper.database;
    return await db.insert('users', user.toMap());
  }
  
  Future<User?> getUser(int id) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await dbHelper.database;
    final maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromMap(maps[i]));
  }

  Future<int> updateUser(User user) async {
    final db = await dbHelper.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'users',
      where: 'user_id = ?',
      whereArgs: [id],
    );
  }

  Future<User?> authenticate(String username, String password) async {
    final db = await dbHelper.database;
    
    // First get the user by username only
    final userMaps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );

    if (userMaps.isEmpty) return null;

    final user = User.fromMap(userMaps.first);
    
    // Verify password hash
    final inputHash = DatabaseHelper.hashPassword(password);
    
    if (inputHash == user.passwordHash && user.status == 'active') {
      return user;
    }
    
    return null;
  }

  Future<bool> usernameExists(String username) async {
    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT 1 FROM users WHERE username = ? LIMIT 1',
      [username],
    );
    return result.isNotEmpty;
  }
}