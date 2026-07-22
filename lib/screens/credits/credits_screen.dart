import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});
  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  bool _loading = true;
  List<Map<String, dynamic>> _rawCredits = [];
  List<Map<String, dynamic>> _plans = [];
  String? _purchasing;
  String _companyId = '';
  int _selectedTypeIndex = 0; // 0 = TRANSCRIPT, 1 = AI_CALL

  // Teal for Transcript, Rose for AI Call — distinct from app's indigo/purple theme
  static const _transcriptGradient = [Color(0xFF0F766E), Color(0xFF0D9488)];
  static const _aiCallGradient = [Color(0xFF9F1239), Color(0xFFE11D48)];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await _auth.getUser();
    _companyId = user?.companyId ?? '';
    await _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadCredits(), _loadPlans()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCredits() async {
    if (_companyId.isEmpty) return;
    try {
      final res = await _api.getCredits();
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      _rawCredits = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _rawCredits = [];
    }
  }

  Future<void> _loadPlans() async {
    try {
      final res = await _api.getActivePlans();
      final raw = res.data;
      final list = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) as List : []);
      _plans = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _plans = [];
    }
  }

  int get _transcriptBalance {
    return _rawCredits
        .where((c) => c['creditType'] == 'TRANSCRIPT' || c['creditType'] == null)
        .fold(0, (sum, c) => sum + ((c['remainingCredits'] ?? 0) as num).toInt());
  }

  int get _aiCallBalance {
    return _rawCredits
        .where((c) => c['creditType'] == 'AI_CALL')
        .fold(0, (sum, c) => sum + ((c['remainingCredits'] ?? 0) as num).toInt());
  }

  int get _currentBalance =>
      _selectedTypeIndex == 0 ? _transcriptBalance : _aiCallBalance;

  List<Color> get _currentGradient =>
      _selectedTypeIndex == 0 ? _transcriptGradient : _aiCallGradient;

  List<Map<String, dynamic>> get _visiblePlans {
    final type = _selectedTypeIndex == 0 ? 'TRANSCRIPT' : 'AI_CALL';
    return _plans.where((p) => p['planType'] == type).toList();
  }

  String _durationLabel(String? d) {
    switch (d) {
      case 'DAY':
        return 'Day';
      case 'WEEK':
        return 'Week';
      case 'MONTH':
        return 'Month';
      case 'YEAR':
        return 'Year';
      case 'MIN_30':
        return '30 Min';
      default:
        return d ?? '';
    }
  }

  String _creditRate(Map<String, dynamic> plan) {
    final price = (plan['price'] ?? 0) as num;
    final credits = (plan['credits'] ?? 1) as num;
    if (price <= 0 || credits <= 0) return '';
    return '₹${(price / credits).toStringAsFixed(3)} per credit';
  }

  int? _bestValueIndex(List<Map<String, dynamic>> plans) {
    if (plans.length <= 1) return null;
    double bestRatio = 0;
    int? idx;
    for (int i = 0; i < plans.length; i++) {
      final price = (plans[i]['price'] ?? 1) as num;
      final credits = (plans[i]['credits'] ?? 0) as num;
      if (price <= 0) continue;
      final ratio = credits / price;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        idx = i;
      }
    }
    return idx;
  }

  Future<void> _purchase(Map<String, dynamic> plan) async {
    if (_companyId.isEmpty) {
      _msg('Company not found', error: true);
      return;
    }
    setState(() => _purchasing = plan['id']);
    try {
      await _api.purchaseCredits(companyId: _companyId, planId: plan['id']);
      _msg('${plan['name']} purchased! ${plan['credits']} credits added.');
      _loadAll();
    } catch (e) {
      _msg('Purchase failed: $e', error: true);
    }
    if (mounted) setState(() => _purchasing = null);
  }

  void _confirmPurchase(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Buy ${plan['label'] ?? plan['name']}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogRow('Credits', '${plan['credits']}'),
            _dialogRow('Price', '₹${plan['price']}'),
            if ((plan['duration'] as String?) != null)
              _dialogRow('Duration', _durationLabel(plan['duration']?.toString())),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _currentGradient[0]),
            onPressed: () {
              Navigator.pop(ctx);
              _purchase(plan);
            },
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildTypeSelector(),
          const SizedBox(height: 16),
          _buildBalanceCard(),
          const SizedBox(height: 24),
          if (_visiblePlans.isNotEmpty) ...[
            _sectionHeader('Credit Packages'),
            const SizedBox(height: 12),
            _buildPlanCards(),
            const SizedBox(height: 24),
          ] else ...[
            _buildNoPlansBanner(),
            const SizedBox(height: 24),
          ],
          _sectionHeader('Transaction History'),
          const SizedBox(height: 10),
          ..._buildTransactionRows(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(2, (i) {
          final selected = i == _selectedTypeIndex;
          final label = i == 0 ? 'Transcript' : 'AI Call';
          final color = i == 0 ? _transcriptGradient[0] : _aiCallGradient[0];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTypeIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final label = _selectedTypeIndex == 0 ? 'Transcript' : 'AI Call';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _currentGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _currentGradient[0].withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label Credits',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_currentBalance',
                  style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  'credits remaining',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _selectedTypeIndex == 0 ? Icons.receipt_long_rounded : Icons.phone_in_talk_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCards() {
    final plans = _visiblePlans;
    final bestIdx = _bestValueIndex(plans);

    if (plans.length == 1) {
      return _PricingCard(
        plan: plans[0],
        gradient: _currentGradient,
        isBestValue: false,
        isPurchasing: _purchasing == plans[0]['id'],
        durationLabel: _durationLabel(plans[0]['duration']?.toString()),
        creditRate: _creditRate(plans[0]),
        onBuy: () => _confirmPurchase(plans[0]),
        width: double.infinity,
      );
    }

    final cardWidth = MediaQuery.of(context).size.width * 0.66;
    return SizedBox(
      height: 290,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _PricingCard(
          plan: plans[i],
          gradient: _currentGradient,
          isBestValue: i == bestIdx,
          isPurchasing: _purchasing == plans[i]['id'],
          durationLabel: _durationLabel(plans[i]['duration']?.toString()),
          creditRate: _creditRate(plans[i]),
          onBuy: () => _confirmPurchase(plans[i]),
          width: cardWidth,
        ),
      ),
    );
  }

  Widget _buildNoPlansBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Center(
        child: Text(
          'No packages available',
          style: const TextStyle(color: AppColors.textHint, fontSize: 13),
        ),
      ),
    );
  }

  List<Widget> _buildTransactionRows() {
    if (_rawCredits.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('No transactions yet', style: TextStyle(color: AppColors.textHint))),
        ),
      ];
    }

    return _rawCredits.map((t) {
      final total = (t['totalCredits'] ?? 0) as num;
      final used = (t['usedCredits'] ?? 0) as num;
      final remaining = (t['remainingCredits'] ?? 0) as num;
      final planName = t['plan']?['name'] ?? t['plan']?['label'] ?? 'Credit Package';
      final creditType = t['creditType'] ?? 'TRANSCRIPT';
      final typeColor = creditType == 'AI_CALL' ? _aiCallGradient[0] : _transcriptGradient[0];
      final typeLabel = creditType == 'AI_CALL' ? 'AI Call' : 'Transcript';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bolt_rounded, size: 20, color: typeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(planName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(typeLabel, style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Used: $used / $total',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${total.toInt()}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: typeColor),
                ),
                Text(
                  '$remaining left',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _PricingCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final List<Color> gradient;
  final bool isBestValue;
  final bool isPurchasing;
  final String durationLabel;
  final String creditRate;
  final VoidCallback onBuy;
  final double width;

  const _PricingCard({
    required this.plan,
    required this.gradient,
    required this.isBestValue,
    required this.isPurchasing,
    required this.durationLabel,
    required this.creditRate,
    required this.onBuy,
    required this.width,
  });

  String _formatNum(dynamic n) {
    final val = (n as num).toInt();
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}K';
    return '$val';
  }

  @override
  Widget build(BuildContext context) {
    final name = plan['label'] ?? plan['name'] ?? '';
    final price = plan['price'] ?? 0;
    final credits = plan['credits'] ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isBestValue ? gradient[0] : const Color(0xFFE2E8F0),
              width: isBestValue ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isBestValue
                    ? gradient[0].withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: isBestValue ? 24 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coloured header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Column(
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (durationLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          durationLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Price + details
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  children: [
                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('₹', style: TextStyle(color: gradient[0], fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                        Text(
                          '$price',
                          style: TextStyle(
                            color: gradient[0],
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: AppColors.surfaceLight, height: 1),
                    const SizedBox(height: 12),

                    // Credits
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, size: 17, color: gradient[0]),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatNum(credits)} credits',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: gradient[0]),
                        ),
                      ],
                    ),
                    if (creditRate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(creditRate, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                    const SizedBox(height: 16),

                    // Buy button
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: isPurchasing ? null : onBuy,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: isPurchasing
                                ? null
                                : LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                            color: isPurchasing ? AppColors.surfaceLight : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isPurchasing
                              ? Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: gradient[0]),
                                  ),
                                )
                              : const Text(
                                  'Buy Now',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Best value ribbon badge
        if (isBestValue)
          Positioned(
            top: -1,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                color: Color(0xFFD97706),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: const Text(
                'BEST VALUE',
                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
            ),
          ),
      ],
    );
  }
}
