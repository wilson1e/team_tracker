import 'package:cloud_firestore/cloud_firestore.dart';

class UserPlanService {
  static const _adminUid = 'oVRpJs75q3erE4XZeI7oHl0dtVs1';
  static const freePlan = 'free';
  static const standardPlan = 'standard';
  static const proPlan = 'pro';
  static const subscriptionFree = 'free';
  static const subscriptionTrial = 'trial';
  static const subscriptionActive = 'active';
  static const subscriptionCanceled = 'canceled';
  static const subscriptionExpired = 'expired';

  static bool isAdmin(String uid) => uid == _adminUid;

  static Future<Map<String, dynamic>> fetchLimits(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      final plan = _effectivePlan(data);
      final activePlanCap = _maxTeams(plan);
      final packBonus = _intValue(data['packTeams']);
      final createCap = _createCap(data, activePlanCap, packBonus);
      final retainedTeamCap = _intValue(
        data['retainedTeamCap'],
        fallback: _freeTeamCap,
      );
      final accessCap = _resolveAccessCap(
        createCap: createCap,
        packBonus: packBonus,
        retainedTeamCap: retainedTeamCap,
      );
      final subscriptionStatus = _subscriptionStatus(data);
      final hasEverPaidSubscription = data['hasEverPaidSubscription'] == true;
      return {
        'plan': plan,
        'subscriptionStatus': subscriptionStatus,
        'trialUsed': data['trialUsed'] == true,
        'hasEverPaidSubscription': hasEverPaidSubscription,
        'packTeams': packBonus,
        'retainedTeamCap': retainedTeamCap,
        'activePlanCap': activePlanCap,
        'createCap': createCap,
        'accessCap': accessCap,
        'maxTeams': accessCap,
        'isTrialActive': subscriptionStatus == subscriptionTrial,
        'isRetentionOnly': hasEverPaidSubscription && accessCap > createCap,
        'maxPlayers': _maxPlayers(plan),
        'maxPhotos': _maxPhotos(plan),
        'noAds': plan != 'free',
        'drillCustom': plan != 'free',
      };
    } catch (_) {
      return {
        'plan': 'free',
        'subscriptionStatus': subscriptionFree,
        'trialUsed': false,
        'hasEverPaidSubscription': false,
        'packTeams': 0,
        'retainedTeamCap': _freeTeamCap,
        'activePlanCap': _freeTeamCap,
        'createCap': _freeTeamCap,
        'accessCap': _freeTeamCap,
        'maxTeams': 1,
        'isTrialActive': false,
        'isRetentionOnly': false,
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

  static String _subscriptionStatus(Map<String, dynamic> data) {
    return (data['subscriptionStatus'] as String?) ?? subscriptionFree;
  }

  static const int _freeTeamCap = 1;

  static int _createCap(
    Map<String, dynamic> data,
    int activePlanCap,
    int packBonus,
  ) {
    final overrideCap = _intValue(data['maxTeams']);
    if (overrideCap > 0) {
      return [
        overrideCap,
        _freeTeamCap + packBonus,
      ].reduce((a, b) => a > b ? a : b);
    }
    return activePlanCap + packBonus;
  }

  static int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static int _resolveAccessCap({
    required int createCap,
    required int packBonus,
    required int retainedTeamCap,
  }) {
    final freeAccessCap = _freeTeamCap + packBonus;
    return [
      createCap,
      retainedTeamCap,
      freeAccessCap,
    ].reduce((a, b) => a > b ? a : b);
  }

  static int _maxTeams(String plan) => plan == 'pro'
      ? 5
      : plan == 'standard'
      ? 3
      : 1;
  static int _maxPlayers(String plan) => plan == 'pro'
      ? 25
      : plan == 'standard'
      ? 20
      : 15;
  static int _maxPhotos(String plan) => plan == 'pro'
      ? 999999
      : plan == 'standard'
      ? 100
      : 50;
}
