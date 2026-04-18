import 'package:cloud_firestore/cloud_firestore.dart';

class UserPlanService {
  static const _adminUid = 'oVRpJs75q3erE4XZeI7oHl0dtVs1';

  static bool isAdmin(String uid) => uid == _adminUid;

  static Future<Map<String, dynamic>> fetchLimits(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final plan = _effectivePlan(data);
      final baseTeams = _maxTeams(plan);
      final packBonus = (data['packTeams'] as int?) ?? 0;
      return {
        'plan': plan,
        'maxTeams': baseTeams + packBonus,
        'maxPlayers': _maxPlayers(plan),
        'maxPhotos': _maxPhotos(plan),
        'noAds': plan != 'free',
        'drillCustom': plan != 'free',
      };
    } catch (_) {
      return {
        'plan': 'free',
        'maxTeams': 1,
        'maxPlayers': 15,
        'maxPhotos': 50,
        'noAds': false,
        'drillCustom': false,
      };
    }
  }

  static String _effectivePlan(Map<String, dynamic> data) {
    if (data['isBetaTester'] == true) return 'standard';
    return (data['plan'] as String?) ?? 'free';
  }

  static int _maxTeams(String plan) =>
      plan == 'pro' ? 5 : plan == 'standard' ? 3 : 1;
  static int _maxPlayers(String plan) =>
      plan == 'pro' ? 25 : plan == 'standard' ? 20 : 15;
  static int _maxPhotos(String plan) =>
      plan == 'pro' ? 999999 : plan == 'standard' ? 100 : 50;
}
