package com.mdnahid.prayerlock

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppBlockerChannel(
            context = applicationContext,
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
        ).register()
    }
}
