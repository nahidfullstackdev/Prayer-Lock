import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:prayer_lock/core/network/dio_client.dart';
import 'package:prayer_lock/features/quran/data/datasources/quran_local_data_source.dart';
import 'package:prayer_lock/features/quran/data/datasources/quran_remote_data_source.dart';
import 'package:prayer_lock/features/quran/data/repositories/quran_repository_impl.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';
import 'package:prayer_lock/features/quran/domain/usecases/add_bookmark.dart';
import 'package:prayer_lock/features/quran/domain/usecases/get_all_surahs.dart';
import 'package:prayer_lock/features/quran/domain/usecases/get_bookmarks.dart';
import 'package:prayer_lock/features/quran/domain/usecases/get_last_read.dart';
import 'package:prayer_lock/features/quran/domain/usecases/get_surah_by_id.dart';
import 'package:prayer_lock/features/quran/domain/usecases/remove_bookmark.dart';
import 'package:prayer_lock/features/quran/domain/usecases/save_last_read.dart';
import 'package:prayer_lock/features/quran/domain/usecases/search_ayahs.dart';
import 'package:prayer_lock/features/quran/presentation/providers/bookmark_notifier.dart';
import 'package:prayer_lock/features/quran/presentation/providers/search_notifier.dart';
import 'package:prayer_lock/features/quran/presentation/providers/surah_detail_notifier.dart';
import 'package:prayer_lock/features/quran/presentation/providers/surah_list_notifier.dart';

// ==================== Data Source Providers ====================

/// Dio client provider (singleton)
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient.instance;
});

/// Hive box provider for Quran data (opened in main before runApp)
final quranHiveBoxProvider = Provider<Box<dynamic>>((ref) {
  return Hive.box<dynamic>('quran_data');
});

/// Remote data source provider
final quranRemoteDataSourceProvider = Provider<QuranRemoteDataSource>((ref) {
  return QuranRemoteDataSource(
    dio: ref.read(dioClientProvider).dio,
  );
});

/// Local data source provider
final quranLocalDataSourceProvider = Provider<QuranLocalDataSource>((ref) {
  return QuranLocalDataSource(
    box: ref.read(quranHiveBoxProvider),
  );
});

// ==================== Repository Provider ====================

/// Quran repository provider
final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepositoryImpl(
    remoteDataSource: ref.read(quranRemoteDataSourceProvider),
    localDataSource: ref.read(quranLocalDataSourceProvider),
  );
});

// ==================== UseCase Providers ====================

/// Get all Surahs use case provider
final getAllSurahsUseCaseProvider = Provider<GetAllSurahsUseCase>((ref) {
  return GetAllSurahsUseCase(ref.read(quranRepositoryProvider));
});

/// Get Surah by ID use case provider
final getSurahByIdUseCaseProvider = Provider<GetSurahByIdUseCase>((ref) {
  return GetSurahByIdUseCase(ref.read(quranRepositoryProvider));
});

/// Search Ayahs use case provider
final searchAyahsUseCaseProvider = Provider<SearchAyahsUseCase>((ref) {
  return SearchAyahsUseCase(ref.read(quranRepositoryProvider));
});

/// Add bookmark use case provider
final addBookmarkUseCaseProvider = Provider<AddBookmarkUseCase>((ref) {
  return AddBookmarkUseCase(ref.read(quranRepositoryProvider));
});

/// Remove bookmark use case provider
final removeBookmarkUseCaseProvider = Provider<RemoveBookmarkUseCase>((ref) {
  return RemoveBookmarkUseCase(ref.read(quranRepositoryProvider));
});

/// Get bookmarks use case provider
final getBookmarksUseCaseProvider = Provider<GetBookmarksUseCase>((ref) {
  return GetBookmarksUseCase(ref.read(quranRepositoryProvider));
});

/// Save last read use case provider
final saveLastReadUseCaseProvider = Provider<SaveLastReadUseCase>((ref) {
  return SaveLastReadUseCase(ref.read(quranRepositoryProvider));
});

/// Get last read use case provider
final getLastReadUseCaseProvider = Provider<GetLastReadUseCase>((ref) {
  return GetLastReadUseCase(ref.read(quranRepositoryProvider));
});

// ==================== State Notifier Providers ====================

/// Surah list state notifier provider
final surahListProvider = StateNotifierProvider<SurahListNotifier, SurahListState>((ref) {
  return SurahListNotifier(
    getAllSurahsUseCase: ref.read(getAllSurahsUseCaseProvider),
  );
});

/// Surah detail state notifier provider (family for different Surahs)
final surahDetailProvider = StateNotifierProvider.family<SurahDetailNotifier, SurahDetailState, int>(
  (ref, surahId) {
    return SurahDetailNotifier(
      surahId: surahId,
      getSurahByIdUseCase: ref.read(getSurahByIdUseCaseProvider),
      saveLastReadUseCase: ref.read(saveLastReadUseCaseProvider),
    );
  },
);

/// Bookmarks state notifier provider
final bookmarksProvider = StateNotifierProvider<BookmarkNotifier, BookmarkState>((ref) {
  return BookmarkNotifier(
    getBookmarksUseCase: ref.read(getBookmarksUseCaseProvider),
    addBookmarkUseCase: ref.read(addBookmarkUseCaseProvider),
    removeBookmarkUseCase: ref.read(removeBookmarkUseCaseProvider),
  );
});

/// Search state notifier provider
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(
    searchAyahsUseCase: ref.read(searchAyahsUseCaseProvider),
  );
});
