import 'dart:convert';

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

  /// Returns the set of language codes already cached for [collection].
  /// Inspects the translations JSON of the first row as a proxy for all rows.
  Future<Set<String>> getLanguagesCachedForCollection(
    String collection,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'hadiths',
      columns: ['translations'],
      where: 'collection = ?',
      whereArgs: [collection],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final translationsJson = (rows.first['translations'] as String?) ?? '{}';
    try {
      final map = jsonDecode(translationsJson) as Map<String, dynamic>;
      return map.keys.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Cache hadiths for a single language edition.
  ///
  /// On first call for [collection]: inserts all rows with a single-key
  /// translations map.
  /// On subsequent calls for additional languages: reads existing translations,
  /// merges the new language key in Dart, then batch-updates all rows.
  Future<void> cacheHadithsForLanguage({
    required String collection,
    required String langCode,
    required List<HadithModel> hadiths,
  }) async {
    if (hadiths.isEmpty) return;

    final db = await _db.database;

    // Read existing translations to know whether to INSERT or UPDATE
    final existingRows = await db.query(
      'hadiths',
      columns: ['hadith_number', 'translations'],
      where: 'collection = ?',
      whereArgs: [collection],
    );

    await db.transaction((txn) async {
      final batch = txn.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      if (existingRows.isEmpty) {
        // First language for this collection — plain inserts
        for (final h in hadiths) {
          batch.insert(
            'hadiths',
            {
              'collection': h.collection,
              'hadith_number': h.hadithNumber,
              'arabic_number': h.arabicNumber,
              'section': h.section,
              'grade': h.grade,
              'translations': jsonEncode(h.translations),
              'cached_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } else {
        // Build existing translations map: hadith_number → Map<lang, text>
        final existingMap = <int, Map<String, dynamic>>{};
        for (final row in existingRows) {
          final num = row['hadith_number'] as int;
          final json = (row['translations'] as String?) ?? '{}';
          try {
            existingMap[num] =
                Map<String, dynamic>.from(jsonDecode(json) as Map);
          } catch (_) {
            existingMap[num] = {};
          }
        }

        // Merge new language into each hadith row
        for (final h in hadiths) {
          final existing =
              Map<String, dynamic>.from(existingMap[h.hadithNumber] ?? {});
          existing[langCode] = h.translations[langCode] ?? '';

          batch.update(
            'hadiths',
            {
              'translations': jsonEncode(existing),
              'cached_at': now,
            },
            where: 'collection = ? AND hadith_number = ?',
            whereArgs: [collection, h.hadithNumber],
          );
        }
      }

      await batch.commit(noResult: true);
    });

    AppLogger.info(
      'Cached ${hadiths.length} hadiths [$langCode] for $collection',
    );
  }

  /// Returns a page of hadiths from SQLite, ordered by hadith_number.
  Future<List<HadithModel>> getHadithsPage({
    required String collection,
    required int page,
    required int limit,
  }) async {
    final db = await _db.database;
    final offset = (page - 1) * limit;
    final rows = await db.query(
      'hadiths',
      where: 'collection = ?',
      whereArgs: [collection],
      orderBy: 'hadith_number ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(HadithModel.fromDbMap).toList();
  }

  /// Total number of cached hadiths for [collection].
  Future<int> getCachedCount(String collection) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM hadiths WHERE collection = ?',
      [collection],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Full-text search across all cached hadith translations.
  Future<List<HadithModel>> searchHadiths({
    required String query,
    String? collection,
  }) async {
    final db = await _db.database;
    final pattern = '%$query%';

    final List<Map<String, dynamic>> rows;
    if (collection != null) {
      rows = await db.query(
        'hadiths',
        where: 'collection = ? AND translations LIKE ?',
        whereArgs: [collection, pattern],
        limit: 50,
      );
    } else {
      rows = await db.query(
        'hadiths',
        where: 'translations LIKE ?',
        whereArgs: [pattern],
        limit: 50,
      );
    }
    return rows.map(HadithModel.fromDbMap).toList();
  }
}
