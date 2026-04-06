import 'package:prayer_lock/core/database/database_helper.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/hadith/data/models/hadith_collection_model.dart';
import 'package:prayer_lock/features/hadith/data/models/hadith_model.dart';
import 'package:sqflite/sqflite.dart';

/// Reads/writes Hadith data from/to the local SQLite database.
class HadithLocalDataSource {
  final DatabaseHelper _db;

  HadithLocalDataSource({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  // ── Collections ───────────────────────────────────────────────────────────

  Future<void> cacheCollections(
    List<HadithCollectionModel> collections,
  ) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final c in collections) {
      batch.insert(
        'hadith_collections',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    AppLogger.info('Cached ${collections.length} hadith collections');
  }

  Future<List<HadithCollectionModel>> getCachedCollections() async {
    final db = await _db.database;
    final rows = await db.query('hadith_collections');
    return rows.map(HadithCollectionModel.fromMap).toList();
  }

  // ── Hadiths ───────────────────────────────────────────────────────────────

  Future<void> cacheHadiths(
    List<HadithModel> hadiths, {
    required int page,
  }) async {
    if (hadiths.isEmpty) return;
    final db = await _db.database;
    final batch = db.batch();
    for (final h in hadiths) {
      batch.insert(
        'hadiths',
        h.toMap(page: page),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    AppLogger.info(
      'Cached ${hadiths.length} hadiths for ${hadiths.first.collection} p$page',
    );
  }

  Future<List<HadithModel>> getCachedHadiths({
    required String collection,
    required int page,
    required int limit,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'hadiths',
      where: 'collection = ? AND page = ?',
      whereArgs: [collection, page],
      limit: limit,
    );
    return rows.map(HadithModel.fromMap).toList();
  }

  Future<bool> hasHadithsForPage({
    required String collection,
    required int page,
  }) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM hadiths WHERE collection = ? AND page = ?',
      [collection, page],
    );
    return (result.first['c'] as int) > 0;
  }

  Future<List<HadithModel>> searchHadiths({
    required String query,
    String? collection,
  }) async {
    final db = await _db.database;
    final pattern = '%$query%';

    if (collection != null) {
      final rows = await db.query(
        'hadiths',
        where:
            'collection = ? AND (text_english LIKE ? OR text_arabic LIKE ?)',
        whereArgs: [collection, pattern, pattern],
        limit: 50,
      );
      return rows.map(HadithModel.fromMap).toList();
    }

    final rows = await db.query(
      'hadiths',
      where: 'text_english LIKE ? OR text_arabic LIKE ?',
      whereArgs: [pattern, pattern],
      limit: 50,
    );
    return rows.map(HadithModel.fromMap).toList();
  }
}
