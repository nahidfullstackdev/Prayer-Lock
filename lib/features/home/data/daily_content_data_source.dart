import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class DailyVerse {
  const DailyVerse({
    required this.id,
    required this.surahNumber,
    required this.surahName,
    required this.ayahNumber,
    required this.arabic,
    required this.translation,
  });

  final String id;
  final int surahNumber;
  final String surahName;
  final int ayahNumber;
  final String arabic;
  final String translation;

  factory DailyVerse.fromJson(Map<String, dynamic> json) => DailyVerse(
    id: json['id'] as String,
    surahNumber: json['surahNumber'] as int,
    surahName: json['surahName'] as String,
    ayahNumber: json['ayahNumber'] as int,
    arabic: json['arabic'] as String,
    translation: json['translation'] as String,
  );

  String get reference => 'Surah $surahName $surahNumber:$ayahNumber';
}

class DailyHadith {
  const DailyHadith({
    required this.id,
    required this.text,
    required this.collection,
    required this.reference,
  });

  final String id;
  final String text;
  final String collection;
  final String reference;

  factory DailyHadith.fromJson(Map<String, dynamic> json) => DailyHadith(
    id: json['id'] as String,
    text: json['text'] as String,
    collection: json['collection'] as String,
    reference: json['reference'] as String,
  );
}

/// Loads the curated daily verse and hadith lists from bundled JSON assets
/// and resolves today's entry by date.
///
/// The lists are cached in memory after the first read so subsequent provider
/// rebuilds (e.g. theme switches) don't re-parse the JSON.
class DailyContentDataSource {
  static const String _versesAssetPath = 'assets/data/daily_verses.json';
  static const String _hadithsAssetPath = 'assets/data/daily_hadiths.json';

  List<DailyVerse>? _verses;
  List<DailyHadith>? _hadiths;

  Future<List<DailyVerse>> loadVerses() async {
    if (_verses != null) return _verses!;
    final raw = await rootBundle.loadString(_versesAssetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['verses'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(DailyVerse.fromJson)
        .toList(growable: false);
    _verses = list;
    return list;
  }

  Future<List<DailyHadith>> loadHadiths() async {
    if (_hadiths != null) return _hadiths!;
    final raw = await rootBundle.loadString(_hadithsAssetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['hadiths'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(DailyHadith.fromJson)
        .toList(growable: false);
    _hadiths = list;
    return list;
  }

  /// Deterministic index for [date] over a list of [length] items. UTC-anchored
  /// so users in different timezones see the same entry on the same calendar
  /// date.
  int indexForDate(DateTime date, int length) {
    if (length <= 0) return 0;
    final epoch = DateTime.utc(1970, 1, 1);
    final daysSinceEpoch =
        DateTime.utc(date.year, date.month, date.day).difference(epoch).inDays;
    return daysSinceEpoch.abs() % length;
  }
}
