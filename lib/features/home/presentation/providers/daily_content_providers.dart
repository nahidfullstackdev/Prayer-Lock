// Providers for the rotating "Verse of the Day" and "Hadith of the Day" cards
// on the home screen. Selection is deterministic by UTC date: every device
// shows the same entry on the same calendar day, and entries cycle through
// the full curated list before repeating.
//
// Note: there is no midnight auto-refresh — the card flips on the next
// rebuild after the date changes. Acceptable because the home screen rebuilds
// frequently (prayer ticking, theme, navigation returns).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/home/data/daily_content_data_source.dart';

final dailyContentDataSourceProvider = Provider<DailyContentDataSource>(
  (_) => DailyContentDataSource(),
);

final dailyVerseProvider = FutureProvider<DailyVerse>((ref) async {
  final ds = ref.read(dailyContentDataSourceProvider);
  final verses = await ds.loadVerses();
  final index = ds.indexForDate(DateTime.now(), verses.length);
  return verses[index];
});

final dailyHadithProvider = FutureProvider<DailyHadith>((ref) async {
  final ds = ref.read(dailyContentDataSourceProvider);
  final hadiths = await ds.loadHadiths();
  final index = ds.indexForDate(DateTime.now(), hadiths.length);
  return hadiths[index];
});
