import 'package:tiba_pay/models/item.dart';
import 'package:tiba_pay/utils/database_helper.dart';

class ItemRepository {
  final DatabaseHelper dbHelper;

  ItemRepository({required this.dbHelper});

  Future<List<Item>> getAllItems() async {
    final db = await dbHelper.database;
    final maps = await db.query('items', orderBy: 'itemName');
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  Future<List<Item>> getActiveItems() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'items',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'itemName',
    );
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  Future<List<Item>> getItemsByCategory(String category) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'items',
      where: 'itemCategory = ? AND isActive = ?',
      whereArgs: [category, 1],
      orderBy: 'itemName',
    );
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  Future<void> addItem(Item item) async {
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
}