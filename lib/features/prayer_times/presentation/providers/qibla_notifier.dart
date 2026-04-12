import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/qibla_direction.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_qibla_direction.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';

class QiblaState {
  final bool isLoading;
  final QiblaDirection? qiblaDirection;
  final String? errorMessage;

  const QiblaState({
    this.isLoading = false,
    this.qiblaDirection,
    this.errorMessage,
  });

  QiblaState copyWith({
    bool? isLoading,
    QiblaDirection? qiblaDirection,
    String? errorMessage,
  }) {
    return QiblaState(
      isLoading: isLoading ?? this.isLoading,
      qiblaDirection: qiblaDirection ?? this.qiblaDirection,
      errorMessage: errorMessage,
    );
  }
}

class QiblaNotifier extends StateNotifier<QiblaState> {
  final GetQiblaDirectionUseCase _useCase;

  QiblaNotifier({required GetQiblaDirectionUseCase useCase})
      : _useCase = useCase,
        super(const QiblaState());

  Future<void> fetch(LocationData location) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _useCase(location);
    result.fold(
      (failure) => state = QiblaState(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (direction) => state = QiblaState(
        isLoading: false,
        qiblaDirection: direction,
      ),
    );
  }
}

final qiblaProvider =
    StateNotifierProvider<QiblaNotifier, QiblaState>((ref) {
  return QiblaNotifier(
    useCase: ref.read(getQiblaDirectionUseCaseProvider),
  );
});
