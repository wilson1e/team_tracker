import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
export 'package:google_mobile_ads/google_mobile_ads.dart' show AdWidget;

class AdService {
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdReady = false;

  // Ad unit IDs — swap the TODO values for real IDs before release
  static String get bannerAdUnitId => Platform.isIOS
      ? 'ca-app-pub-4385478710579461/3407504997'
      : 'ca-app-pub-3940256099942544/6300978111'; // TODO: replace with real Android banner ID

  static String get interstitialAdUnitId => Platform.isIOS
      ? 'ca-app-pub-4385478710579461/5427163670'
      : 'ca-app-pub-3940256099942544/1033173712'; // TODO: replace with real Android interstitial ID

  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize()
          .timeout(const Duration(seconds: 5));
    } catch (e, st) {
      debugPrint('AdService.initialize failed (non-fatal): $e\n$st');
      // 靜默失敗，不影響 app 啟動（BlueStacks / 無 GMS 環境）
    }
  }

  static BannerAd? createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint('Banner ad loaded'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
    return _bannerAd;
  }

  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  static void showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  static void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
  }
}
