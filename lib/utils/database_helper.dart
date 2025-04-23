import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tibapay.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        middleName TEXT,
        lastName TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('cashier', 'accountant', 'admin')),
        status TEXT NOT NULL CHECK (status IN ('active', 'inactive')),
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE patients (
        patient_id INTEGER PRIMARY KEY AUTOINCREMENT,
        patientNumber TEXT NOT NULL UNIQUE,
        firstName TEXT NOT NULL,
        middleName TEXT,
        lastName TEXT NOT NULL,
        sponsor TEXT NOT NULL,
        phoneNumber TEXT,
        address TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        itemId TEXT PRIMARY KEY,
        itemName TEXT NOT NULL,
        itemCategory TEXT NOT NULL,
        itemPrice REAL NOT NULL,
        itemSponsor TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        paymentId TEXT PRIMARY KEY,
        paymentDate TEXT NOT NULL,
        patientId TEXT NOT NULL,
        createdBy TEXT NOT NULL,
        createdById INTEGER NOT NULL,
        sponsor TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        itemCategory TEXT NOT NULL,
        amount REAL NOT NULL,
        quantity INTEGER NOT NULL,
        isSynced INTEGER DEFAULT 0,
        department TEXT,
        status TEXT,
        patientName TEXT,
        phoneNumber TEXT,
        FOREIGN KEY (createdById) REFERENCES users (user_id)
      )
    ''');

    await _createDefaultAdmin(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE payments ADD COLUMN createdById INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE payments ADD COLUMN patientName TEXT');
      await db.execute('ALTER TABLE payments ADD COLUMN phoneNumber TEXT');
    }
  }

  Future<void> _createDefaultAdmin(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users')
    ) ?? 0;
  
    if (count == 0) {
      final admin = User(
        firstName: 'Admin',
        lastName: 'User',
        username: 'admin',
        passwordHash: hashPassword('admin123'),
        role: 'admin',
        status: 'active',
        createdAt: DateTime.now().toIso8601String(),
      );
      
      await db.insert('users', admin.toMap());
    }
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}