# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# App Blocker — keep class names for Android system service resolution
-keep class com.mdnahid.prayerlock.AppBlockerService { *; }
-keep class com.mdnahid.prayerlock.BlockerOverlayActivity { *; }
-keep class com.mdnahid.prayerlock.AppBlockerChannel { *; }
