import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app_database_migrations.dart';

class AppDatabase {
  AppDatabase({String? databasePath}) : _databasePath = databasePath;

  static const int schemaVersion = 1;
  static const String databaseName = 'app_acc_transito.db';

  final String? _databasePath;
  Database? _database;

  Future<Database> get instance async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final path =
        _databasePath ?? p.join(await getDatabasesPath(), databaseName);
    _database = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await AppDatabaseMigrations.create(db, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await AppDatabaseMigrations.upgrade(db, oldVersion, newVersion);
      },
    );

    return _database!;
  }

  Future<T> transaction<T>(
      Future<T> Function(Transaction transaction) action) async {
    final db = await instance;
    return db.transaction(action);
  }

  Future<void> close() async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    _database = null;
  }
}
