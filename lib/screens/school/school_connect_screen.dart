import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../models/user_type.dart';
import '../../providers/user_type_provider.dart';
import '../../supabase/neis_service.dart';
import '../../widgets/app_toast.dart';

/// 학교 연결 (핸드오프 F1 · spec §12).
///
/// 2단계: 학교 검색 → 학년·반. NEIS `schoolInfo` 로 최대 10곳을 찾는다.
/// 저장하면 시간표와 학사일정을 새로 받아온다.
Future<void> showSchoolConnect(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const SchoolConnectScreen()),
    );

class SchoolConnectScreen extends ConsumerStatefulWidget {
  const SchoolConnectScreen({super.key});

  @override
  ConsumerState<SchoolConnectScreen> createState() =>
      _SchoolConnectScreenState();
}

class _SchoolConnectScreenState extends ConsumerState<SchoolConnectScreen> {
  final _queryCtrl = TextEditingController();

  bool _loading = false;
  bool _searched = false;
  List<Map<String, dynamic>> _results = const [];

  /// 2단계에서 고른 학교.
  Map<String, dynamic>? _picked;
  int _grade = 1;
  int _classNm = 1;

  @override
  void initState() {
    super.initState();
    final saved = NeisSchool.load();
    if (saved != null) {
      _grade = saved.grade;
      _classNm = saved.classNm;
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  /// 학교 종류에서 학년 상한을 정한다 — 초등 1–6, 중·고 1–3.
  int get _maxGrade {
    final kind = (_picked?['SCHUL_KND_SC_NM'] ?? '').toString();
    return kind.contains('초등') ? 6 : 3;
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final rows = await searchSchools(q);
      if (!mounted) return;
      setState(() => _results = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = const []);
      AppToast.error(context, tr('학교를 찾지 못했습니다. 네트워크를 확인해 주세요.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(Map<String, dynamic> row) {
    setState(() {
      _picked = row;
      if (_grade > _maxGrade) _grade = 1;
    });
  }

  Future<void> _save() async {
    final row = _picked;
    if (row == null) return;
    final kind = (row['SCHUL_KND_SC_NM'] ?? '').toString();

    final school = NeisSchool(
      name: (row['SCHUL_NM'] ?? '').toString(),
      code: (row['SD_SCHUL_CODE'] ?? '').toString(),
      officeCode: (row['ATPT_OFCDC_SC_CODE'] ?? '').toString(),
      kind: kind,
      grade: _grade,
      classNm: _classNm,
      homepage: (row['HMPG_ADRES'] ?? '').toString(),
    );
    await school.save();

    // 학교 종류에서 사용자 유형을 유추한다(미선택일 때만).
    if (ref.read(userTypeProvider) == null) {
      final inferred = inferUserType(kind);
      if (inferred != null) {
        await ref.read(userTypeProvider.notifier).set(inferred);
      }
    }

    // 시간표·학사일정을 새로 받아온다.
    ref.read(neisCacheProvider.notifier).refresh();
    ref.read(academicScheduleProvider.notifier).refresh();

    if (!mounted) return;
    AppToast.success(context, tr('학교를 연결했어요'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final usesMeal = ref.watch(userTypeProvider)?.usesMeal;
    // 유형을 아직 안 골랐으면 막지 않는다 — 학교 종류로 유추할 수 있다.
    final blocked = usesMeal == false;

    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        backgroundColor: sh.bg,
        elevation: 0,
        title: Text(tr('학교 연결'),
            style: AppType.display.copyWith(fontSize: 22, color: sh.ink)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.lg),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: sh.card2,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text('NEIS',
                    style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: sh.ink.withValues(alpha: 0.60))),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        children: [
          if (blocked)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: _Banner(
                  tr('지금 사용자 유형에서는 학교 연동을 쓸 수 없습니다. '
                      '초·중·고등학생만 시간표·급식·학사일정을 받아옵니다.')),
            ),
          _Stepper(step2Active: _picked != null),
          const SizedBox(height: Gap.md),
          if (_picked == null) ...[
            _SearchBar(
              controller: _queryCtrl,
              onSearch: _search,
              enabled: !blocked,
            ),
            const SizedBox(height: Gap.md),
            if (_loading)
              _Loading(tr('NEIS에서 학교를 찾는 중'))
            else if (_searched && _results.isEmpty)
              _Notice(tr('검색 결과가 없습니다. 학교 이름을 다시 확인해 주세요.'))
            else
              for (final row in _results)
                _SchoolRow(row: row, onTap: () => _pick(row)),
          ] else
            _GradeStep(
              school: _picked!,
              grade: _grade,
              classNm: _classNm,
              maxGrade: _maxGrade,
              onGrade: (g) => setState(() => _grade = g),
              onClass: (c) => setState(() => _classNm = c),
              onBack: () => setState(() => _picked = null),
              onSave: _save,
            ),
        ],
      ),
    );
  }
}

/// 1 학교 검색 ── 2 학년·반.
class _Stepper extends StatelessWidget {
  final bool step2Active;
  const _Stepper({required this.step2Active});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    Widget dot(String n) => Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: sh.accent, shape: BoxShape.circle),
          child: Text(n,
              style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700, color: sh.onAccent)),
        );

    return Row(
      children: [
        dot('1'),
        const SizedBox(width: 6),
        Text(tr('학교 검색'),
            style: AppType.sub.copyWith(
                fontWeight: FontWeight.w600, color: sh.ink)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: sh.border)),
        const SizedBox(width: 10),
        Opacity(
          opacity: step2Active ? 1 : 0.4,
          child: Row(
            children: [
              dot('2'),
              const SizedBox(width: 6),
              Text(tr('학년 · 반'),
                  style: AppType.sub.copyWith(
                      fontWeight: FontWeight.w600, color: sh.ink)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool enabled;

  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: sh.shadowCard,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              size: 17, color: sh.ink.withValues(alpha: 0.45)),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onSubmitted: (_) => onSearch(),
              style: AppType.button.copyWith(
                  fontSize: 14.5, fontWeight: FontWeight.w400, color: sh.ink),
              decoration: InputDecoration(
                hintText: tr('학교 이름'),
                hintStyle: TextStyle(
                    color: sh.ink.withValues(alpha: Alpha.placeholder)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          FilledButton(
            onPressed: enabled ? onSearch : null,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(tr('검색'), style: AppType.sub),
          ),
        ],
      ),
    );
  }
}

class _SchoolRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _SchoolRow({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final name = (row['SCHUL_NM'] ?? '').toString();
    final addr = (row['ORG_RDNMA'] ?? row['ORG_RDNZC'] ?? '').toString();
    final kind = (row['SCHUL_KND_SC_NM'] ?? '').toString();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: sh.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.button.copyWith(
                          fontSize: 14.5, color: sh.ink)),
                  if (addr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(addr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(
                            color: sh.ink.withValues(alpha: 0.48))),
                  ],
                ],
              ),
            ),
            if (kind.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: sh.card2,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(kind,
                    style: AppType.micro.copyWith(
                        color: sh.ink.withValues(alpha: 0.55))),
              ),
            Icon(Icons.chevron_right_rounded,
                size: 15, color: sh.ink.withValues(alpha: 0.30)),
          ],
        ),
      ),
    );
  }
}

