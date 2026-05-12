# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Crashlytics — preserve crash report metadata
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }

# App Blocker — keep class names for Android system service resolution
-keep class com.mdnahid.prayerlock.PrayerLockAccessibilityService { *; }
-keep class com.mdnahid.prayerlock.BlockerWindowReceiver { *; }
-keep class com.mdnahid.prayerlock.BlockerOverlayActivity { *; }
-keep class com.mdnahid.prayerlock.AppBlockerChannel { *; }

# RevenueCat & Google Play Billing — defensive. The AARs ship consumer rules,
# but explicit -keep entries eliminate one variable when debugging release-only
# purchase failures.
-keep class com.revenuecat.purchases.** { *; }
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.revenuecat.purchases.**

# Play Core split-install (used by Flutter deferred components; not bundled in this app)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
