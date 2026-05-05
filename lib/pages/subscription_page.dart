import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/iap_service.dart';
import '../services/user_plan_service.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  static final Uri _termsUri = Uri.parse(
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );
  static final Uri _privacyUri = Uri.parse(
    'https://team-tracker-7e8a9.web.app/privacy_policy.html',
  );

  final _iap = IAPService();

  Map<String, dynamic> _limits = {};
  bool _loading = true;
  bool _purchasing = false;
  bool _isBeta = false;
  bool _storeAvailable = false;

  @override
  void initState() {
    super.initState();
    _iap.onPurchaseSuccess = _onSuccess;
    _iap.onPurchaseError = _onError;
    _iap.onPurchasePending = _onPending;
    _init();
  }

  Future<void> _init() async {
    _storeAvailable = await InAppPurchase.instance.isAvailable();
    await _iap.initialize();
    await _loadPlan();
  }

  Future<void> _loadPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final limits = await UserPlanService.fetchLimits(uid);
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final isBeta = doc.data()?['isBetaTester'] == true;
    if (mounted) {
      setState(() {
        _limits = limits;
        _isBeta = isBeta;
        _loading = false;
      });
    }
  }

  void _onSuccess(PurchaseDetails purchase) {
    if (!mounted) return;
    setState(() => _purchasing = false);
    _loadPlan(); // refresh plan display
    _showSnack('購買成功！方案已更新', Colors.green);
  }

  void _onError(String msg) {
    if (!mounted) return;
    setState(() => _purchasing = false);
    _showSnack(msg, Colors.red);
  }

  void _onPending() {
    if (!mounted) return;
    setState(() => _purchasing = true);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _currentPlan => _limits['plan'] as String? ?? 'free';

  Color _planColor(String plan) {
    if (plan == 'pro') return Colors.amber;
    if (plan == 'standard') return Colors.orange;
    return Colors.white54;
  }

  String _planLabel(String plan) {
    if (plan == 'pro') return '專業版';
    if (plan == 'standard') return '標準版';
    return '免費版';
  }

  String _productIdForPlan(String plan) {
    if (plan == 'standard') return IAPProductIds.standardMonthly;
    if (plan == 'pro') return IAPProductIds.proMonthly;
    return '';
  }

  String _priceForProduct(String productId) {
    final p = _iap.getProduct(productId);
    return p?.price ?? (productId.contains('standard') ? '\$38' : '\$68');
  }

  bool _supportsTrial(String plan) => plan == 'standard';

  String _confirmDescriptionForPlan(String plan) {
    if (_supportsTrial(plan)) {
      return '首月免費試用，其後每月自動續訂，可隨時取消';
    }
    return '每月自動續訂，可隨時取消';
  }

  String _packProductId(String name) {
    if (name.contains('+1')) return IAPProductIds.packTeam1;
    if (name.contains('+3')) return IAPProductIds.packTeam3;
    if (name.contains('+5')) return IAPProductIds.packTeam5;
    return '';
  }

  Future<void> _buyPlan(String plan) async {
    if (!_storeAvailable) {
      _showSnack('App Store 暫時無法連線，請稍後再試', Colors.orange);
      return;
    }
    final productId = _productIdForPlan(plan);
    if (productId.isEmpty) return;

    // Show confirmation dialog first
    final confirmed = await _showConfirmDialog(
      title: '升級至${_planLabel(plan)}',
      price: _priceForProduct(productId),
      desc: _confirmDescriptionForPlan(plan),
    );
    if (!confirmed) return;

    setState(() => _purchasing = true);
    await _iap.buySubscription(productId);
  }

  Future<void> _buyPack(String name, String fallbackPrice) async {
    if (!_storeAvailable) {
      _showSnack('App Store 暫時無法連線，請稍後再試', Colors.orange);
      return;
    }
    final productId = _packProductId(name);
    if (productId.isEmpty) return;

    final product = _iap.getProduct(productId);
    final price = product?.price ?? fallbackPrice;

    final confirmed = await _showConfirmDialog(
      title: '購買 $name',
      price: price,
      desc: '一次性付款，永久增加球隊上限',
    );
    if (!confirmed) return;

    setState(() => _purchasing = true);
    await _iap.buyPack(productId);
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String price,
    required String desc,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              price,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 14),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.45),
                children: [
                  const TextSpan(text: '完成購買即表示你同意 '),
                  TextSpan(
                    text: 'Terms of Use',
                    style: const TextStyle(
                      color: Colors.orange,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        unawaited(_openLegalUrl(_termsUri));
                      },
                  ),
                  const TextSpan(text: ' 及 '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: Colors.orange,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        unawaited(_openLegalUrl(_privacyUri));
                      },
                  ),
                  const TextSpan(text: '。'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('確認購買', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openLegalUrl(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showSnack('未能打開連結，請稍後再試', Colors.orange);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _purchasing = true);
    await _iap.restorePurchases();
    // onPurchaseSuccess will handle state update if anything is restored
    // If nothing to restore, stop spinner after a delay
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _purchasing = false);
  }

  @override
  void dispose() {
    _iap.onPurchaseSuccess = null;
    _iap.onPurchaseError = null;
    _iap.onPurchasePending = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            title: const Text('訂閱方案'),
            actions: [
              TextButton(
                onPressed: _restorePurchases,
                child: const Text(
                  '恢復購買',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentPlanBanner(),
                      const SizedBox(height: 12),
                      _buildSubscriptionStatusCard(),
                      const SizedBox(height: 24),
                      const Text(
                        '選擇方案',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPlanCard('free', '\$0', '免費使用'),
                      const SizedBox(height: 10),
                      _buildPlanCard('standard', '\$38', '每月'),
                      const SizedBox(height: 10),
                      _buildPlanCard('pro', '\$68', '每月'),
                      const SizedBox(height: 24),
                      const Text(
                        '擴展包',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '一次性付款，永久增加球隊上限',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      _buildPackCard(
                        '球隊 +1',
                        '\$10',
                        '額外增加 1 隊創建上限',
                        IAPProductIds.packTeam1,
                      ),
                      const SizedBox(height: 8),
                      _buildPackCard(
                        '球隊 +3',
                        '\$25',
                        '額外增加 3 隊創建上限',
                        IAPProductIds.packTeam3,
                      ),
                      const SizedBox(height: 8),
                      _buildPackCard(
                        '球隊 +5',
                        '\$40',
                        '額外增加 5 隊創建上限',
                        IAPProductIds.packTeam5,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '訂閱說明',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '標準版可提供首月免費試用（需先於 App Store Connect 啟用）。訂閱方案會自動續訂，可隨時於 App Store「訂閱項目」取消。',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openLegalUrl(_termsUri),
                                  icon: const Icon(Icons.description_outlined, size: 16),
                                  label: const Text('Terms of Use'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _openLegalUrl(_privacyUri),
                                  icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                                  label: const Text('Privacy Policy'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
        // Purchasing overlay
        if (_purchasing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    '處理中…',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentPlanBanner() {
    final plan = _currentPlan;
    final color = _planColor(plan);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '目前方案',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _planLabel(plan),
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isBeta) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange, width: 0.5),
                        ),
                        child: const Text(
                          'Beta',
                          style: TextStyle(color: Colors.orange, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionStatusCard() {
    final status = _limits['subscriptionStatus'] as String? ?? 'free';
    final trialUsed = _limits['trialUsed'] == true;
    final hasPaid = _limits['hasEverPaidSubscription'] == true;
    final createCap = _limits['createCap'] as int? ?? 1;
    final accessCap = _limits['accessCap'] as int? ?? 1;
    final retainedCap = _limits['retainedTeamCap'] as int? ?? 1;
    final message = status == 'trial'
        ? '你而家喺試用期內，可以暫時用到額外球隊。試用完如果未成功付款，超出免費上限嘅球隊會鎖住。'
        : hasPaid
        ? '你曾經成功付款，所以取消後可保留已有球隊；但新增球隊仍受當前建立上限限制。'
        : trialUsed
        ? '你已用過試用。若未成功付款，超出免費上限嘅球隊會維持鎖定。'
        : '目前係免費版。升級後可即時提高球隊上限。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '球隊權限摘要',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            '建立上限：$createCap  ｜  存取上限：$accessCap  ｜  保留上限：$retainedCap',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String plan, String fallbackPrice, String priceLabel) {
    final isCurrent = _currentPlan == plan;
    final color = _planColor(plan);
    final features = _planFeatures(plan);
    final supportsTrial = _supportsTrial(plan);

    // Use live price from store if available
    String displayPrice = fallbackPrice;
    if (plan != 'free') {
      final productId = _productIdForPlan(plan);
      final product = _iap.getProduct(productId);
      if (product != null) displayPrice = product.price;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? color : Colors.white12,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _planLabel(plan),
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  displayPrice,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  priceLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            if (supportsTrial) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(24),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.green.withAlpha(90)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.card_giftcard, size: 14, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      '首月免費試用',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 14,
                      color: (f['ok'] as bool) ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f['text'] as String,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: color.withAlpha(80)),
                      ),
                      child: Text('目前方案', style: TextStyle(color: color)),
                    )
                  : plan == 'free'
                  ? const SizedBox.shrink()
                  : ElevatedButton(
                      onPressed: _purchasing ? null : () => _buyPlan(plan),
                      style: ElevatedButton.styleFrom(backgroundColor: color),
                      child: const Text(
                        '升級',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _planFeatures(String plan) {
    final isPro = plan == 'pro';
    final isStd = plan == 'standard' || isPro;
    return [
      {
        'icon': Icons.groups,
        'text':
            '球隊上限：${isPro
                ? "5隊"
                : isStd
                ? "3隊"
                : "1隊"}',
        'ok': true,
      },
      {
        'icon': Icons.person,
        'text':
            '球員上限：${isPro
                ? "25人/隊"
                : isStd
                ? "20人/隊"
                : "15人/隊"}',
        'ok': true,
      },
      {
        'icon': Icons.photo,
        'text':
            '照片上限：${isPro
                ? "無限"
                : isStd
                ? "100張/隊"
                : "50張/隊"}',
        'ok': true,
      },
      {'icon': Icons.ads_click, 'text': isStd ? '無廣告' : '含廣告', 'ok': isStd},
      {'icon': Icons.fitness_center, 'text': '訓練細項自訂', 'ok': isStd},
      if (plan == 'standard')
        {'icon': Icons.card_giftcard, 'text': '首月免費試用（啟用後生效）', 'ok': true},
    ];
  }

  Widget _buildPackCard(
    String name,
    String fallbackPrice,
    String desc,
    String productId,
  ) {
    final product = _iap.getProduct(productId);
    final price = product?.price ?? fallbackPrice;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: const Icon(Icons.add_circle_outline, color: Colors.orange),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          desc,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Text(
              '永久',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        onTap: _purchasing ? null : () => _buyPack(name, fallbackPrice),
      ),
    );
  }
}
