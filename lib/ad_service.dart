import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdReady = false;

  // 測試廣告 ID（正式上線前需要替換為真實 ID）
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  static void initialize() {
    MobileAds.instance.initialize();
  }

  static BannerAd? createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => print('Banner ad loaded'),
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: $error');
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
          print('Interstitial ad failed to load: $error');
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
