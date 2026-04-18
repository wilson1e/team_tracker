// Web stub — dart:io 不可用，所有平台相關功能回傳 false/no-op
import 'package:flutter/widgets.dart';

bool get isIOS => false;
bool get isAndroid => false;
Future<void> requestATT() async {} // no-op on web

// File helpers — web has no local filesystem
ImageProvider? fileImageOrNull(String? path) => null;
bool fileExists(String path) => false;
