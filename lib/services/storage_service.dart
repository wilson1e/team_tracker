import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/match.dart';
import '../exceptions.dart';

class StorageService {
  static const String _matchesKey = 'matches';
  static const String _homeJerseyKey = 'homeJerseyColor';
  static const String _awayJerseyKey = 'awayJerseyColor';
  
  late SharedPreferences _prefs;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      throw StorageException('初始化存儲失敗: $e', code: 'INIT_FAILED');
    }
  }

  // Matches CRUD with Result type
  Result<List<Match>> getMatches() {
    try {
      final savedMatches = _prefs.getString(_matchesKey);
      if (savedMatches != null) {
        final List<dynamic> decoded = json.decode(savedMatches);
        final matches = decoded.map((m) => 
          Match.fromJson(Map<String, dynamic>.from(m))
        ).toList();
        return Result.success(matches);
      }
      return Result.success([]);
    } catch (e) {
      return Result.failure(StorageException(
        '讀取比賽數據失敗: $e',
        code: 'READ_FAILED',
      ));
    }
  }

  Future<Result<void>> saveMatches(List<Match> matches) async {
    try {
      final jsonList = matches.map((m) => m.toJson()).toList();
      await _prefs.setString(_matchesKey, json.encode(jsonList));
      return Result.success(null);
    } catch (e) {
      return Result.failure(StorageException(
        '保存比賽數據失敗: $e',
        code: 'WRITE_FAILED',
      ));
    }
  }

  // Settings
  String? getHomeJerseyColor() {
    return _prefs.getString(_homeJerseyKey);
  }

  String? getAwayJerseyColor() {
    return _prefs.getString(_awayJerseyKey);
  }

  Result<void> setHomeJerseyColor(String color) {
    try {
      _prefs.setString(_homeJerseyKey, color);
      return Result.success(null);
    } catch (e) {
      return Result.failure(StorageException(
        '保存主場球衣失敗: $e',
        code: 'SET_HOME_FAILED',
      ));
    }
  }

  Result<void> setAwayJerseyColor(String color) {
    try {
      _prefs.setString(_awayJerseyKey, color);
      return Result.success(null);
    } catch (e) {
      return Result.failure(StorageException(
        '保存作客球衣失敗: $e',
        code: 'SET_AWAY_FAILED',
      ));
    }
  }
}