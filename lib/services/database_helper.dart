import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/transaction.dart' show Transaction;

/// DatabaseHelper — sqflite singleton for UPI Lens.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;
  static const String _dbName = 'upilens.db';
  static const int _dbVersion = 1;
  static const String _table = 'transactions';

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY,
        rawSms TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        merchantName TEXT NOT NULL,
        upiId TEXT NOT NULL,
        bankName TEXT NOT NULL,
        category TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        classifiedBy TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_timestamp ON $_table (timestamp DESC)');
    await db.execute(
        'CREATE INDEX idx_category ON $_table (category)');
  }

  // ── CRUD ───────────────────────────────────────────────────────────────

  /// Insert a transaction. Ignores conflicts (duplicate IDs).
  Future<void> insertTransaction(Transaction tx) async {
    final db = await database;
    await db.insert(
      _table,
      tx.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// All transactions ordered by date descending.
  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'timestamp DESC');
    return rows.map((r) => Transaction.fromMap(r)).toList();
  }

  /// Delete all transactions.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_table);
  }

  // ── Aggregation queries ────────────────────────────────────────────────

  /// Category totals for the current calendar month.
  Future<Map<String, double>> getCategoryTotalsThisMonth() async {
    final db = await database;
    final now = DateTime.now();
    final startOfMonth =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    final rows = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM $_table
      WHERE type = 'DEBIT' AND timestamp >= ?
      GROUP BY category
    ''', [startOfMonth]);

    return {for (final r in rows) r['category'] as String: (r['total'] as num).toDouble()};
  }

  /// Total debited and credited this month.
  Future<Map<String, double>> getMonthlyTotals() async {
    final db = await database;
    final now = DateTime.now();
    final startOfMonth =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    final debitRow = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM $_table WHERE type = 'DEBIT' AND timestamp >= ?
    ''', [startOfMonth]);

    final creditRow = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM $_table WHERE type = 'CREDIT' AND timestamp >= ?
    ''', [startOfMonth]);

    return {
      'debit': (debitRow.first['total'] as num).toDouble(),
      'credit': (creditRow.first['total'] as num).toDouble(),
    };
  }

  /// Top N merchants by total spend this month (DEBIT only).
  Future<List<Map<String, dynamic>>> getTopMerchants({int limit = 5}) async {
    final db = await database;
    final now = DateTime.now();
    final startOfMonth =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    return db.rawQuery('''
      SELECT merchantName, category, SUM(amount) as total
      FROM $_table
      WHERE type = 'DEBIT' AND timestamp >= ?
      GROUP BY merchantName
      ORDER BY total DESC
      LIMIT ?
    ''', [startOfMonth, limit]);
  }

  /// Monthly totals for the last N months (for bar chart).
  Future<List<Map<String, dynamic>>> getMonthlyTrends({int months = 6}) async {
    final db = await database;
    final results = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = months - 1; i >= 0; i--) {
      final start =
          DateTime(now.year, now.month - i, 1).millisecondsSinceEpoch;
      final end =
          DateTime(now.year, now.month - i + 1, 1).millisecondsSinceEpoch;

      final row = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total
        FROM $_table WHERE type = 'DEBIT' AND timestamp >= ? AND timestamp < ?
      ''', [start, end]);

      final monthDate = DateTime(now.year, now.month - i, 1);
      results.add({
        'month': monthDate,
        'total': (row.first['total'] as num).toDouble(),
      });
    }
    return results;
  }

  /// Check if a transaction ID already exists (dedup).
  Future<bool> exists(String id) async {
    final db = await database;
    final rows = await db.query(_table,
        columns: ['id'], where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }

  /// Get total spend for this week vs last week for comparison.
  Future<Map<String, double>> getWeeklySpendComparison() async {
    final db = await database;
    final now = DateTime.now();
    final thisWeekStart = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final lastWeekStart = now.subtract(const Duration(days: 14)).millisecondsSinceEpoch;

    final thisWeekRow = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM $_table WHERE type = 'DEBIT' AND timestamp >= ?
    ''', [thisWeekStart]);

    final lastWeekRow = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM $_table WHERE type = 'DEBIT' AND timestamp >= ? AND timestamp < ?
    ''', [lastWeekStart, thisWeekStart]);

    return {
      'thisWeek': (thisWeekRow.first['total'] as num).toDouble(),
      'lastWeek': (lastWeekRow.first['total'] as num).toDouble(),
    };
  }

  /// Get the top merchant by spend this month.
  Future<Map<String, dynamic>?> getTopMerchantThisMonth() async {
    final db = await database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    final rows = await db.rawQuery('''
      SELECT merchantName, SUM(amount) as total
      FROM $_table
      WHERE type = 'DEBIT' AND timestamp >= ?
      GROUP BY merchantName
      ORDER BY total DESC
      LIMIT 1
    ''', [startOfMonth]);

    return rows.isNotEmpty ? rows.first : null;
  }
}
