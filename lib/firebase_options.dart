// ─── Firebase Options ────────────────────────────────────────────────────────
//
// IMPORTANT: This file contains placeholder values.
//
// Replace with real configuration:
//   1. Create a Firebase project at https://console.firebase.google.com
//   2. Add an Android app (com.mdnahid.prayerlock) and iOS app
//   3. Run: flutterfire configure --project=YOUR_PROJECT_ID
//      This regenerates this file with real keys.
//   4. Enable Authentication → Google & Email/Password in Firebase Console
//   5. Enable Firestore in Firebase Console
//
// Until you configure Firebase, auth features will not work and the app
// will throw on startup (Firebase.initializeApp will fail).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCDAZxv3IU-fvOYbgLmDkfecJ_xoDC4VT8',
    appId: '1:623519534939:android:a006ca2492b37a51b0547e',
    messagingSenderId: '623519534939',
    projectId: 'prayer-lock-fa061',
    databaseURL: 'https://prayer-lock-fa061-default-rtdb.firebaseio.com',
    storageBucket: 'prayer-lock-fa061.firebasestorage.app',
  );

  // TODO: Replace ALL values below by running `flutterfire configure`

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZlMoXHAVxcCqSxY31N76wMtdt34RCWKM',
    appId: '1:623519534939:ios:6e8d406fbc885bc9b0547e',
    messagingSenderId: '623519534939',
    projectId: 'prayer-lock-fa061',
    databaseURL: 'https://prayer-lock-fa061-default-rtdb.firebaseio.com',
    storageBucket: 'prayer-lock-fa061.firebasestorage.app',
    iosClientId: '623519534939-tnpngbe6g4m6cseminale37543t6h601.apps.googleusercontent.com',
    iosBundleId: 'com.mdnahid.prayerlock',
  );

}