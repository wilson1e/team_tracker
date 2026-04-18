// Conditional export: web uses stub, native uses google_mobile_ads
export 'ad_service_web.dart'
    if (dart.library.io) 'ad_service_native.dart';
