import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static const _dbName = 'shegong.db';
  static const _dbVersion = 2;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    Directory? ext = await getExternalStorageDirectory();
    String dbDir;
    if (ext != null) {
      dbDir = join(ext.path, 'database');
      await Directory(dbDir).create(recursive: true);
    } else {
      dbDir = await getDatabasesPath();
    }
    final path = join(dbDir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // ensure new columns exist
        final cols = await db.rawQuery('PRAGMA table_info(captures)');
        final names = cols.map((e) => e['name']).toList();
        if (!names.contains('site')) {
          await db.execute('ALTER TABLE captures ADD COLUMN site TEXT');
        }
      },
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE captures(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time INTEGER,
        type TEXT,
        site TEXT,
        headers TEXT,
        body TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE frp_config(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS frp_config(
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
  }
} 