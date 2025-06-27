import '../models/item.dart';
import '../utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class ItemRepository {
  final DatabaseHelper dbHelper;

  ItemRepository({required this.dbHelper});

  Future<List<Item>> getAllItems({
    int? limit,
    int? offset,
    String? searchQuery,
    String? category,
    String? sponsor,
    bool? isActive,
  }) async {
    final db = await dbHelper.database;
    
    // Build where clause based on filters
    var where = '1 = 1';
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (itemName LIKE ? OR itemCategory LIKE ? OR itemSponsor LIKE ?)';
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll([searchTerm, searchTerm, searchTerm]);
    }

    if (category != null && category != 'All') {
      where += ' AND itemCategory = ?';
      whereArgs.add(category);
    }

    if (sponsor != null && sponsor != 'All') {
      where += ' AND itemSponsor = ?';
      whereArgs.add(sponsor);
    }

    if (isActive != null) {
      where += ' AND isActive = ?';
      whereArgs.add(isActive ? 1 : 0);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  Future<int> getItemsCount({
    String? searchQuery,
    String? category,
    String? sponsor,
    bool? isActive,
  }) async {
    final db = await dbHelper.database;
    
    // Build where clause based on filters
    var where = '1 = 1';
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (itemName LIKE ? OR itemCategory LIKE ? OR itemSponsor LIKE ?)';
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll([searchTerm, searchTerm, searchTerm]);
    }

    if (category != null && category != 'All') {
      where += ' AND itemCategory = ?';
      whereArgs.add(category);
    }

    if (sponsor != null && sponsor != 'All') {
      where += ' AND itemSponsor = ?';
      whereArgs.add(sponsor);
    }

    if (isActive != null) {
      where += ' AND isActive = ?';
      whereArgs.add(isActive ? 1 : 0);
    }

    final count = await db.rawQuery('SELECT COUNT(*) FROM items WHERE $where', whereArgs);
    return Sqflite.firstIntValue(count) ?? 0;
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

  Future<void> insertItemsBatch(List<Item> items) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    
    for (var item in items) {
      batch.insert('items', item.toMap());
    }
    
    await batch.commit();
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

  Future<List<String>> getDistinctCategories() async {
    final db = await dbHelper.database;
    final result = await db.rawQuery('SELECT DISTINCT itemCategory FROM items');
    return result.map((e) => e['itemCategory'] as String).toList();
  }

  Future<List<String>> getDistinctSponsors() async {
    final db = await dbHelper.database;
    final result = await db.rawQuery('SELECT DISTINCT itemSponsor FROM items');
    return result.map((e) => e['itemSponsor'] as String).toList();
  }
}