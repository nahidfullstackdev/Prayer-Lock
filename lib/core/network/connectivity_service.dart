import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around `connectivity_plus` so the rest of the app does not
/// need to import the package directly. Treats "any non-`none` interface" as
/// online — wifi, mobile, ethernet, vpn, bluetooth all qualify.
///
/// Note: this only reports *interface* state, not real reachability of a
/// specific host. A device on captive-portal wifi will still report online.
/// Repository-level retry on `DioException` remains the source of truth for
/// "did the actual fetch succeed".
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity() {
    // Eagerly built so the analyzer can see the close in dispose(). The
    // platform subscription stays lazy via onListen/onCancel below.
    _controller = StreamController<bool>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final Connectivity _connectivity;

  late final StreamController<bool> _controller;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool? _lastValue;

  /// Distinct stream of online/offline transitions. Emits the current state
  /// as the first value when the first listener subscribes.
  Stream<bool> get onStatusChange => _controller.stream;

  /// One-shot check used by the repository before deciding to call the API.
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return _resultToBool(result);
  }

  void _start() {
    _sub = _connectivity.onConnectivityChanged.listen((r) {
      _emit(_resultToBool(r));
    });
    isOnline().then(_emit);
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _lastValue = null;
  }

  void _emit(bool value) {
    if (_lastValue == value) return;
    _lastValue = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  static bool _resultToBool(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  Future<void> dispose() async {
    await _sub?.cancel();
    if (!_controller.isClosed) await _controller.close();
  }
}
