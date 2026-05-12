import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:prayer_lock/core/utils/logger.dart';

/// In-app full-length Adhan playback.
///
/// Why this exists:
///   iOS caps notification sounds at ~30 s, so the bundled `.caf` fallback can
///   only ever play a truncated Adhan. To deliver the full Adhan when the iOS
///   app is alive (foreground or background), we drive an [AudioPlayer]
///   directly from a Dart [Timer] that fires at the scheduled prayer time.
///
///   Android does not need this: the `prayer_adhan` notification channel
///   plays the full-length `adhan.mp3` regardless of Dart-isolate state.
class AdhanAudioService {
  AdhanAudioService._();
  static final AdhanAudioService _instance = AdhanAudioService._();
  factory AdhanAudioService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  bool _initialised = false;

  /// Configures the iOS audio session so playback:
  ///   - continues when the device's ring switch is silenced (`.playback`),
  ///   - keeps running when the app is backgrounded (requires the `audio`
  ///     entry in `UIBackgroundModes`),
  ///   - mixes with other audio rather than ducking music/podcasts.
  Future<void> initialize() async {
    if (_initialised) return;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      if (Platform.isIOS) {
        await _player.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: const <AVAudioSessionOptions>{
                AVAudioSessionOptions.mixWithOthers,
              },
            ),
          ),
        );
      }
      _initialised = true;
      AppLogger.info('AdhanAudioService initialised');
    } catch (e, st) {
      AppLogger.error('AdhanAudioService.initialize failed', e, st);
    }
  }

  /// Plays the full-length Adhan from bundled Flutter assets.
  ///
  /// Stops any currently-playing Adhan first so back-to-back triggers (or a
  /// late timer that overlaps with the next prayer) never double-fire.
  Future<void> playAdhan({required bool isFajr}) async {
    if (!_initialised) await initialize();
    final asset = isFajr ? 'sounds/adhan_fajr.mp3' : 'sounds/adhan.mp3';
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
      AppLogger.info('Adhan playback started ($asset)');
    } catch (e, st) {
      AppLogger.error('playAdhan failed for $asset', e, st);
    }
  }

  /// Stops any in-progress Adhan playback.
  Future<void> stop() async {
    try {
      await _player.stop();
      AppLogger.info('Adhan playback stopped');
    } catch (e, st) {
      AppLogger.error('AdhanAudioService.stop failed', e, st);
    }
  }

  /// True when an Adhan is currently playing. Used by the notification-tap
  /// handler to avoid restarting playback mid-Adhan.
  bool get isPlaying => _player.state == PlayerState.playing;
}
