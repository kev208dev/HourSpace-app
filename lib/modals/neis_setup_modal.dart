import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../models/user_type.dart';
import '../providers/user_type_provider.dart';
import '../providers/neis_cache_provider.dart';
import '../providers/academic_schedule_provider.dart';
import '../supabase/neis_service.dart';
import '../widgets/mascot/mascot_feedback.dart';
import '../widgets/school_logo.dart';

Future<void> showNeisSetupModal(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NeisSetupModal(),
    );

class NeisSetupModal extends ConsumerStatefulWidget {
  const NeisSetupModal({super.key});
  @override
  ConsumerState<NeisSetupModal> createState() => _NeisSetupModalState();
}

class _NeisSetupModalState extends ConsumerState<NeisSetupModal> {
  final _nameCtrl = TextEditingController();
  final _classCtrl = TextEditingController(text: '1');
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;
  NeisSchool? _existing; // 이미 연결된 학교(재진입 시 학년/반 편집)
  int _grade = 1;
  int _classNm = 1;
  bool _loading = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    // 이미 연결돼 있으면 학년/반을 미리 채운다.
    final s = NeisSchool.load();
    if (s != null) {
      _existing = s;
      _grade = s.grade;
      _classNm = s.classNm;
      _classCtrl.text = '${s.classNm}';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _classCtrl.dispose();
    super.dispose();
  }

  // 현재 선택(검색결과) 또는 기존 연결 학교의 종류 문자열.
  String get _activeKind =>
      _selected?['SCHUL_KND_SC_NM']?.toString() ?? _existing?.kind ?? '';

  int get _maxGrade => maxGradeForSchoolKind(_activeKind);

  // 학교가 선택/연결된 상태인가 — 학년·반 입력을 노출.
  bool get _hasSchool => _selected != null || _existing != null;

  // 연결된 학교 카드용 로고 URL(홈페이지 고화질 파비콘).
  String? get _previewLogo {
    final hp = _selected?['HMPG_ADRES']?.toString() ?? _existing?.homepage ?? '';
    return faviconUrlFor(hp);
  }

  String? get _previewLogoFallback {
    final hp = _selected?['HMPG_ADRES']?.toString() ?? _existing?.homepage ?? '';
    return faviconFallbackUrlFor(hp);
  }

