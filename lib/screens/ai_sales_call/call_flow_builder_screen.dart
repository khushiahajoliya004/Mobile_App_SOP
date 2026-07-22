import 'dart:math';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const double _nW    = 152.0;  // node card width
const double _nH    = 98.0;   // node card height
const double _pW    = 44.0;   // placeholder circle diameter
const double _hGap  = 24.0;   // horizontal gap between subtrees
const double _vGap  = 76.0;   // vertical gap (parent bottom → child top)
const double _mg    = 52.0;   // canvas margin
const double _badgeR = 13.0;

// ─── Node model ───────────────────────────────────────────────────────────────
class _Node {
  String questionText;
  List<String> otherPredictions;
  _Node? yes;
  _Node? no;

  _Node({required this.questionText, List<String>? otherPredictions, this.yes, this.no})
      : otherPredictions = otherPredictions ?? [];

  static _Node? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return _Node(
      questionText: m['questionText']?.toString() ?? '',
      otherPredictions: (m['otherPredictions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      yes: fromMap(m['yes'] is Map ? Map<String, dynamic>.from(m['yes'] as Map) : null),
      no:  fromMap(m['no']  is Map ? Map<String, dynamic>.from(m['no']  as Map) : null),
    );
  }

  Map<String, dynamic> toMap() => {
    'questionText': questionText,
    if (otherPredictions.isNotEmpty) 'otherPredictions': otherPredictions,
    if (yes != null) 'yes': yes!.toMap(),
    if (no  != null) 'no':  no!.toMap(),
  };
}

// ─── Layout node ─────────────────────────────────────────────────────────────
// Each real _Node in the tree gets an _L wrapper for canvas positioning.
// Null-node _L entries are placeholder circles (YES, NO, or OTHER).
class _L {
  final _Node? node;         // null → placeholder circle
  final String  branch;      // 'ROOT' | 'YES' | 'NO' | 'OTHER'
  final int     depth;
  final _Node?  parentNode;  // set on placeholders so they know where to attach
  double x = 0, y = 0;      // center-x, top-y on canvas
  double sw = 0;             // total subtree width (used for layout)
  _L? yes, no, other;

  _L({this.node, required this.branch, required this.depth, this.parentNode});
}

// Build layout tree. Every real node always gets YES, NO, and OTHER children.
// YES/NO children are either a real _L (if the node has that child) or a
// placeholder _L (circle). OTHER is always a placeholder.
_L _buildLayout(_Node? node, String branch, int depth, {_Node? parentNode}) {
  final l = _L(node: node, branch: branch, depth: depth, parentNode: parentNode);
  if (node == null) { l.sw = _pW; return l; }

  l.yes   = _buildLayout(node.yes, 'YES',   depth + 1, parentNode: node);
  l.no    = _buildLayout(node.no,  'NO',    depth + 1, parentNode: node);
  l.other = _L(node: null, branch: 'OTHER', depth: depth + 1, parentNode: node)..sw = _pW;

  // Total child row width: YES-subtree  gap  NO-subtree  gap  OTHER-circle
  final childW = l.yes!.sw + _hGap + l.no!.sw + _hGap + _pW;
  l.sw = max(_nW, childW);
  return l;
}

// Assign x/y positions top-down given a center-x and top-y for this node.
void _position(_L l, double cx, double ty) {
  l.x = cx; l.y = ty;
  if (l.node == null) return;

  final childW = l.yes!.sw + _hGap + l.no!.sw + _hGap + _pW;
  final le     = cx - childW / 2;
  final childY = ty + _nH + _vGap;

  _position(l.yes!, le + l.yes!.sw / 2,                                  childY);
  _position(l.no!,  le + l.yes!.sw + _hGap + l.no!.sw / 2,              childY);
  l.other!.x = le + l.yes!.sw + _hGap + l.no!.sw + _hGap + _pW / 2;
  l.other!.y = childY;
}

// Total canvas height for the subtree rooted at l.
double _treeH(_L l) {
  if (l.node == null) return _pW;
  return _nH + _vGap + max(max(_treeH(l.yes!), _treeH(l.no!)), _pW);
}

// Flatten layout tree to a list (DFS). Includes placeholder circles.
List<_L> _flatten(_L l) {
  final r = <_L>[l];
  if (l.node != null) {
    r.addAll(_flatten(l.yes!));
    r.addAll(_flatten(l.no!));
    r.add(l.other!);
  }
  return r;
}

// ─── Painter ─────────────────────────────────────────────────────────────────
class _FlowPainter extends CustomPainter {
  final _L root;
  _FlowPainter(this.root);

