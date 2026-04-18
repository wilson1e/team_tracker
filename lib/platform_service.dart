// Conditional import: web uses stub, native uses dart:io
export 'platform_service_web.dart'
    if (dart.library.io) 'platform_service_native.dart';