  // 학교 선택 시 로고 + 학교명을 보여주는 확인 팝업(선택됨 피드백).
  void _showSelectedPopup(Map<String, dynamic> row) {
    final name = row['SCHUL_NM']?.toString() ?? '';
    final hp = row['HMPG_ADRES']?.toString() ?? '';
    final logo = faviconUrlFor(hp);
    final fallback = faviconFallbackUrlFor(hp);
    final sh = context.sh;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: tr('닫기'),
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dctx, _, _) {
        // 잠깐 보여주고 자동으로 닫힘(탭해도 닫힘).
        Future<void>.delayed(const Duration(milliseconds: 1600), () {
          if (dctx.mounted && Navigator.of(dctx).canPop()) {
            Navigator.of(dctx).pop();
          }
        });
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: BoxDecoration(
                color: sh.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: sh.dark ? 0.5 : 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SchoolLogo(
                      name: name, logoUrl: logo,
                      fallbackUrl: fallback, size: 72),
                  const SizedBox(height: 16),
                  Text(name,
                      textAlign: TextAlign.center,
                      style: AppType.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800, color: sh.ink)),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: sh.accent),
                    const SizedBox(width: 4),
                    Text(tr('선택됨'),
                        style: AppType.bodySmall.copyWith(
                            color: sh.accent, fontWeight: FontWeight.w700)),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sh.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 그랩 핸들
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: sh.ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(tr('🏫 학교 연결'),
                      style: AppType.titleMedium.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: sh.ink)),
                  const Spacer(),
                  // 항상 보이는 닫기(×) 버튼.
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: tr('닫기'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(tr('초·중·고는 시간표·급식·학사일정을 자동으로 가져와요.'),
                  style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
              const SizedBox(height: Gap.lg),

              // 현재 연결된 학교 카드(있으면)
              if (_existing != null && _selected == null) ...[
                _SchoolPreviewCard(sh: sh, logo: _previewLogo,
                    logoFallback: _previewLogoFallback, name: _existing!.name,
                    sub: '${tr(_existing!.kind)} · ${trf('{0}학년 {1}반', [_existing!.grade, _existing!.classNm])}'),
                const SizedBox(height: 14),
              ],

              // 학교명 검색
              Row(children: [
                Expanded(child: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: _existing == null ? tr('학교명') : tr('다른 학교로 변경'),
                    hintText: tr('예) 한국디지털미디어고등학교'),
                    hintStyle: TextStyle(color: sh.inkFaint),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                )),
                const SizedBox(width: Gap.sm),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr('검색')),
                ),
              ]),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Text(_status!, style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
                ),
              // 검색 결과
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      final sel = _selected == r;
                      return ListTile(
                        dense: true,
                        tileColor: sel ? sh.accentBg : null,
                        title: Text(r['SCHUL_NM']?.toString() ?? '',
                            style: AppType.bodyLarge.copyWith(
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                color: sel ? sh.accentInk : sh.ink)),
                        subtitle: Text(
                            '${r['LCTN_SC_NM'] ?? ''} · ${r['SCHUL_KND_SC_NM'] ?? ''}',
                            style: AppType.labelMedium.copyWith(color: sh.inkSoft)),
                        onTap: () {
                          setState(() {
                            _selected = r;
                            // 학교 종류가 바뀌면 학년 상한을 넘지 않게 보정.
                            if (_grade > _maxGrade) _grade = 1;
                          });
                          // 선택 피드백 — 로고 + 학교명 팝업.
                          _showSelectedPopup(r);
                        },
                      );
                    },
                  ),
                ),
              ],
              // 학년/반 — 초등학교면 1~6, 그 외 1~3
              if (_hasSchool) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('학년'), style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
                      DropdownButton<int>(
                        value: _grade.clamp(1, _maxGrade),
                        isExpanded: true,
                        items: List.generate(_maxGrade, (i) => i + 1)
                            .map((g) => DropdownMenuItem(value: g,
                                child: Text(trf('{0}학년', [g])))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _grade = v); },
                      ),
                    ],
                  )),
                  const SizedBox(width: Gap.lg),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('반'), style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
                      TextField(
                        keyboardType: TextInputType.number,
                        controller: _classCtrl,
                        decoration: InputDecoration(
                            hintText: '1',
                            hintStyle: TextStyle(color: sh.inkFaint)),
                        onChanged: (v) => _classNm = int.tryParse(v) ?? 1,
                      ),
                    ],
                  )),
                ]),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: sh.inkSoft,
                      side: BorderSide(color: sh.ink.withValues(alpha: 0.12)),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: Text(tr('취소'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                )),
                const SizedBox(width: Gap.md),
                Expanded(flex: 2, child: FilledButton(
                  onPressed: _hasSchool ? _save : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: sh.accent,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: Text(_existing != null && _selected == null ? tr('저장') : tr('연결'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _search() async {
    final q = _nameCtrl.text.trim();
    if (q.isEmpty) { return; }
    setState(() { _loading = true; _status = tr('검색 중…'); _results = []; _selected = null; });
    try {
      final rows = await searchSchools(q);
      setState(() {
        _results = rows;
        _status = rows.isEmpty ? tr('검색 결과가 없습니다') : null;
        _loading = false;
      });
    } catch (e) {
      setState(() { _status = trf('오류: {0}', [e]); _loading = false; });
    }
  }

  Future<void> _save() async {
    // 새로 고른 학교가 있으면 그 정보로, 없으면 기존 학교의 학년·반만 갱신.
    final NeisSchool school;
    if (_selected != null) {
      school = NeisSchool(
        name: _selected!['SCHUL_NM']?.toString() ?? '',
        code: _selected!['SD_SCHUL_CODE']?.toString() ?? '',
        officeCode: _selected!['ATPT_OFCDC_SC_CODE']?.toString() ?? '',
        kind: _selected!['SCHUL_KND_SC_NM']?.toString() ?? '',
        grade: _grade.clamp(1, _maxGrade),
        classNm: _classNm,
        homepage: _selected!['HMPG_ADRES']?.toString() ?? '',
      );
    } else if (_existing != null) {
      school = _existing!.copyWith(
        grade: _grade.clamp(1, _maxGrade),
        classNm: _classNm,
      );
    } else {
      return;
    }
    await school.save();
    // 유형이 아직 선택 안 됐으면 학교 종류로 자동 설정(고/중/초 학생).
    if (ref.read(userTypeProvider) == null) {
      final k = school.kind;
      final inferred = k.contains('고등')
          ? UserType.high
          : k.contains('중학')
              ? UserType.middle
              : k.contains('초등')
                  ? UserType.elementary
                  : null;
      if (inferred != null) {
        await ref.read(userTypeProvider.notifier).set(inferred);
      }
    }
    // 학교가 바뀌었으니 시간표·학사일정을 바로 다시 받아 즉시 반영.
    ref.read(neisCacheProvider.notifier).refresh();
    ref.read(academicScheduleProvider.notifier).refresh();
    if (mounted) {
      MascotToast.success(context, trf('{0} 연결 완료!', [school.name]));
      Navigator.pop(context);
    }
  }
}

// ─── 현재 연결된 학교 미리보기 카드 ─────────────────────────────────
class _SchoolPreviewCard extends StatelessWidget {
  final SurlapColors sh;
  final String? logo;
  final String? logoFallback;
  final String name;
  final String sub;
  const _SchoolPreviewCard(
      {required this.sh, required this.logo, this.logoFallback,
      required this.name, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sh.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sh.accent.withValues(alpha: 0.16)),
      ),
      child: Row(children: [
        SchoolLogo(
            name: name, logoUrl: logo, fallbackUrl: logoFallback, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800, color: sh.ink)),
              const SizedBox(height: 2),
              Text(sub,
                  style: AppType.labelMedium.copyWith(color: sh.inkSoft)),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: sh.accent, size: 20),
      ]),
    );
  }
}