/// 2단계 — 학년·반 고르기.
class _GradeStep extends StatelessWidget {
  final Map<String, dynamic> school;
  final int grade;
  final int classNm;
  final int maxGrade;
  final ValueChanged<int> onGrade;
  final ValueChanged<int> onClass;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _GradeStep({
    required this.school,
    required this.grade,
    required this.classNm,
    required this.maxGrade,
    required this.onGrade,
    required this.onClass,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: sh.card,
            borderRadius: BorderRadius.circular(Radii.card),
            boxShadow: sh.shadowCard,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text((school['SCHUL_NM'] ?? '').toString(),
                    style: AppType.cardTitle.copyWith(color: sh.ink)),
              ),
              TextButton(
                onPressed: onBack,
                child: Text(tr('다시 찾기'), style: AppType.sub),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text(tr('학년'),
            style: AppType.label
                .copyWith(color: sh.ink.withValues(alpha: 0.50))),
        const SizedBox(height: Gap.sm),
        _NumberChips(
          count: maxGrade,
          selected: grade,
          suffix: tr('학년'),
          onPick: onGrade,
        ),
        const SizedBox(height: Gap.lg),
        Text(tr('반'),
            style: AppType.label
                .copyWith(color: sh.ink.withValues(alpha: 0.50))),
        const SizedBox(height: Gap.sm),
        _NumberChips(
          count: 15,
          selected: classNm,
          suffix: tr('반'),
          onPick: onClass,
        ),
        const SizedBox(height: Gap.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
            ),
            child: Text(tr('연결하기'),
                style: AppType.button.copyWith(fontSize: 16)),
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(tr('연결하면 시간표·급식·학사일정을 바로 받아옵니다.'),
            style: AppType.caption.copyWith(
                height: 1.6, color: sh.ink.withValues(alpha: 0.48))),
      ],
    );
  }
}

class _NumberChips extends StatelessWidget {
  final int count;
  final int selected;
  final String suffix;
  final ValueChanged<int> onPick;

  const _NumberChips({
    required this.count,
    required this.selected,
    required this.suffix,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 1; i <= count; i++)
          GestureDetector(
            onTap: () => onPick(i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: i == selected ? sh.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.pill),
                border:
                    Border.all(color: i == selected ? sh.accent : sh.border),
              ),
              child: Text('$i$suffix',
                  style: AppType.sub.copyWith(
                      fontWeight: FontWeight.w600,
                      color: i == selected ? sh.bg : sh.ink)),
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  final String text;
  const _Loading(this.text);

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: sh.accent),
          ),
          const SizedBox(width: 9),
          Text(text,
              style: AppType.body
                  .copyWith(color: sh.ink.withValues(alpha: 0.55))),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        child: Text(text,
            style: AppType.body.copyWith(
                color: context.sh.ink.withValues(alpha: 0.45))),
      );
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner(this.text);

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.accent2Bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child:
                Icon(Icons.info_outline_rounded, size: 16, color: sh.accent2Ink),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(text,
                style: AppType.sub
                    .copyWith(height: 1.55, color: sh.accent2Ink)),
          ),
        ],
      ),
    );
  }
}
