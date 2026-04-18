// Web stub — AdMob not supported on web
import 'package:flutter/widgets.dart';

class AdService {
  static Future<void> initialize() async {}
  static dynamic createBannerAd() => null;
  static void loadInterstitialAd() {}
  static void showInterstitialAd() {}
  static void dispose() {}
}

// Dummy AdWidget for web
class AdWidget extends StatelessWidget {
  // ignore: avoid_unused_constructor_parameters
  const AdWidget({super.key, required dynamic ad});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
