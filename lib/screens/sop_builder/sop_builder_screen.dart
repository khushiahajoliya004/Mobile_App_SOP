import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class SopBuilderScreen extends StatefulWidget {
  final String? editId;
  const SopBuilderScreen({super.key, this.editId});
  @override
  State<SopBuilderScreen> createState() => _SopBuilderScreenState();
}

class _SopBuilderScreenState extends State<SopBuilderScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  bool _loading = false;
  bool _saving = false;
  String _companyId = '';

  final _nameCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _customerTypeCtrl = TextEditingController();
  String? _categoryId;
  String? _stageId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _stages = [];

  // Sections with questions
  final List<_Section> _sections = [];

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await _auth.getUser();
    _companyId = user?.companyId ?? '';
    _loadDropdowns();
    if (_isEdit) {
      _loadSop();
    } else {
      _sections.add(_Section());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _industryCtrl.dispose();
    _customerTypeCtrl.dispose();
    for (final s in _sections) {
      s.titleCtrl.dispose();
      s.descCtrl.dispose();
      for (final q in s.questions) q.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    try {
      final r = await _api.getCategories();
      _categories = _parseList(r.data);
    } catch (_) {}
    try {
      final r = await _api.getSalesStages();
      _stages = _parseList(r.data);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadSop() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getSop(widget.editId!);
      final sop = res.data is Map
          ? Map<String, dynamic>.from(res.data['data'] ?? res.data)
          : <String, dynamic>{};
      _nameCtrl.text = sop['name'] ?? '';
      _industryCtrl.text = sop['industry'] ?? '';
      _customerTypeCtrl.text = sop['customerType'] ?? '';
      _categoryId = sop['categoryId'];
      _stageId = sop['interactionStageId'];
      _sections.clear();
      for (final sec in (sop['sections'] ?? []) as List) {
        final s = _Section();
        s.titleCtrl.text = sec['title'] ?? '';
        s.descCtrl.text = sec['description'] ?? '';
        s.weightage = sec['weightage'] ?? 10;
        for (final q in (sec['questions'] ?? []) as List) {
          s.questions.add(TextEditingController(text: q['question'] ?? ''));
        }
        if (s.questions.isEmpty) s.questions.add(TextEditingController());
        _sections.add(s);
      }
      if (_sections.isEmpty) _sections.add(_Section());
    } catch (e) {
      _msg('Failed to load SOP: $e', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List)
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    if (raw is Map)
      return ((raw['data'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    return [];
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _msg('SOP name is required', error: true);
      return;
    }
    if (_industryCtrl.text.trim().isEmpty) {
      _msg('Industry is required', error: true);
      return;
    }

    setState(() => _saving = true);

    final sectionsList = <Map<String, dynamic>>[];
    for (int i = 0; i < _sections.length; i++) {
      final s = _sections[i];
      if (s.titleCtrl.text.trim().isEmpty) continue;
      final questionsList = <Map<String, dynamic>>[];
      for (int qi = 0; qi < s.questions.length; qi++) {
        if (s.questions[qi].text.trim().isNotEmpty) {
          questionsList.add({
            'question': s.questions[qi].text.trim(),
            'orderIndex': qi,
          });
        }
      }
      sectionsList.add({
        'title': s.titleCtrl.text.trim(),
        'description': s.descCtrl.text.trim(),
        'weightage': s.weightage,
        'orderIndex': i,
        'questions': questionsList,
      });
    }

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'industry': _industryCtrl.text.trim(),
      'sections': sectionsList,
    };
    if (_companyId.isNotEmpty) data['companyId'] = _companyId;
    if (_customerTypeCtrl.text.trim().isNotEmpty)
      data['customerType'] = _customerTypeCtrl.text.trim();
    if (_categoryId != null) data['categoryId'] = _categoryId;
    if (_stageId != null) data['interactionStageId'] = _stageId;

    try {
      if (_isEdit) {
        await _api.updateSop(widget.editId!, data);
        _msg('SOP updated');
      } else {
        await _api.createSop(data);
        _msg('SOP created');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      String errorMsg = 'Failed';
      if (e is Exception) {
        final str = e.toString();
        // Extract server message from DioException
        if (str.contains('message')) {
          errorMsg = str;
        }
      }
      _msg('$errorMsg', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  int get _totalWeightage => _sections.fold(0, (sum, s) => sum + s.weightage);
  int get _totalQuestions => _sections.fold(
    0,
    (sum, s) => sum + s.questions.where((q) => q.text.trim().isNotEmpty).length,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          // App bar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 16,
              bottom: 12,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  _isEdit ? 'Edit SOP' : 'Create SOP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Stats
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_totalQuestions Q · ${_sections.length} S · $_totalWeightage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Basic info
                  _field(_nameCtrl, 'SOP Name *'),
                  const SizedBox(height: 10),
                  // Industry dropdown or text
                  _field(_industryCtrl, 'Industry *'),
                  const SizedBox(height: 10),
                  _field(_customerTypeCtrl, 'Customer Type'),
                  const SizedBox(height: 10),
                  // Category dropdown
                  _dropdown(
                    'Category',
                    _categoryId,
                    _categories,
                    (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 10),
                  _dropdown(
                    'Sales Stage',
                    _stageId,
                    _stages,
                    (v) => setState(() => _stageId = v),
                  ),
                  const SizedBox(height: 20),

                  // Sections
                  Row(
                    children: [
                      const Text(
                        'Sections',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _sections.add(_Section())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Add Section',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._sections.asMap().entries.map(
                    (e) => _sectionCard(e.key, e.value),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEdit ? 'Update SOP' : 'Create SOP'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.surfaceLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.surfaceLight),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  Widget _dropdown(
    String label,
    String? value,
    List<Map<String, dynamic>> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.textHint),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'No $label',
                style: const TextStyle(color: AppColors.textHint),
              ),
            ),
            ...items.map(
              (i) => DropdownMenuItem(
                value: i['id'] as String,
                child: Text(
                  '${i['name']}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sectionCard(int index, _Section section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Section ${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              // Weightage
              SizedBox(
                width: 70,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weight %',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(
                    text: '${section.weightage}',
                  ),
                  onChanged: (v) => section.weightage = int.tryParse(v) ?? 10,
                ),
              ),
              const SizedBox(width: 8),
              if (_sections.length > 1)
                GestureDetector(
                  onTap: () => setState(() {
                    section.dispose();
                    _sections.removeAt(index);
                  }),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Title
          TextField(
            controller: section.titleCtrl,
            decoration: InputDecoration(
              labelText: 'Section Title *',
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: section.descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description',
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Questions
          Row(
            children: [
              const Text(
                'Questions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(
                  () => section.questions.add(TextEditingController()),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...section.questions.asMap().entries.map(
            (qe) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '${qe.key + 1}.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: qe.value,
                      decoration: InputDecoration(
                        hintText: 'Enter question...',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (section.questions.length > 1)
                    GestureDetector(
                      onTap: () => setState(() {
                        section.questions[qe.key].dispose();
                        section.questions.removeAt(qe.key);
                      }),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  int weightage = 10;
  final List<TextEditingController> questions = [TextEditingController()];

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    for (final q in questions) q.dispose();
  }
}
