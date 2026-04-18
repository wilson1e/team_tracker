import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';

bool get isIOS => Platform.isIOS;
bool get isAndroid => Platform.isAndroid;

Future<void> requestATT() async {
  if (!Platform.isIOS) return;
  try {
    await AppTrackingTransparency.requestTrackingAuthorization()
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    // non-fatal
  }
}

// File helpers
ImageProvider? fileImageOrNull(String? path) {
  if (path == null) return null;
  final f = File(path);
  return f.existsSync() ? FileImage(f) : null;
}

bool fileExists(String path) => File(path).existsSync();
