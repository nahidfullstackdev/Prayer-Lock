import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/quran/domain/entities/bookmark.dart';
import 'package:prayer_lock/features/quran/domain/usecases/add_bookmark.dart';
import 'package:prayer_lock/features/quran/domain/usecases/get_bookmarks.dart';
import 'package:prayer_lock/features/quran/domain/usecases/remove_bookmark.dart';

/// State for bookmarks
class BookmarkState {
  final List<Bookmark> bookmarks;
  final bool isLoading;
  final String? errorMessage;

  const BookmarkState({
    this.bookmarks = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  BookmarkState copyWith({
    List<Bookmark>? bookmarks,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// State notifier for bookmarks
class BookmarkNotifier extends StateNotifier<BookmarkState> {
  final GetBookmarksUseCase getBookmarksUseCase;
  final AddBookmarkUseCase addBookmarkUseCase;
  final RemoveBookmarkUseCase removeBookmarkUseCase;

  BookmarkNotifier({
    required this.getBookmarksUseCase,
    required this.addBookmarkUseCase,
    required this.removeBookmarkUseCase,
  }) : super(const BookmarkState()) {
    loadBookmarks();
  }

  /// Load all bookmarks
  Future<void> loadBookmarks() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    AppLogger.info('Loading bookmarks...');

    final result = await getBookmarksUseCase();

    result.fold(
      (failure) {
        AppLogger.error('Failed to load bookmarks: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (bookmarks) {
        AppLogger.info('Loaded ${bookmarks.length} bookmarks');
        state = state.copyWith(
          bookmarks: bookmarks,
          isLoading: false,
          errorMessage: null,
        );
      },
    );
  }

  /// Add a bookmark
  Future<bool> addBookmark(Bookmark bookmark) async {
    final result = await addBookmarkUseCase(bookmark);

    return result.fold(
      (failure) {
        AppLogger.error('Failed to add bookmark: ${failure.message}');
        return false;
      },
      (_) {
        AppLogger.info('Bookmark added successfully');
        loadBookmarks(); // Refresh list
        return true;
      },
    );
  }

  /// Remove a bookmark
  Future<bool> removeBookmark(int surahId, int ayahId) async {
    final result = await removeBookmarkUseCase(
      surahId: surahId,
      ayahId: ayahId,
    );

    return result.fold(
      (failure) {
        AppLogger.error('Failed to remove bookmark: ${failure.message}');
        return false;
      },
      (_) {
        AppLogger.info('Bookmark removed successfully');
        loadBookmarks(); // Refresh list
        return true;
      },
    );
  }

  /// Toggle bookmark (add if not bookmarked, remove if bookmarked)
  Future<bool> toggleBookmark(Bookmark bookmark) async {
    // Check if already bookmarked
    final isAlreadyBookmarked = state.bookmarks.any(
      (b) => b.surahId == bookmark.surahId && b.ayahId == bookmark.ayahId,
    );

    if (isAlreadyBookmarked) {
      return await removeBookmark(bookmark.surahId, bookmark.ayahId);
    } else {
      return await addBookmark(bookmark);
    }
  }

  /// Check if an Ayah is bookmarked
  bool isBookmarked(int surahId, int ayahId) {
    return state.bookmarks.any(
      (b) => b.surahId == surahId && b.ayahId == ayahId,
    );
  }

  /// Refresh bookmarks
  Future<void> refresh() async {
    await loadBookmarks();
  }
}
