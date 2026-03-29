/// AI Prediction Service - 未來擴展用
/// 參考 MiroFish 多智能體概念
/// 
/// 用途：
/// - 預測比賽結果
/// - 分析球員表現
/// - 天氣/場地建議
/// - 球隊實力評估
abstract class AIPredictionService {
  /// 預測比賽結果
  /// 輸入：主隊、客隊、聯賽、場地
  /// 輸出：預測結果 (主隊勝/客隊勝/和波)
  Future<AIMatchPrediction> predictMatchResult({
    required String homeTeam,
    required String awayTeam,
    required String league,
    String? venue,
  });
  
  /// 分析球隊實力
  Future<TeamAnalysis> analyzeTeamStrength({
    required String teamName,
    List<String>? recentOpponents,
  });
  
  /// 建議最佳陣容
  Future<List<PlayerSuggestion>> suggestLineup({
    required String teamName,
    required String opponent,
  });
}

/// 比賽預測結果
class AIMatchPrediction {
  final String predictedWinner;
  final double confidence; // 0.0 - 1.0
  final String reasoning;
  final Map<String, dynamic> factors;

  AIMatchPrediction({
    required this.predictedWinner,
    required this.confidence,
    required this.reasoning,
    this.factors = const {},
  });
}

/// 球隊分析結果
class TeamAnalysis {
  final String teamName;
  final int strengthScore; // 0-100
  final String strengthLevel; // 強/中/弱
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> recommendations;

  TeamAnalysis({
    required this.teamName,
    required this.strengthScore,
    required this.strengthLevel,
    this.strengths = const [],
    this.weaknesses = const [],
    this.recommendations = const [],
  });
}

/// 球員建議
class PlayerSuggestion {
  final String playerName;
  final String position;
  final String reason;
  final double rating;

  PlayerSuggestion({
    required this.playerName,
    required this.position,
    required this.reason,
    required this.rating,
  });
}

/// Stub implementation - 等真正接 AI 時實現
class StubAIPredictionService implements AIPredictionService {
  @override
  Future<AIMatchPrediction> predictMatchResult({
    required String homeTeam,
    required String awayTeam,
    required String league,
    String? venue,
  }) async {
    // Stub: 隨機預測
    final winners = [homeTeam, awayTeam, '和波'];
    return AIMatchPrediction(
      predictedWinner: winners[DateTime.now().second % 3],
      confidence: 0.5,
      reasoning: 'AI 服務尚未接入 - .stub mode',
      factors: {'mode': 'stub'},
    );
  }

  @override
  Future<TeamAnalysis> analyzeTeamStrength({
    required String teamName,
    List<String>? recentOpponents,
  }) async {
    return TeamAnalysis(
      teamName: teamName,
      strengthScore: 70,
      strengthLevel: '中',
      strengths: ['進攻效率中等', '防守穩定'],
      weaknesses: ['替補深度不足'],
      recommendations: ['建議輪換球員', '加強訓練'],
    );
  }

  @override
  Future<List<PlayerSuggestion>> suggestLineup({
    required String teamName,
    required String opponent,
  }) async {
    return [
      PlayerSuggestion(
        playerName: '球員A',
        position: '前鋒',
        reason: '對手防守弱點',
        rating: 8.5,
      ),
    ];
  }
}