  static const _yesColor   = Color(0xFF22C55E);
  static const _noColor    = Color(0xFFEF4444);
  static const _otherColor = Color(0xFFF97316);

  @override
  void paint(Canvas canvas, Size size) => _drawNode(canvas, root);

  void _drawNode(Canvas canvas, _L l) {
    if (l.node == null) return;
    // Draw all three branches from every real node.
    _drawBranch(canvas, l, l.yes!,   _yesColor,   'Yes',   dashed: false);
    _drawBranch(canvas, l, l.no!,    _noColor,    'No',    dashed: false);
    _drawBranch(canvas, l, l.other!, _otherColor, 'Other', dashed: true);
    _drawNode(canvas, l.yes!);
    _drawNode(canvas, l.no!);
  }

  void _drawBranch(Canvas canvas, _L parent, _L child, Color color, String label, {required bool dashed}) {
    final p1 = Offset(parent.x, parent.y + _nH);
    final p2 = Offset(child.x,  child.y + (child.node == null ? _pW / 2 : 0));

    final paint = Paint()
      ..color      = color.withValues(alpha: 0.65)
      ..strokeWidth = 2.2
      ..style      = PaintingStyle.stroke;

    if (dashed) {
      _dashed(canvas, p1, p2, paint);
    } else {
      canvas.drawLine(p1, p2, paint);
    }

    // Label badge at 38% along the line
    final bx = p1.dx + (p2.dx - p1.dx) * 0.38;
    final by = p1.dy + (p2.dy - p1.dy) * 0.38;
    _badge(canvas, Offset(bx, by), color, label);
  }

  void _badge(Canvas canvas, Offset center, Color color, String text) {
    final w = text.length > 3 ? 46.0 : _badgeR * 2 + 4;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: _badgeR * 2),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, Paint()..color = color);

    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _dashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dash = 6.0, gap = 4.0;
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len, uy = dy / len;
    double d = 0; bool on = true;
    while (d < len) {
      final end = min(d + (on ? dash : gap), len);
      if (on) canvas.drawLine(
        Offset(p1.dx + ux * d, p1.dy + uy * d),
        Offset(p1.dx + ux * end, p1.dy + uy * end),
        paint,
      );
      d = end; on = !on;
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) => true;
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class CallFlowBuilderScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  const CallFlowBuilderScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  State<CallFlowBuilderScreen> createState() => _CallFlowBuilderScreenState();
}

class _CallFlowBuilderScreenState extends State<CallFlowBuilderScreen> {
  final _api = ApiService();
  bool _loading = true, _saving = false;
  _Node? _root;

  @override
  void initState() { super.initState(); _loadTree(); }

  Future<void> _loadTree() async {
    setState(() => _loading = true);
    try {
      final res  = await _api.getCallQuestionFlowTree(widget.categoryId);
      final raw  = res.data;
      final data = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : null;
      final rm   = data?['root'];
      if (mounted) setState(() {
        _root    = rm is Map ? _Node.fromMap(Map<String, dynamic>.from(rm)) : null;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.saveCallQuestionFlowTree(widget.categoryId, _root?.toMap());
      _msg('Flow saved', success: true);
    } catch (_) { _msg('Failed to save', error: true); }
    if (mounted) setState(() => _saving = false);
  }

  void _msg(String t, {bool error = false, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t),
      backgroundColor: error ? AppColors.error : success ? AppColors.success : null,
    ));
  }

  // ─── Question editor bottom-sheet ──────────────────────────────────────────

