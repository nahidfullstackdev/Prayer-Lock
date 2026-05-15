import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Pure math for Qibla direction. Independent of any sensor package.
///
/// Uses the great-circle initial bearing formula, which gives the bearing
/// from true north at the user's location toward the Kaaba in Mecca.
class QiblaMath {
  /// Kaaba coordinates in Makkah.
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  /// Returns the Qibla bearing from true north, in degrees [0, 360).
  ///
  /// This is a static property of the user's location — it does not change
  /// as the device rotates. To get the needle rotation, subtract the
  /// device's compass heading from this value (mod 360).
  static double calculateQiblaBearing(double userLat, double userLng) {
    final phi1 = _toRad(userLat);
    final phi2 = _toRad(kaabaLatitude);
    final deltaLambda = _toRad(kaabaLongitude - userLng);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final bearingRad = math.atan2(y, x);
    final bearingDeg = bearingRad * 180 / math.pi;
    return (bearingDeg + 360) % 360;
  }

  /// Great-circle distance from the user to the Kaaba in kilometers.
  static double distanceToKaabaKm(double userLat, double userLng) {
    return Geolocator.distanceBetween(
          userLat,
          userLng,
          kaabaLatitude,
          kaabaLongitude,
        ) /
        1000;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
