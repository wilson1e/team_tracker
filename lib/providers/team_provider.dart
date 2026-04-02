import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../services/storage_service.dart';

class TeamProvider extends ChangeNotifier {
  final StorageService _storageService;
  
  List<Match> _matches = [];
  String? _homeJerseyColor;
  String? _awayJerseyColor;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  TeamProvider(this._storageService);

  // Getters
  List<Match> get matches => _matches;
  String? get homeJerseyColor => _homeJerseyColor;
  String? get awayJerseyColor => _awayJerseyColor;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get hasError => _error != null;
  bool get hasSuccess => _successMessage != null;

  // Clear messages
  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  // Initialize data
  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = _storageService.getMatches();
    
    result.when(
      success: (data) {
        _matches = data;
        _homeJerseyColor = _storageService.getHomeJerseyColor();
        _awayJerseyColor = _storageService.getAwayJerseyColor();
      },
      failure: (e) {
        _error = e.message;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  // Add match with validation
  Future<bool> addMatch(Match match) async {
    // Validation
    if (match.date.isEmpty || match.opponent.isEmpty) {
      _error = '請填寫必要資料';
      notifyListeners();
      return false;
    }

    try {
      _matches.add(match);
      final result = await _storageService.saveMatches(_matches);

      result.when(
        success: (_) {
          _successMessage = '比賽已添加';
          _error = null;
        },
        failure: (e) {
          _matches.removeLast(); // Rollback
          _error = e.message;
        },
      );
      
      notifyListeners();
      return result.isSuccess;
    } catch (e) {
      _error = '添加失敗: $e';
      notifyListeners();
      return false;
    }
  }

  // Update match
  Future<bool> updateMatch(int index, Match match) async {
    if (index < 0 || index >= _matches.length) {
      _error = '無效既比賽 index';
      notifyListeners();
      return false;
    }

    final oldMatch = _matches[index];
    _matches[index] = match;

    final result = await _storageService.saveMatches(_matches);
    
    result.when(
      success: (_) {
        _successMessage = '比賽已更新';
        _error = null;
      },
      failure: (e) {
        _matches[index] = oldMatch; // Rollback
        _error = e.message;
      },
    );
    
    notifyListeners();
    return result.isSuccess;
  }

  // Delete match
  Future<bool> deleteMatch(int index) async {
    if (index < 0 || index >= _matches.length) {
      _error = '無效既比賽 index';
      notifyListeners();
      return false;
    }

    final removedMatch = _matches.removeAt(index);
    final result = await _storageService.saveMatches(_matches);
    
    result.when(
      success: (_) {
        _successMessage = '比賽已刪除';
        _error = null;
      },
      failure: (e) {
        _matches.insert(index, removedMatch); // Rollback
        _error = e.message;
      },
    );
    
    notifyListeners();
    return result.isSuccess;
  }

  // Save all matches
  Future<bool> saveAllMatches(List<Match> matches) async {
    final result = await _storageService.saveMatches(matches);
    
    result.when(
      success: (_) {
        _matches = matches;
        _successMessage = '保存成功';
        _error = null;
      },
      failure: (e) {
        _error = e.message;
      },
    );
    
    notifyListeners();
    return result.isSuccess;
  }

  // Jersey colors
  Future<void> setHomeJerseyColor(String? color) async {
    if (color == null) {
      _homeJerseyColor = null;
      notifyListeners();
      return;
    }

    final result = _storageService.setHomeJerseyColor(color);
    result.when(
      success: (_) {
        _homeJerseyColor = color;
        _error = null;
      },
      failure: (e) {
        _error = e.message;
      },
    );
    notifyListeners();
  }

  Future<void> setAwayJerseyColor(String? color) async {
    if (color == null) {
      _awayJerseyColor = null;
      notifyListeners();
      return;
    }

    final result = _storageService.setAwayJerseyColor(color);
    result.when(
      success: (_) {
        _awayJerseyColor = color;
        _error = null;
      },
      failure: (e) {
        _error = e.message;
      },
    );
    notifyListeners();
  }
}