  Future<String?> _askQuestion(String title, {String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: StatefulBuilder(builder: (_, ss) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl, maxLines: 3, autofocus: true,
                onChanged: (_) => ss(() {}),
                decoration: InputDecoration(
                  hintText: 'Type the question here...',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                  filled: true, fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                _varChip('Customer Name', '{{customerName}}', ctrl, ss),
                _varChip('Phone',         '{{phoneNumber}}',  ctrl, ss),
                _varChip('Company',       '{{companyName}}',  ctrl, ss),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: ctrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, ctrl.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(initial.isEmpty ? 'Add' : 'Update', style: const TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ],
          )),
        ),
      ),
    );
  }

  Widget _varChip(String label, String token, TextEditingController ctrl, StateSetter ss) {
    return GestureDetector(
      onTap: () {
        final pos = ctrl.selection.baseOffset;
        final t   = ctrl.text;
        final ins = pos < 0 ? t + token : t.substring(0, pos) + token + t.substring(pos);
        ctrl.value = TextEditingValue(
          text: ins,
          selection: TextSelection.collapsed(offset: (pos < 0 ? t.length : pos) + token.length),
        );
        ss(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ─── Other predictions editor ───────────────────────────────────────────────

  Future<void> _editOther(_Node node) async {
    final draft = List<String>.from(node.otherPredictions);
    final ic    = TextEditingController();
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            const Text('Other — Predicted Responses', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Up to 4 responses that are neither Yes nor No.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            draft.isEmpty
                ? const Text('No responses yet.', style: TextStyle(fontSize: 12, color: AppColors.textHint))
                : Wrap(spacing: 6, runSpacing: 6, children: draft.asMap().entries.map((e) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(e.value, style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => ss(() => draft.removeAt(e.key)),
                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF7C3AED)),
                        ),
                      ]),
                    ),
                  ).toList()),
            if (draft.length < 4) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: ic,
                  decoration: InputDecoration(
                    hintText: 'Type a predicted response...',
                    filled: true, fillColor: AppColors.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (v) { if (v.trim().isNotEmpty) ss(() { draft.add(v.trim()); ic.clear(); }); },
                )),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () { if (ic.text.trim().isNotEmpty) ss(() { draft.add(ic.text.trim()); ic.clear(); }); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  child: const Text('Add'),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () { setState(() => node.otherPredictions = List.from(draft)); Navigator.pop(ctx); },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                child: const Text('Save'),
              )),
            ]),
          ]),
        ),
      )),
    );
  }

  // ─── AI Generate ───────────────────────────────────────────────────────────

  Future<void> _openAiGenerate() async {
    final ctrl = TextEditingController();
    _Node? preview;
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 16, 16, 0), child: Row(children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED), size: 18)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Generate with AI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.textHint), onPressed: () => Navigator.pop(ctx)),
            ])),
            const Divider(height: 20),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Describe what this call flow should cover', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(controller: ctrl, maxLines: 4, decoration: InputDecoration(hintText: 'e.g. Check if customer is interested, verify budget and financing needs.', hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint), filled: true, fillColor: AppColors.surfaceLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(12))),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    ss(() => preview = null);
                    try {
                      final res  = await _api.aiGenerateCallQuestionFlow(widget.categoryId, categoryName: widget.categoryName, summary: text);
                      final raw  = res.data;
                      final data = raw is Map ? Map<String, dynamic>.from(raw['data'] ?? raw) : null;
                      final rm   = data?['root'];
                      ss(() => preview = rm is Map ? _Node.fromMap(Map<String, dynamic>.from(rm)) : null);
                    } catch (_) { _msg('AI generation failed', error: true); }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Generate Tree', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF7C3AED)), SizedBox(width: 6), Text('Preview — review before applying', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)))]),
                    const SizedBox(height: 8),
                    Text(_previewText(preview), style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.5)),
                  ])),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Discard'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () { setState(() => _root = preview); Navigator.pop(ctx); _msg('AI tree applied — save when ready', success: true); },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                      child: const Text('Apply Tree'),
                    )),
                  ]),
                ],
              ]),
            )),
          ]),
        ),
      )),
    );
  }

  String _previewText(_Node? n, [int i = 0]) {
    if (n == null) return '';
    final p = '  ' * i;
    var t = '$p• ${n.questionText}\n';
    if (n.yes != null) t += '${p}  YES → ${_previewText(n.yes, i + 2).trimLeft()}';
    if (n.no  != null) t += '${p}  NO  → ${_previewText(n.no,  i + 2).trimLeft()}';
    if (n.otherPredictions.isNotEmpty) t += '${p}  OTHER: ${n.otherPredictions.join(', ')}\n';
    return t;
  }

  Future<bool> _confirmDelete() async {
    final r = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Question'),
      content: const Text('Delete this question and all its children?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Delete', style: TextStyle(color: AppColors.error))),
      ],
    ));
    return r == true;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBg,
      child: Column(children: [
        // Header
        Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 4, right: 16, bottom: 14),
          decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81), AppColors.primary],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          )),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.categoryName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              const Text('Question Flow Builder', style: TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
            _hBtn(Icons.auto_awesome_rounded, 'AI', _openAiGenerate),
            const SizedBox(width: 8),
            _hBtn(
              _saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              'Save',
              (_root == null || _saving) ? () {} : _save,
              disabled: _root == null || _saving,
            ),
          ]),
        ),

        // Canvas card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
                    : _root == null ? _buildEmpty() : _buildCanvas(),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _hBtn(IconData icon, String label, VoidCallback onTap, {bool disabled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: disabled ? Colors.white38 : Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: disabled ? Colors.white38 : Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.07), shape: BoxShape.circle), child: const Icon(Icons.account_tree_rounded, size: 36, color: AppColors.primary)),
      const SizedBox(height: 16),
      const Text('No questions yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      const Text('Add the first question to start\nbuilding the call flow', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () async {
          final t = await _askQuestion('Add First Question');
          if (t != null) setState(() => _root = _Node(questionText: t));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add First Question', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ]));
  }

  Widget _buildCanvas() {
    final layout = _buildLayout(_root!, 'ROOT', 0);
    final totalW = layout.sw + _mg * 2;
    final totalH = _treeH(layout) + _mg * 2;
    _position(layout, totalW / 2, _mg);
    final all = _flatten(layout);

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(80),
      minScale: 0.35,
      maxScale: 2.0,
      child: SizedBox(
        width: totalW,
        height: totalH,
        child: Stack(children: [
          CustomPaint(size: Size(totalW, totalH), painter: _FlowPainter(layout)),
          ...all.map(_buildNodeWidget),
        ]),
      ),
    );
  }

  // ─── Node / placeholder widgets ────────────────────────────────────────────

  static const List<Color> _nodeBg = [
    Color(0xFFEEF2FF), // depth 0 – soft lavender (matches web)
    Color(0xFFE0F2FE), // depth 1 – light sky
    Color(0xFFF0FDF4), // depth 2 – light green
    Color(0xFFFFFBEB), // depth 3 – light amber
  ];

  Widget _buildNodeWidget(_L l) {
    // ── Placeholder circles ──────────────────────────────────────────────────
    if (l.node == null) {
      if (l.branch == 'OTHER') {
        // Dashed orange "+" circle — tapping opens Other predictions editor
        return Positioned(
          left: l.x - _pW / 2,
          top: l.y,
          width: _pW,
          height: _pW,
          child: GestureDetector(
            onTap: () async {
              if (l.parentNode != null) {
                await _editOther(l.parentNode!);
                setState(() {});
              }
            },
            child: _dashedCircle(const Color(0xFFF97316)),
          ),
        );
      }

      // YES / NO placeholder — solid colored "+" circle
      final isYes = l.branch == 'YES';
      final color = isYes ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
      return Positioned(
        left: l.x - _pW / 2,
        top: l.y,
        width: _pW,
        height: _pW,
        child: GestureDetector(
          onTap: () async {
            final t = await _askQuestion('Add ${l.branch} Question');
            if (t != null && l.parentNode != null) {
              setState(() {
                if (l.branch == 'YES') { l.parentNode!.yes = _Node(questionText: t); }
                else                   { l.parentNode!.no  = _Node(questionText: t); }
              });
            }
          },
          child: _solidCircle(color),
        ),
      );
    }

    // ── Real node card ───────────────────────────────────────────────────────
    final bg   = _nodeBg[l.depth % _nodeBg.length];
    final node = l.node!;
    return Positioned(
      left:   l.x - _nW / 2,
      top:    l.y,
      width:  _nW,
      height: _nH,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.09)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Question text + edit / delete
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(
              node.questionText,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.38),
              maxLines: 4, overflow: TextOverflow.ellipsis,
            )),
            Column(mainAxisSize: MainAxisSize.min, children: [
              _nodeBtn(Icons.edit_rounded, AppColors.primary, () async {
                final t = await _askQuestion('Edit Question', initial: node.questionText);
                if (t != null) setState(() => node.questionText = t);
              }),
              const SizedBox(height: 3),
              _nodeBtn(Icons.delete_outline_rounded, AppColors.error, () async {
                if (await _confirmDelete()) setState(() => _findAndDelete(node));
              }),
            ]),
          ]),
        ]),
      ),
    );
  }

  // Solid circle with "+" icon
  Widget _solidCircle(Color color) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
    ),
    child: Icon(Icons.add_rounded, color: color, size: 20),
  );

  // Dashed circle with "+" icon (for Other branch)
  Widget _dashedCircle(Color color) => CustomPaint(
    painter: _DashedCirclePainter(color),
    child: Container(
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Icon(Icons.add_rounded, color: color, size: 20),
    ),
  );

  Widget _nodeBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }

  void _findAndDelete(_Node target) {
    if (_root == target) { _root = null; return; }
    _deleteFrom(_root, target);
  }

  void _deleteFrom(_Node? cur, _Node target) {
    if (cur == null) return;
    if (cur.yes == target) { cur.yes = null; return; }
    if (cur.no  == target) { cur.no  = null; return; }
    _deleteFrom(cur.yes, target);
    _deleteFrom(cur.no,  target);
  }
}

// ─── Dashed circle painter ────────────────────────────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style       = PaintingStyle.stroke;

    final r      = size.width / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const steps  = 24;
    const onAngle = (2 * pi) / steps;

    for (int i = 0; i < steps; i += 2) {
      final a1 = i * onAngle;
      final a2 = (i + 1) * onAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        a1, a2 - a1, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
