import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/quran/data/models/ayah_model.dart';
import 'package:prayer_lock/features/quran/data/models/bookmark_model.dart';
import 'package:prayer_lock/features/quran/data/models/last_read_model.dart';
import 'package:prayer_lock/features/quran/data/models/surah_model.dart';

/// Local data source for caching and retrieving Quran data via Hive
class QuranLocalDataSource {
  final Box<dynamic> box;

  static const String _surahsKey = 'surahs';
  static const String _ayahsPrefix = 'ayahs_';
  static const String _bookmarksKey = 'bookmarks';
  static const String _lastReadKey = 'last_read';

  QuranLocalDataSource({required this.box});

  // ==================== Surahs ====================

  /// Cache Surahs in Hive
  Future<void> cacheSurahs(List<SurahModel> surahs) async {
    try {
      final json = jsonEncode(surahs.map((s) => s.toJson()).toList());
      await box.put(_surahsKey, json);
      AppLogger.info('Cached ${surahs.length} Surahs in Hive');
    } catch (e, stackTrace) {
      AppLogger.error('Error caching Surahs', e, stackTrace);
      rethrow;
    }
  }

  /// Get cached Surahs from Hive
  Future<List<SurahModel>> getCachedSurahs() async {
    try {
      final json = box.get(_surahsKey) as String?;
      if (json == null) {
        AppLogger.debug('No cached Surahs found');
        return [];
      }
      final list = jsonDecode(json) as List<dynamic>;
      final surahs = list
          .map((j) => SurahModel.fromJson(j as Map<String, dynamic>))
          .toList();
      AppLogger.debug('Retrieved ${surahs.length} cached Surahs from Hive');
      return surahs;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting cached Surahs', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Ayahs ====================

  /// Cache Ayahs for a specific Surah in Hive
  Future<void> cacheAyahs(List<AyahModel> ayahs) async {
    if (ayahs.isEmpty) return;
    try {
      final surahId = ayahs.first.surahId;
      final json = jsonEncode(ayahs.map((a) => a.toJson()).toList());
      await box.put('$_ayahsPrefix$surahId', json);
      AppLogger.info('Cached ${ayahs.length} Ayahs for Surah $surahId in Hive');
    } catch (e, stackTrace) {
      AppLogger.error('Error caching Ayahs', e, stackTrace);
      rethrow;
    }
  }

  /// Get cached Ayahs for a specific Surah from Hive
  Future<List<AyahModel>> getCachedAyahs(int surahId) async {
    try {
      final json = box.get('$_ayahsPrefix$surahId') as String?;
      if (json == null) {
        AppLogger.debug('No cached Ayahs for Surah $surahId');
        return [];
      }
      final list = jsonDecode(json) as List<dynamic>;
      final ayahs = list
          .map((j) => AyahModel.fromCacheJson(j as Map<String, dynamic>))
          .toList();
      AppLogger.debug('Retrieved ${ayahs.length} cached Ayahs for Surah $surahId from Hive');
      return ayahs;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting cached Ayahs', e, stackTrace);
      rethrow;
    }
  }

  /// Search Ayahs by English or Bengali text across all cached Surahs
  Future<List<AyahModel>> searchAyahs(String query) async {
    try {
      final trimmed = query.trim().toLowerCase();
      if (trimmed.isEmpty) return [];

      final results = <AyahModel>[];
      for (final key in box.keys) {
        if (key is! String || !key.startsWith(_ayahsPrefix)) continue;
        final json = box.get(key) as String?;
        if (json == null) continue;
        final list = jsonDecode(json) as List<dynamic>;
        for (final j in list) {
          final ayah = AyahModel.fromCacheJson(j as Map<String, dynamic>);
          if (ayah.textEnglish.toLowerCase().contains(trimmed) ||
              ayah.textBengali.toLowerCase().contains(trimmed)) {
            results.add(ayah);
          }
        }
        if (results.length >= 50) break;
      }

      results.sort((a, b) {
        final sc = a.surahId.compareTo(b.surahId);
        return sc != 0 ? sc : a.ayahNumber.compareTo(b.ayahNumber);
      });

      final limited = results.take(50).toList();
      AppLogger.debug('Found ${limited.length} Ayahs matching "$query"');
      return limited;
    } catch (e, stackTrace) {
      AppLogger.error('Error searching Ayahs', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Bookmarks ====================

  /// Add a bookmark (replaces existing bookmark for same surah+ayah)
  Future<void> addBookmark(BookmarkModel bookmark) async {
    try {
      final bookmarks = await getBookmarks();
      bookmarks.removeWhere(
        (b) => b.surahId == bookmark.surahId && b.ayahId == bookmark.ayahId,
      );
      bookmarks.insert(0, bookmark);
      final json = jsonEncode(bookmarks.map((b) => b.toJson()).toList());
      await box.put(_bookmarksKey, json);
      AppLogger.info('Added bookmark: Surah ${bookmark.surahId}, Ayah ${bookmark.ayahNumber}');
    } catch (e, stackTrace) {
      AppLogger.error('Error adding bookmark', e, stackTrace);
      rethrow;
    }
  }

  /// Remove a bookmark
  Future<void> removeBookmark(int surahId, int ayahId) async {
    try {
      final bookmarks = await getBookmarks();
      bookmarks.removeWhere(
        (b) => b.surahId == surahId && b.ayahId == ayahId,
      );
      final json = jsonEncode(bookmarks.map((b) => b.toJson()).toList());
      await box.put(_bookmarksKey, json);
      AppLogger.info('Removed bookmark: Surah $surahId, Ayah $ayahId');
    } catch (e, stackTrace) {
      AppLogger.error('Error removing bookmark', e, stackTrace);
      rethrow;
    }
  }

  /// Get all bookmarks (newest first)
  Future<List<BookmarkModel>> getBookmarks() async {
    try {
      final json = box.get(_bookmarksKey) as String?;
      if (json == null) return [];
      final list = jsonDecode(json) as List<dynamic>;
      final bookmarks = list
          .map((j) => BookmarkModel.fromCacheJson(j as Map<String, dynamic>))
          .toList();
      AppLogger.debug('Retrieved ${bookmarks.length} bookmarks from Hive');
      return bookmarks;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting bookmarks', e, stackTrace);
      rethrow;
    }
  }

  /// Check if an Ayah is bookmarked
  Future<bool> isBookmarked(int surahId, int ayahId) async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.any(
        (b) => b.surahId == surahId && b.ayahId == ayahId,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error checking bookmark status', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Last Read ====================

  /// Save last read position
  Future<void> saveLastRead(LastReadModel lastRead) async {
    try {
      final json = jsonEncode(lastRead.toJson());
      await box.put(_lastReadKey, json);
      AppLogger.info('Saved last read: Surah ${lastRead.surahId}, Ayah ${lastRead.ayahNumber}');
    } catch (e, stackTrace) {
      AppLogger.error('Error saving last read', e, stackTrace);
      rethrow;
    }
  }

  /// Get last read position (returns null if not set)
  Future<LastReadModel?> getLastRead() async {
    try {
      final json = box.get(_lastReadKey) as String?;
      if (json == null) {
        AppLogger.debug('No last read position found');
        return null;
      }
      final map = jsonDecode(json) as Map<String, dynamic>;
      final lastRead = LastReadModel.fromCacheJson(map);
      AppLogger.debug('Retrieved last read: Surah ${lastRead.surahId}, Ayah ${lastRead.ayahNumber}');
      return lastRead;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting last read', e, stackTrace);
      rethrow;
    }
  }
}
