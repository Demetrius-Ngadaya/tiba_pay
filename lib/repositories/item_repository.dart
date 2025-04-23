import '../models/item.dart';
import '../utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class ItemRepository {
  final DatabaseHelper dbHelper;

  ItemRepository({required this.dbHelper});

  Future<List<Item>> getAllItems() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('items');
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  Future<List<Item>> getActiveItems() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  Future<void> insertItem(Item item) async {
    final db = await dbHelper.database;
    await db.insert('items', item.toMap());
  }

  Future<void> updateItem(Item item) async {
    final db = await dbHelper.database;
    await db.update(
      'items',
      item.toMap(),
      where: 'itemId = ?',
      whereArgs: [item.itemId],
    );
  }

  Future<void> deleteItem(String itemId) async {
    final db = await dbHelper.database;
    await db.delete(
      'items',
      where: 'itemId = ?',
      whereArgs: [itemId],
    );
  }

  Future<Item?> getItemById(String itemId) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'itemId = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Item.fromMap(maps.first);
    }
    return null;
  }
}