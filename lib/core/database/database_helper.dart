import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:prayer_lock/core/utils/logger.dart';

/// SQLite database helper for the application
///
/// Manages database creation, migrations, and provides database instance
class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;

  static Database? _database;

  // Private constructor
  DatabaseHelper._internal();

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'muslim_companion.db');

    AppLogger.info('Initializing database at: $path');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  /// Verify core tables exist on every open.
  /// Guards against a corrupt DB left behind by a previously failed _onCreate.
  Future<void> _onOpen(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='surahs'",
    );
    if (tables.isEmpty) {
      AppLogger.warning('Core tables missing — recreating schema');
      await _onCreate(db, 3);
    }
  }

  /// Create database tables (version 3 — Quran + Hadith)
  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info('Creating database tables (v$version)');

    // Surahs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS surahs (
        id INTEGER PRIMARY KEY,
        name_arabic TEXT NOT NULL,
        name_transliteration TEXT NOT NULL,
        name_english TEXT NOT NULL,
        revelation_place TEXT NOT NULL,
        total_ayahs INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_surahs_id ON surahs(id)',
    );

    // Ayahs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ayahs (
        id INTEGER PRIMARY KEY,
        surah_id INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        text_arabic TEXT NOT NULL,
        text_english TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (surah_id) REFERENCES surahs(id) ON DELETE CASCADE,
        UNIQUE(surah_id, ayah_number)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ayahs_surah_id ON ayahs(surah_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ayahs_text ON ayahs(text_english)',
    );

    // Bookmarks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_id INTEGER NOT NULL,
        ayah_id INTEGER NOT NULL,
        surah_name TEXT NOT NULL,
        ayah_number INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(surah_id, ayah_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_surah_ayah ON bookmarks(surah_id, ayah_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_created ON bookmarks(created_at DESC)',
    );

    // Last read position table (single row)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS last_read (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        surah_id INTEGER NOT NULL,
        ayah_id INTEGER NOT NULL,
        surah_name TEXT NOT NULL,
        ayah_number INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Hadith collections table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hadith_collections (
        name TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        title_arabic TEXT NOT NULL,
        total_hadith INTEGER NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Hadiths table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hadiths (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection TEXT NOT NULL,
        book_number TEXT NOT NULL,
        hadith_number TEXT NOT NULL,
        text_arabic TEXT NOT NULL,
        text_english TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        chapter_title_arabic TEXT NOT NULL,
        grade_en TEXT,
        grade_ar TEXT,
        page INTEGER NOT NULL DEFAULT 1,
        cached_at INTEGER NOT NULL,
        UNIQUE(collection, hadith_number)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hadiths_collection ON hadiths(collection)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_hadiths_collection_page ON hadiths(collection, page)',
    );

    AppLogger.info('Database tables created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info('Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // v1 → v2: drop FTS5 virtual table and its triggers (FTS5 unavailable
      // on many Android devices and caused database creation to fail entirely).
      await db.execute('DROP TABLE IF EXISTS ayahs_fts');
      await db.execute('DROP TRIGGER IF EXISTS ayahs_ai');
      await db.execute('DROP TRIGGER IF EXISTS ayahs_ad');
      await db.execute('DROP TRIGGER IF EXISTS ayahs_au');

      // Also drop the old foreign-key constraint columns on last_read that
      // referenced ayahs (safe to recreate without them).
      AppLogger.info('v1→v2: removed FTS5 table and triggers');
    }

    if (oldVersion < 3) {
      // v2 → v3: add hadith_collections and hadiths tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hadith_collections (
          name TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          title_arabic TEXT NOT NULL,
          total_hadith INTEGER NOT NULL,
          cached_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS hadiths (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          collection TEXT NOT NULL,
          book_number TEXT NOT NULL,
          hadith_number TEXT NOT NULL,
          text_arabic TEXT NOT NULL,
          text_english TEXT NOT NULL,
          chapter_title TEXT NOT NULL,
          chapter_title_arabic TEXT NOT NULL,
          grade_en TEXT,
          grade_ar TEXT,
          page INTEGER NOT NULL DEFAULT 1,
          cached_at INTEGER NOT NULL,
          UNIQUE(collection, hadith_number)
        )
      ''');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hadiths_collection ON hadiths(collection)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hadiths_collection_page ON hadiths(collection, page)',
      );

      AppLogger.info('v2→v3: added hadith_collections and hadiths tables');
    }
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    AppLogger.info('Database connection closed');
  }
}
