import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/constants/api_constants.dart';
import 'package:prayer_lock/features/hadith/data/datasources/hadith_local_data_source.dart';
import 'package:prayer_lock/features/hadith/data/datasources/hadith_remote_data_source.dart';
import 'package:prayer_lock/features/hadith/data/repositories/hadith_repository_impl.dart';
import 'package:prayer_lock/features/hadith/domain/repositories/hadith_repository.dart';
import 'package:prayer_lock/features/hadith/domain/usecases/get_hadith_collections.dart';
import 'package:prayer_lock/features/hadith/domain/usecases/get_hadiths.dart';
import 'package:prayer_lock/features/hadith/domain/usecases/search_hadiths.dart';
import 'package:prayer_lock/features/hadith/presentation/providers/hadith_collections_notifier.dart';
import 'package:prayer_lock/features/hadith/presentation/providers/hadith_list_notifier.dart';

export 'package:prayer_lock/features/hadith/presentation/providers/hadith_language_preferences_provider.dart';

// ── HTTP client ───────────────────────────────────────────────────────────────

/// Dio instance configured for the fawazahmed0/hadith-api CDN.
/// No authentication needed — entirely free and open.
final hadithDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.hadithApiBaseUrl,
      connectTimeout:
          const Duration(milliseconds: ApiConstants.connectionTimeout),
      receiveTimeout:
          const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

// ── Data sources ──────────────────────────────────────────────────────────────

final hadithRemoteDataSourceProvider =
    Provider<HadithRemoteDataSource>((ref) {
  return HadithRemoteDataSource(dio: ref.read(hadithDioProvider));
});

final hadithLocalDataSourceProvider =
    Provider<HadithLocalDataSource>((ref) {
  return HadithLocalDataSource();
});

// ── Repository ────────────────────────────────────────────────────────────────

final hadithRepositoryProvider = Provider<HadithRepository>((ref) {
  return HadithRepositoryImpl(
    remoteDataSource: ref.read(hadithRemoteDataSourceProvider),
    localDataSource: ref.read(hadithLocalDataSourceProvider),
  );
});

// ── Use cases ─────────────────────────────────────────────────────────────────

final getHadithCollectionsUseCaseProvider =
    Provider<GetHadithCollectionsUseCase>((ref) {
  return GetHadithCollectionsUseCase(ref.read(hadithRepositoryProvider));
});

final getHadithsUseCaseProvider = Provider<GetHadithsUseCase>((ref) {
  return GetHadithsUseCase(ref.read(hadithRepositoryProvider));
});

final searchHadithsUseCaseProvider = Provider<SearchHadithsUseCase>((ref) {
  return SearchHadithsUseCase(ref.read(hadithRepositoryProvider));
});

// ── State notifiers ───────────────────────────────────────────────────────────

final hadithCollectionsProvider =
    StateNotifierProvider<HadithCollectionsNotifier, HadithCollectionsState>(
  (ref) => HadithCollectionsNotifier(
    getCollectionsUseCase: ref.read(getHadithCollectionsUseCaseProvider),
  ),
);

/// Family provider keyed by collection name (e.g. 'bukhari').
/// Automatically reloads when the user's selected languages change.
final hadithListProvider = StateNotifierProvider.family<
    HadithListNotifier, HadithListState, String>(
  (ref, collection) => HadithListNotifier(
    collection: collection,
    ref: ref,
    getHadithsUseCase: ref.read(getHadithsUseCaseProvider),
    searchHadithsUseCase: ref.read(searchHadithsUseCaseProvider),
  ),
);
