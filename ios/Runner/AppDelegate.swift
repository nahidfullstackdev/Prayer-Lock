import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure the shared AVAudioSession so AdhanAudioService can play the
    // full-length Adhan even when the device ring switch is silenced and
    // when the app is backgrounded (requires `audio` in UIBackgroundModes).
    // `.mixWithOthers` keeps music/podcasts running underneath instead of
    // ducking them — a quieter UX for users mid-listen.
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("Adhan AVAudioSession setup failed: \(error)")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
