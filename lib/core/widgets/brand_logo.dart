import 'package:flutter/material.dart';

/// App icon rendered from the same source assets used by the native
/// launcher/AppIcon generators. The light variant is used in light mode
/// and the dark variant in dark mode so the logo sits naturally on either
/// background.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 96,
    this.brightness,
  });

  final double size;

  /// Override the auto-detected brightness. When null, reads
  /// `Theme.of(context).brightness`.
  final Brightness? brightness;

  static const _darkAsset = 'assets/android/play_store_512.png';
  static const _lightAsset = 'assets/light/AppIcon_512_light.png';

  static String assetFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkAsset : _lightAsset;

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    return Image.asset(
      assetFor(b),
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
    );
  }
}
