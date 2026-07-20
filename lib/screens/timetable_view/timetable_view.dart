import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../storage/local_store.dart';
import '../../core/constants/storage_keys.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/cell_design_provider.dart';
import '../../providers/neis_cache_provider.dart';
import '../../providers/academic_schedule_provider.dart';
import '../../providers/settings_provider.dart';
import '../../modals/neis_setup_modal.dart';
import '../../i18n/strings.dart';

// ─── Row definition ───────────────────────────────────────────────

enum _RType { free, school, lunch, divider }

class _RowDef {
  final _RType type;
  final String label;
  final int hour;   // -1 for divider
  final int period; // 1..N for school rows, -1 otherwise
  const _RowDef({required this.type, this.label = '', this.hour = -1, this.period = -1});
  bool get isDivider => type == _RType.divider;
}

// ─── Merge group ──────────────────────────────────────────────────

class _MergeGroup {
  final int col;
  final int startRow;
  final int span;
  final String text;
  final double topOffset;

  const _MergeGroup({
    required this.col,
    required this.startRow,
    required this.span,
    required this.text,
    required this.topOffset,
  });
}

/// 과목명 표시용 정리 — 원본 데이터는 그대로 두고 UI 표시만 줄인다.
/// 글자 단위로 어색하게 쪼개지지 않도록 단어/접미사 기준으로 다듬는다.
String getDisplaySubjectName(String raw, {bool lunch = false}) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  // 점심 행은 급식 메뉴를 줄별로 정리해 그대로 보여준다.
  if (lunch) return _formatLunchMenu(s);
  // 선두 주석 제거: [보강]·(1)·【...】 등 → 본 과목명만 남겨 줄바꿈 방지.
  var t = s.replaceFirst(
      RegExp(r'^\s*[\[\(（【][^\]\)）】]*[\]\)）】]\s*'), '');
  if (t.trim().isEmpty) t = s; // 통째로 주석뿐이면 원본 유지
  // 다중 공백 → 단일 공백.
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  // 흔한 군더더기 접미사 제거(결과가 2자 이상일 때만).
  for (final suf in const ['일반', '기초', '입문', '개론']) {
    final stripped = t.replaceAll(' ', '');
    if (stripped.length > suf.length + 1 && stripped.endsWith(suf)) {
      t = stripped.substring(0, stripped.length - suf.length);
      break;
    }
  }
  return t;
}

/// 급식 메뉴 정리 — 구분자(줄바꿈/`*`/`/`) 기준으로 나눠 줄별 표시.
/// 알레르기 표기 등은 그대로 둔다.
String _formatLunchMenu(String raw) {
  final parts = raw
      .split(RegExp(r'[\n*/]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return parts.isEmpty ? '' : parts.join('\n');
}

// ─── 표시 밀도 프리셋 ─────────────────────────────────────────────
/// "넓게 보기 / 촘촘히 보기" 같은 밀도 값을 한곳에 모아 둔다.
class _Density {
  final double dayColW;
  final double labelW;
  final double headerH;
  final double schoolH;
  final double lunchH;
  final double freeH;
  final double cardMargin;
  final double cardRadius;
  final int subjectMaxLines;
  final double subjectFont;
  const _Density({
    required this.dayColW,
    required this.labelW,
    required this.headerH,
    required this.schoolH,
    required this.lunchH,
    required this.freeH,
    required this.cardMargin,
    required this.cardRadius,
    required this.subjectMaxLines,
    required this.subjectFont,
  });

  // 넓게(t=0) 기준값.
  static const wide = _Density(
    dayColW: 92, labelW: 70, headerH: 60, schoolH: 82, lunchH: 96, freeH: 50,
    cardMargin: 3, cardRadius: 10, subjectMaxLines: 2, subjectFont: 13,
  );

  /// 슬라이더 t(0=넓게 … 1=최대압축)로 치수를 보간.
  /// 최대압축에서는 7일이 화면폭(availW)에 딱 맞아 가로 스크롤이 사라진다.
  static _Density forSlider(double t, double availW) {
    double lp(double a, double b) => a + (b - a) * t;
    final labelW = lp(70, 48);
    final fitColW = ((availW - labelW) / 7).clamp(40.0, 92.0);
    return _Density(
      dayColW: lp(92, fitColW),
      labelW: labelW,
      headerH: lp(60, 40),
      schoolH: lp(82, 40),
      lunchH: lp(96, 52),
      freeH: lp(50, 30),
      cardMargin: lp(3, 1.5),
      cardRadius: lp(10, 7),
      subjectMaxLines: t > 0.5 ? 1 : 2,
      subjectFont: lp(13, 9.5),
    );
  }
}

// ─── Main widget ──────────────────────────────────────────────────

class TimetableView extends ConsumerStatefulWidget {
  const TimetableView({super.key});

  @override
  ConsumerState<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends ConsumerState<TimetableView> {
  static const _dowNames = ['월', '화', '수', '목', '금', '토', '일'];
  static const _divH = 3.0;

  // 디자인 모드(셀 꾸미기) — 화면 로컬 UI 상태.
  bool _designMode = false;
  // 밀도 — 0=넓게 … 1=최대압축(한 화면). 두 손가락 핀치로 연속 조절.
  double _density = 0;
  double _densityStart = 0; // 핀치 시작 시점 밀도 snapshot
  _Density _dim = _Density.wide;

  // 가로/세로 스크롤 — 고정 라벨열·헤더가 본문을 따라가도록 동기화.
  final _bodyV = ScrollController();
  final _bodyH = ScrollController();
  final _labelV = ScrollController();
  final _headerH = ScrollController();
  bool _didAutoScroll = false;

  static const _palette = [
    Color(0xFFFFE4E4), Color(0xFFFFF3CD), Color(0xFFD4EDDA), Color(0xFFD1ECF1),
    Color(0xFFE2D9F3), Color(0xFFFFF5EE), Color(0xFFF0F0F0), Color(0xFFFFE8D6),
  ];

  // ── 치수는 현재 밀도(_dim)에서 읽는다(build에서 화면폭 반영해 갱신). ──
  bool get _tight => _density > 0.5;
  double get _dayColW => _dim.dayColW;
  double get _labelW => _dim.labelW;
  double get _headerBandH => _dim.headerH;
  double get _schoolH => _dim.schoolH;
  double get _lunchH => _dim.lunchH;
  double get _freeH => _dim.freeH;
  double get _subjectFont => _dim.subjectFont;

  @override
  void initState() {
    super.initState();
    _bodyV.addListener(_syncV);
    _bodyH.addListener(_syncH);
  }

  @override
  void dispose() {
    _bodyV.removeListener(_syncV);
    _bodyH.removeListener(_syncH);
    _bodyV.dispose();
    _bodyH.dispose();
    _labelV.dispose();
    _headerH.dispose();
    super.dispose();
  }

  void _syncV() {
    if (!_labelV.hasClients || !_bodyV.hasClients) return;
    final o = _bodyV.offset
        .clamp(_labelV.position.minScrollExtent, _labelV.position.maxScrollExtent);
    if (_labelV.offset != o) _labelV.jumpTo(o);
  }

  void _syncH() {
    if (!_headerH.hasClients || !_bodyH.hasClients) return;
    final o = _bodyH.offset
        .clamp(_headerH.position.minScrollExtent, _headerH.position.maxScrollExtent);
    if (_headerH.offset != o) _headerH.jumpTo(o);
  }

  // 첫 진입 시 오늘 요일이 보이도록 가로 스크롤.
  void _autoScrollToToday() {
    if (_didAutoScroll || !_bodyH.hasClients) return;
    _didAutoScroll = true;
    final todayCol = DateTime.now().weekday - 1; // 월=0
    final target = (todayCol * _dayColW)
        .clamp(0.0, _bodyH.position.maxScrollExtent);
    if (target > 0) _bodyH.jumpTo(target);
  }

  // ── Data builders ─────────────────────────────────────────────

  static List<DateTime> _weekDays() {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  static int _maxPeriod(Map<int, Map<int, String>> neis) {
    int mp = 7;
    for (final pm in neis.values) {
      for (final p in pm.keys) {
        if (p > mp) mp = p;
      }
    }
    return mp;
  }

  static List<_RowDef> _buildRows(int maxPeriod) {
    final rows = <_RowDef>[];
    for (int h = 0; h <= 8; h++) {
      rows.add(_RowDef(type: _RType.free, label: '$h:00', hour: h));
    }
    rows.add(const _RowDef(type: _RType.divider));
    final topPeriods = maxPeriod < 4 ? maxPeriod : 4;
    for (int p = 1; p <= topPeriods; p++) {
      rows.add(_RowDef(type: _RType.school, label: trf('{0}교시', [p]), hour: 8 + p, period: p));
    }
    rows.add(_RowDef(type: _RType.lunch, label: tr('점심'), hour: 13));
    for (int p = 5; p <= maxPeriod; p++) {
      rows.add(_RowDef(type: _RType.school, label: trf('{0}교시', [p]), hour: 9 + p, period: p));
    }
    rows.add(const _RowDef(type: _RType.divider));
    final afterSchool = 10 + maxPeriod;
    for (int h = afterSchool; h <= 23; h++) {
      rows.add(_RowDef(type: _RType.free, label: '$h:00', hour: h));
    }
    return rows;
  }

  // 행 높이 — 내용 길이가 아니라 행 종류·보기 모드로 결정(넓고 일정하게).
  double _heightFor(_RowDef r) => switch (r.type) {
        _RType.divider => _divH,
        _RType.school => _schoolH,
        _RType.lunch => _lunchH,
        _RType.free => _freeH,
      };

  List<double> _rowHeights(List<_RowDef> rows) =>
      [for (final r in rows) _heightFor(r)];

  static List<double> _rowOffsets(List<double> heights) {
    final offsets = <double>[];
    double acc = 0;
    for (final h in heights) {
      offsets.add(acc);
      acc += h;
    }
    offsets.add(acc);
    return offsets;
  }

  static Map<int, Map<int, String>> _buildTemplateData(List<DateTime> days) {
    final result = <int, Map<int, String>>{};
    for (int di = 0; di < 7; di++) { result[di] = {}; }

    final rawTpl = LocalStore.instance.getString(StorageKeys.timetableTemplate);
    if (rawTpl == null) return result;
    Map<String, dynamic> tpl;
    try {
      tpl = jsonDecode(rawTpl) as Map<String, dynamic>;
    } catch (_) {
      return result;
    }

    final blocks = (tpl['blocks'] as List? ?? []).cast<Map<String, dynamic>>();
    final weekdays = (tpl['weekdays'] as List? ?? [0, 1, 2, 3, 4])
        .map((e) => e as int).toSet();
    final startDate = tpl['startDate'] as String?;
    final endDate = tpl['endDate'] as String?;

    Map<String, dynamic> overrides = {};
    final rawOv = LocalStore.instance.getString(StorageKeys.timetableOverrides);
    if (rawOv != null) {
      try {
        overrides = jsonDecode(rawOv) as Map<String, dynamic>;
      } catch (_) {}
    }

    for (int di = 0; di < 7; di++) {
      final date = days[di];
      final dow = (date.weekday - 1) % 7;
      if (!weekdays.contains(dow)) continue;
      final dk = du.toDateKey(date);
      if (startDate != null && dk.compareTo(startDate) < 0) continue;
      if (endDate != null && dk.compareTo(endDate) > 0) continue;
      final ov = overrides[dk] as Map<String, dynamic>? ?? {};
      final hiddenIds = ((ov['hiddenBlockIds'] as List?) ?? [])
          .map((e) => e.toString()).toSet();
      for (final b in blocks) {
        if ((b['day'] as int?) != dow) continue;
        final id = b['id']?.toString() ?? '';
        if (hiddenIds.contains(id)) continue;
        final tm = b['tm'] as String? ?? '';
        if (tm.isEmpty) continue;
        final hour = int.tryParse(tm.split(':')[0]) ?? -1;
        if (hour < 0 || hour > 23) continue;
        result[di]![hour] = b['t']?.toString() ?? '';
      }
      final extra = (ov['extra'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final e in extra) {
        final tm = e['tm'] as String? ?? '';
        if (tm.isEmpty) continue;
        final hour = int.tryParse(tm.split(':')[0]) ?? -1;
        if (hour < 0 || hour > 23) continue;
        result[di]![hour] = e['t']?.toString() ?? '';
      }
    }
    return result;
  }

  static Map<int, Map<int, String>> _buildNeisHourData(Map<int, Map<int, String>> neis) {
    final result = <int, Map<int, String>>{};
    neis.forEach((di, periodMap) {
      result[di] = {};
      periodMap.forEach((period, subject) {
        final h = period <= 4 ? 8 + period : 9 + period;
        result[di]![h] = subject;
      });
    });
    return result;
  }

  static Map<int, Map<int, String>> _buildDisplayData(
    Map<int, Map<int, String>> neisData,
    Map<int, Map<int, String>> tplData,
    Map<int, Map<int, String>> freeData,
    Map<int, String> neisLunch,
    List<_RowDef> rows,
  ) {
    final result = <int, Map<int, String>>{};
    for (int col = 0; col < 7; col++) {
      result[col] = {};
      for (final row in rows) {
        if (row.isDivider || row.hour < 0) continue;
        final n = neisData[col]?[row.hour] ?? '';
        final t = tplData[col]?[row.hour] ?? '';
        final u = freeData[col]?[row.hour] ?? '';
        if (row.type == _RType.school) {
          result[col]![row.hour] = n.isNotEmpty ? n : t.isNotEmpty ? t : u;
        } else if (row.type == _RType.lunch) {
          final lunch = neisLunch[col] ?? '';
          // 급식 메뉴 전체를 보여준다(첫 줄만 자르지 않음).
          result[col]![row.hour] = u.isNotEmpty ? u : lunch;
        } else {
          result[col]![row.hour] = u.isNotEmpty ? u : t;
        }
      }
    }
    return result;
  }

  static List<_MergeGroup> _computeMerges(
    List<_RowDef> rows,
    List<double> offsets,
    Map<int, Map<int, String>> displayData,
  ) {
    final groups = <_MergeGroup>[];
    // 병합 비교는 '표시명' 기준 — [보강]·(3) 등 주석/접미사가 달라도
    // 같은 과목이면 합친다(원시 텍스트 비교 시 안 합쳐지던 문제 수정).
    String keyAt(int col, _RowDef r) {
      final raw = displayData[col]?[r.hour] ?? '';
      if (raw.isEmpty) return '';
      // 공백까지 제거해 비교 — "아침운동"과 "아침 운동"도 같은 과목으로 병합.
      return getDisplaySubjectName(raw, lunch: r.type == _RType.lunch)
          .replaceAll(RegExp(r'\s+'), '');
    }

    for (int col = 0; col < 7; col++) {
      int i = 0;
      while (i < rows.length) {
        if (rows[i].isDivider || rows[i].hour < 0) { i++; continue; }
        final key = keyAt(col, rows[i]);
        if (key.isEmpty) { i++; continue; }
        int j = i + 1;
        while (j < rows.length &&
               !rows[j].isDivider &&
               rows[j].hour >= 0 &&
               keyAt(col, rows[j]) == key) {
          j++;
        }
        if (j - i >= 2) {
          groups.add(_MergeGroup(
            col: col, startRow: i, span: j - i,
            text: displayData[col]?[rows[i].hour] ?? '',
            topOffset: offsets[i],
          ));
        }
        i = j;
      }
    }
    return groups;
  }

  static Set<(int, int)> _buildMergeSet(List<_MergeGroup> groups) {
    final set = <(int, int)>{};
    for (final g in groups) {
      for (int k = g.startRow; k < g.startRow + g.span; k++) {
        set.add((g.col, k));
      }
    }
    return set;
  }

  // ── Cell edit / design handlers ───────────────────────────────

  void _editCell(BuildContext ctx, int col, int hour, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: ctx,
      builder: (dctx) {
        final sh = ctx.sh;
        return AlertDialog(
          backgroundColor: sh.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          title: Text(trf('{0}요일 {1}:00 · 매주 반복', [_dowNames[col], hour]),
              style: AppType.titleMedium.copyWith(
                  fontWeight: FontWeight.w800, color: sh.ink)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: tr('예) 수학, 영어...'),
              hintStyle: TextStyle(color: sh.inkFaint),
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _saveCell(dctx, col, hour, ctrl.text.trim()),
          ),
          actions: [
            if (current.isNotEmpty)
              TextButton(
                onPressed: () => _saveCell(dctx, col, hour, ''),
                style: TextButton.styleFrom(foregroundColor: sh.danger),
                child: Text(tr('삭제')),
              ),
            TextButton(
                onPressed: () => Navigator.pop(dctx), child: Text(tr('취소'))),
            FilledButton(
              onPressed: () => _saveCell(dctx, col, hour, ctrl.text.trim()),
              child: Text(tr('저장')),
            ),
          ],
        );
      },
    );
  }

  void _saveCell(BuildContext ctx, int col, int hour, String text) {
    Navigator.pop(ctx);
    ref.read(recurringProvider.notifier).setCell(col, hour, text);
  }

  void _showDesignPanel(BuildContext ctx, int col, int hour, SurlapColors sh) {
    final current = ref.read(cellDesignProvider.notifier).forCell(col, hour);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _DesignPanel(
        currentDesign: current,
        palette: _palette,
        sh: sh,
        onApply: (design) =>
            ref.read(cellDesignProvider.notifier).setDesign(col, hour, design),
      ),
    );
  }

  // 햄버거 메뉴 — 보기 모드 + 셀 디자인 토글 + 학교 연결 + 새로고침.
  void _openMenu(BuildContext ctx, SurlapColors sh) {
    showModalBottomSheet(
      context: ctx,
      builder: (mctx) => Container(
        color: sh.card,
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.ios_share_rounded, color: sh.accent),
              title: Text(tr('이미지로 공유'),
                  style: AppType.bodyLarge.copyWith(color: sh.ink)),
              subtitle: Text(tr('시간표를 깔끔한 이미지로 내보내요'),
                  style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
              onTap: () {
                Navigator.pop(mctx);
                openTimetableExport(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.palette_outlined,
                  color: _designMode ? sh.accent : sh.inkSoft),
              title: Text(tr('셀 디자인'),
                  style: AppType.bodyLarge.copyWith(color: sh.ink)),
              subtitle: Text(_designMode ? tr('켜짐 — 셀을 눌러 꾸미기') : tr('꺼짐'),
                  style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
              trailing: Switch.adaptive(
                value: _designMode,
                activeThumbColor: sh.accent,
                onChanged: (v) {
                  setState(() => _designMode = v);
                  Navigator.pop(mctx);
                },
              ),
              onTap: () {
                setState(() => _designMode = !_designMode);
                Navigator.pop(mctx);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.school_outlined, color: sh.inkSoft),
              title: Text(tr('학교 연결 (NEIS)'),
                  style: AppType.bodyLarge.copyWith(color: sh.ink)),
              onTap: () {
                Navigator.pop(mctx);
                showNeisSetupModal(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.refresh_rounded, color: sh.inkSoft),
              title: Text(tr('시간표·학사일정 새로고침'),
                  style: AppType.bodyLarge.copyWith(color: sh.ink)),
              onTap: () {
                Navigator.pop(mctx);
                ref.read(neisCacheProvider.notifier).refresh();
                ref.read(academicScheduleProvider.notifier).refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final days = _weekDays();
    final now = DateTime.now();

    // 슬라이더 밀도 → 화면폭 반영해 치수 갱신(최대압축 시 7일 화면맞춤).
    final availW = MediaQuery.of(context).size.width - 24;
    _dim = _Density.forSlider(_density, availW);

    final neis = ref.watch(neisCacheProvider);
    final designs = ref.watch(cellDesignProvider);
    CellDesign designOf(int col, int hour) =>
        designs[cellDesignKey(col, hour)] ?? const CellDesign();

    final maxPeriod = _maxPeriod(neis.timetable);
    final rows = _buildRows(maxPeriod);
    final neisHourData = _buildNeisHourData(neis.timetable);
    final weekly = ref.watch(recurringProvider);
    final freeData = {
      for (int c = 0; c < 7; c++) c: Map<int, String>.from(weekly[c] ?? const {}),
    };
    final tplData = _buildTemplateData(days);
    final displayData =
        _buildDisplayData(neisHourData, tplData, freeData, neis.lunch, rows);
    final rowHeights = _rowHeights(rows);
    final offsets = _rowOffsets(rowHeights);
    final totalH = offsets.last;
    final mergeGroups = _computeMerges(rows, offsets, displayData);
    final mergeSet = _buildMergeSet(mergeGroups);

    final tableW = 7 * _dayColW;
    final bottomPad = 120.0 + MediaQuery.of(context).padding.bottom;

    // 오늘 위치로 자동 스크롤(첫 프레임 후).
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScrollToToday());

    return Column(
      children: [
        // ── 제목 + 보기 모드 토글 + 햄버거 ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                    _designMode ? tr('스케줄표 · 디자인') : tr('스케줄표'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.titleLarge.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _designMode ? sh.accent : sh.ink)),
              ),
              // 확대/축소는 본문에서 두 손가락 핀치로 조절 — 별도 버튼 없음.
              _HamburgerBtn(onTap: () => _openMenu(context, sh)),
            ],
          ),
        ),

        // ── 헤더 밴드 (고정) — 좌상단 코너 + 요일 헤더(가로 동기) ──
        SizedBox(
          height: _headerBandH,
          child: Row(
            children: [
              // 좌상단 코너
              Container(
                width: _labelW,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sh.card2,
                  border: Border(
                    right: BorderSide(color: _gridLine(sh), width: 1),
                    bottom: BorderSide(color: _gridLine(sh), width: 1.5),
                  ),
                ),
                child: Icon(Icons.schedule_rounded, size: 16, color: sh.inkSoft),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerH,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: tableW,
                    child: Row(
                      children: List.generate(7, (i) =>
                          _dayHeader(i, days[i], now, sh)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 본문 — 좌측 고정 라벨열 + 가로/세로 스크롤 그리드 ──────
        // 두 손가락 핀치로 확대/축소(밀도 조절). 한 손가락은 스크롤로 통과.
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onScaleStart: (_) => _densityStart = _density,
            onScaleUpdate: (d) {
              if (d.pointerCount < 2) return;
              // scale>1 (벌림) → 밀도 감소(더 넓게). scale<1 (오므림) → 밀도 증가(더 압축).
              final next = (_densityStart / d.scale).clamp(0.0, 1.0);
              if ((next - _density).abs() > 0.005) {
                setState(() => _density = next);
              }
            },
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 고정 시간/교시 라벨열 (세로 동기)
              SizedBox(
                width: _labelW,
                child: SingleChildScrollView(
                  controller: _labelV,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      for (int ri = 0; ri < rows.length; ri++)
                        _labelCell(rows[ri], rowHeights[ri], sh),
                      SizedBox(height: bottomPad),
                    ],
                  ),
                ),
              ),
              // 그리드 본문
              Expanded(
                child: SingleChildScrollView(
                  controller: _bodyV,
                  child: SingleChildScrollView(
                    controller: _bodyH,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: tableW,
                          height: totalH,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 그리드 셀
                              Column(
                                children: List.generate(rows.length, (ri) {
                                  final row = rows[ri];
                                  if (row.isDivider) {
                                    return Container(
                                      height: _divH,
                                      width: tableW,
                                      color: sh.accent.withValues(alpha: 0.28),
                                    );
                                  }
                                  return SizedBox(
                                    height: rowHeights[ri],
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: List.generate(7, (col) =>
                                          _gridCell(
                                            col: col, ri: ri, row: row,
                                            days: days, now: now,
                                            displayData: displayData,
                                            mergeSet: mergeSet,
                                            designOf: designOf,
                                            freeData: freeData, sh: sh,
                                          )),
                                    ),
                                  );
                                }),
                              ),
                              // 병합(연속 교시) 카드 오버레이
                              ...mergeGroups.map((mg) => _mergeCard(
                                    mg, rows, offsets, days, now,
                                    designOf, sh,
                                  )),
                            ],
                          ),
                        ),
                        SizedBox(height: bottomPad),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ],
    );
  }

  // ── 요일 헤더 셀 ───────────────────────────────────────────────
  Widget _dayHeader(int i, DateTime date, DateTime now, SurlapColors sh) {
    final isTodayDow = now.weekday - 1 == i;
    final isSat = i == 5;
    final isSun = i == 6;
    // 오늘은 동그라미(pill) 대신 accent 색으로만 강조. 날짜 숫자는 표시하지 않음.
    final nameColor = isTodayDow
        ? sh.accent
        : isSun ? sh.sun : isSat ? sh.sat : sh.ink;
    return SizedBox(
      width: _dayColW,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isTodayDow
              ? sh.accent.withValues(alpha: sh.dark ? 0.14 : 0.08)
              : sh.card2.withValues(alpha: sh.dark ? 1 : 0.6),
          border: Border(
            left: BorderSide(color: _gridLine(sh), width: 1),
            right: i == 6
                ? BorderSide(color: _gridLine(sh), width: 1)
                : BorderSide.none,
            bottom: BorderSide(color: _gridLine(sh), width: 1.5),
          ),
        ),
        child: Text(tr(_dowNames[i]),
            style: AppType.bodyLarge.copyWith(
                fontSize: _tight ? 14 : 16,
                fontWeight: FontWeight.w800,
                color: nameColor)),
      ),
    );
  }

  // ── 시간/교시 라벨 셀 ──────────────────────────────────────────
  Widget _labelCell(_RowDef row, double h, SurlapColors sh) {
    if (row.isDivider) {
      return SizedBox(height: _divH, width: _labelW);
    }
    final isSchool = row.type == _RType.school;
    final isLunch = row.type == _RType.lunch;
    return Container(
      height: h,
      width: _labelW,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSchool
            ? sh.accentBg.withValues(alpha: 0.35)
            : isLunch
                ? sh.accentBg.withValues(alpha: 0.55)
                : sh.card2,
        border: Border(
          right: BorderSide(color: _gridLine(sh), width: 1),
          bottom: BorderSide(color: _gridLine(sh), width: 1),
        ),
      ),
      child: isSchool
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${row.period}',
                    style: TextStyle(
                        fontSize: _tight ? 14 : 17,
                        fontWeight: FontWeight.w800,
                        color: sh.accentInk,
                        height: 1.0)),
                Text(tr('교시'),
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: sh.accentInk.withValues(alpha: 0.7))),
              ],
            )
          : Text(row.label,
              style: TextStyle(
                fontSize: isLunch ? 12 : 11,
                color: isLunch ? sh.accentInk : sh.inkSoft,
                fontWeight: isLunch ? FontWeight.w700 : FontWeight.w500,
              )),
    );
  }

  // ── 그리드 셀(단일) ───────────────────────────────────────────
  Widget _gridCell({
    required int col,
    required int ri,
    required _RowDef row,
    required List<DateTime> days,
    required DateTime now,
    required Map<int, Map<int, String>> displayData,
    required Set<(int, int)> mergeSet,
    required CellDesign Function(int, int) designOf,
    required Map<int, Map<int, String>> freeData,
    required SurlapColors sh,
  }) {
    final isMerged = mergeSet.contains((col, ri));
    final isToday = du.isSameDay(days[col], now);
    final text = displayData[col]?[row.hour] ?? '';
    final design = designOf(col, row.hour);
    final isLunch = row.type == _RType.lunch;
    final filled = text.isNotEmpty;

    void onTap() {
      if (_designMode) {
        _showDesignPanel(context, col, row.hour, sh);
      } else {
        _editCell(context, col, row.hour, freeData[col]?[row.hour] ?? '');
      }
    }

    // 병합 멤버 셀은 비워 두고(오버레이 카드가 그려짐), 오늘 컬럼 틴트만.
    Widget? child;
    if (!isMerged && filled) {
      child = _classCard(
        text: text, isToday: isToday, isLunch: isLunch,
        design: design, sh: sh,
      );
    } else if (!isMerged && !filled && !isLunch && row.hour >= 0) {
      // 빈 교시 라벨(자습/공강 등) — 설정에 라벨이 있을 때만.
      final emptyLabel =
          ref.read(settingsProvider).timetableEmptyLabel.trim();
      if (emptyLabel.isNotEmpty) {
        child = Center(
          child: Text(
            emptyLabel,
            style: TextStyle(
              fontSize: _subjectFont - 2,
              fontWeight: FontWeight.w500,
              color: sh.inkFaint,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
    }

    // 빈 셀도 아주 옅게 채워 허전함 제거(오늘 컬럼은 살짝 보랏빛).
    final cellBg = isToday
        ? sh.accent.withValues(alpha: sh.dark ? 0.10 : 0.06)
        : sh.ink.withValues(alpha: sh.dark ? 0.022 : 0.012);
    // 오늘 컬럼 좌우 구분선만 보라색으로 살짝 강조.
    final sideColor =
        isToday ? sh.accent.withValues(alpha: 0.30) : _gridLine(sh);
    final sideWidth = isToday ? 1.0 : 0.5;

    return SizedBox(
      width: _dayColW,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: cellBg,
            border: Border(
              left: BorderSide(color: sideColor, width: sideWidth),
              right: (col == 6 || isToday)
                  ? BorderSide(color: sideColor, width: sideWidth)
                  : BorderSide.none,
              bottom: BorderSide(color: _gridLine(sh), width: 0.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // ── 수업 카드 — 셀을 거의 채우는 블록형 ───────────────────────
  Widget _classCard({
    required String text,
    required bool isToday,
    required bool isLunch,
    required CellDesign design,
    required SurlapColors sh,
    bool merged = false,
  }) {
    final display = getDisplaySubjectName(text, lunch: isLunch);
    // 급식 메뉴는 줄별로 더 많이 보이게(작은 폰트·여러 줄).
    final isMenu = isLunch;
    final font = isMenu ? (_tight ? 8.5 : 10.0) : _subjectFont;

    final baseBg = isLunch
        ? (isToday
            ? sh.accent.withValues(alpha: 0.20)
            : (sh.dark ? sh.card2 : const Color(0xFFFFF3EC)))
        : sh.accent.withValues(
            alpha: isToday ? (sh.dark ? 0.34 : 0.22) : (sh.dark ? 0.20 : 0.12));
    final textColor = design.textColor ?? (sh.dark ? sh.ink : sh.accentInk);

    // 병합(연속 교시) 카드는 은은한 대각 그라데이션으로 큰 면적을 채운다.
    final useGradient = design.bg == null && merged && !isLunch;

    return Container(
      width: double.infinity,
      height: double.infinity,
      margin: EdgeInsets.all(_dim.cardMargin),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: isMenu ? 5 : 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: design.bg ?? (useGradient ? null : baseBg),
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  sh.accent.withValues(
                      alpha: isToday ? (sh.dark ? 0.40 : 0.26) : (sh.dark ? 0.24 : 0.15)),
                  sh.accent.withValues(
                      alpha: isToday ? (sh.dark ? 0.24 : 0.15) : (sh.dark ? 0.13 : 0.08)),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(_dim.cardRadius),
        border: Border.all(
          color: isToday
              ? sh.accent.withValues(alpha: 0.55)
              : sh.ink.withValues(alpha: sh.dark ? 0.14 : 0.07),
          width: isToday ? 1.2 : 1,
        ),
      ),
      child: isMenu
          // 급식 메뉴: 각 항목을 한 줄로 유지하고(글자단위 쪼갬 방지)
          // 칸 크기에 맞춰 통째로 살짝 줄여 표시.
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                display,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: font + 1,
                  height: 1.28,
                  letterSpacing: -0.2,
                  color: textColor,
                  fontWeight: design.bold ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            )
          // 과목명: 한 줄로 유지하되 길면 살짝만 줄여 글자단위 줄바꿈 방지.
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                display,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: font,
                  height: 1.1,
                  letterSpacing: -0.3,
                  color: textColor,
                  fontWeight: design.bold ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
    );
  }

  // ── 병합(연속 교시) 오버레이 카드 ─────────────────────────────
  Widget _mergeCard(
    _MergeGroup mg,
    List<_RowDef> rows,
    List<double> offsets,
    List<DateTime> days,
    DateTime now,
    CellDesign Function(int, int) designOf,
    SurlapColors sh,
  ) {
    final row = rows[mg.startRow];
    final isToday = du.isSameDay(days[mg.col], now);
    final isLunch = row.type == _RType.lunch;
    final design = designOf(mg.col, row.hour);
    final top = offsets[mg.startRow];
    final height = offsets[mg.startRow + mg.span] - top;
    return Positioned(
      top: top,
      left: mg.col * _dayColW,
      width: _dayColW,
      height: height,
      child: IgnorePointer(
        child: _classCard(
          text: mg.text, isToday: isToday, isLunch: isLunch,
          design: design, sh: sh, merged: true,
        ),
      ),
    );
  }

  // 그리드 선은 은은하게 — 카드가 주인공이 되도록.
  Color _gridLine(SurlapColors sh) =>
      sh.ink.withValues(alpha: sh.dark ? 0.10 : 0.07);
}

// ─── 햄버거 버튼 ──────────────────────────────────────────────────
class _HamburgerBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _HamburgerBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: sh.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
        ),
        child: Icon(Icons.menu_rounded, size: 20, color: sh.inkSoft),
      ),
    );
  }
}

// ─── Design panel bottom sheet ────────────────────────────────────

class _DesignPanel extends StatefulWidget {
  final CellDesign currentDesign;
  final List<Color> palette;
  final SurlapColors sh;
  final void Function(CellDesign) onApply;

  const _DesignPanel({
    required this.currentDesign,
    required this.palette,
    required this.sh,
    required this.onApply,
  });

  @override
  State<_DesignPanel> createState() => _DesignPanelState();
}

class _DesignPanelState extends State<_DesignPanel> {
  late Color? _bg;
  late bool _bold;

  @override
  void initState() {
    super.initState();
    _bg = widget.currentDesign.bg;
    _bold = widget.currentDesign.bold;
  }

  @override
  Widget build(BuildContext context) {
    final sh = widget.sh;
    return Container(
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: sh.ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(children: [
            Text(tr('셀 디자인'), style: AppType.titleMedium.copyWith(
                fontWeight: FontWeight.w800, color: sh.ink)),
            const Spacer(),
            TextButton(
              onPressed: () {
                widget.onApply(const CellDesign());
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: sh.danger),
              child: Text(tr('초기화')),
            ),
          ]),
          const SizedBox(height: Gap.md),
          Text(tr('배경색'), style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: Gap.sm,
            children: [
              GestureDetector(
                onTap: () => setState(() => _bg = null),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _bg == null ? sh.ink : sh.border, width: 2),
                  ),
                  child: const Center(child: Text('✕',
                      style: TextStyle(fontSize: 12, color: Color(0xFF888888)))),
                ),
              ),
              ...widget.palette.map((c) => GestureDetector(
                onTap: () => setState(() => _bg = c),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _bg == c ? sh.ink : Colors.transparent, width: 2),
                    boxShadow: _bg == c
                        ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6)]
                        : null,
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(children: [
            Text(tr('굵게'), style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
            const SizedBox(width: Gap.sm),
            Switch(
              value: _bold,
              onChanged: (v) => setState(() => _bold = v),
            ),
          ]),
          const SizedBox(height: Gap.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onApply(CellDesign(bg: _bg, bold: _bold));
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: sh.accent,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(tr('적용'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 시간표 내보내기(인쇄 미리보기형 공유) ─────────────────────────

/// 시간표를 깔끔한 이미지로 미리보고 공유/저장하는 페이지를 띄운다.
void openTimetableExport(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => const TimetableExportPage(),
  ));
}

class TimetableExportPage extends ConsumerStatefulWidget {
  const TimetableExportPage({super.key});

  @override
  ConsumerState<TimetableExportPage> createState() =>
      _TimetableExportPageState();
}

class _TimetableExportPageState extends ConsumerState<TimetableExportPage> {
  final _boundaryKey = GlobalKey();
  bool _weekend = false; // 토·일 포함
  bool _light = true;    // 밝게/어둡게
  bool _full = false;    // 0~24시 전체 시간 포함
  bool _busy = false;

  static const _accent = Color(0xFF8B7FF5);
  static const _dow = ['월', '화', '수', '목', '금', '토', '일'];

  double get _dayColW => _weekend ? 92 : 104;
  static const _labelW = 52.0;
  static const _headerH = 50.0;
  static const _schoolH = 84.0;

  Future<Uint8List?> _capture() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_busy) return;
    // iPad 시트 위치 기준 — async 전에 미리 계산.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : (Offset.zero & MediaQuery.of(context).size);
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        _toast(tr('이미지를 만들지 못했어요'));
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/Surlap_timetable_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: tr('Surlap 시간표'),
        sharePositionOrigin: origin,
      );
    } catch (e) {
      _toast(trf('공유 실패: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      await Gal.putImageBytes(bytes,
          name: 'Surlap_timetable_${DateTime.now().millisecondsSinceEpoch}');
      _toast(tr('이미지를 갤러리에 저장했어요'));
    } catch (_) {
      _toast(tr('저장하지 못했어요'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final neis = ref.watch(neisCacheProvider);
    final recurring = ref.watch(recurringProvider);

    final maxPeriod = _TimetableViewState._maxPeriod(neis.timetable);
    final days = _TimetableViewState._weekDays();
    // 전체 시간(_full): 0~24시 전부 / 기본: 교시+점심만.
    final allRows = _TimetableViewState._buildRows(maxPeriod)
        .where((r) => _full
            ? !r.isDivider
            : (r.type == _RType.school || r.type == _RType.lunch))
        .toList();
    final neisHour = _TimetableViewState._buildNeisHourData(neis.timetable);
    final weekly = {
      for (int c = 0; c < 7; c++)
        c: Map<int, String>.from(recurring[c] ?? const {}),
    };
    final tplData = _TimetableViewState._buildTemplateData(days);
    final displayData = _TimetableViewState._buildDisplayData(
        neisHour, tplData, weekly, neis.lunch, allRows);

    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        backgroundColor: sh.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: sh.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('시간표 공유'),
            style: AppType.titleLarge.copyWith(
                fontSize: 18, fontWeight: FontWeight.w800, color: sh.ink)),
      ),
      body: Column(
        children: [
          // ── 옵션 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 4, Gap.lg, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _toggleChip(tr('주말 포함'), _weekend,
                    () => setState(() => _weekend = !_weekend), sh),
                _toggleChip(tr('전체 시간'), _full,
                    () => setState(() => _full = !_full), sh),
                _toggleChip(_light ? tr('밝게') : tr('어둡게'), true,
                    () => setState(() => _light = !_light), sh),
              ],
            ),
          ),
          // ── 미리보기 ──
          Expanded(
            child: Container(
              width: double.infinity,
              color: sh.dark ? const Color(0xFF0E0D14) : const Color(0xFFEDEAF5),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: _buildExportImage(allRows, displayData, days),
                  ),
                ),
              ),
            ),
          ),
          // ── 액션 ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 10, Gap.lg, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.download_rounded, size: 19),
                      label: Text(tr('저장')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sh.inkSoft,
                        side: BorderSide(color: sh.ink.withValues(alpha: 0.14)),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: _busy
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.ios_share_rounded, size: 19),
                      label: Text(tr('공유하기'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      style: FilledButton.styleFrom(
                        backgroundColor: sh.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
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

  Widget _toggleChip(String label, bool active, VoidCallback onTap,
      SurlapColors sh) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? sh.accent.withValues(alpha: sh.dark ? 0.22 : 0.12)
              : sh.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active
                  ? sh.accent.withValues(alpha: 0.5)
                  : sh.ink.withValues(alpha: 0.08)),
        ),
        child: Text(label,
            style: AppType.labelMedium.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? sh.accent : sh.inkSoft)),
      ),
    );
  }

  // 캡처 대상 — 깔끔한 시간표 카드 이미지(고정 크기).
  Widget _buildExportImage(
    List<_RowDef> rows,
    Map<int, Map<int, String>> displayData,
    List<DateTime> days,
  ) {
    final cols = _weekend ? 7 : 5;
    final bg = _light ? const Color(0xFFFBFAFF) : const Color(0xFF1A1726);
    final ink = _light ? const Color(0xFF26203F) : Colors.white;
    final inkSoft = _light
        ? const Color(0xFF6B6480)
        : Colors.white.withValues(alpha: 0.6);
    final line = (_light ? Colors.black : Colors.white).withValues(alpha: 0.07);

    // 점심 행 높이(메뉴 줄 수 반영).
    final heights = <double>[];
    for (final r in rows) {
      if (r.type == _RType.lunch) {
        int lines = 1;
        for (int c = 0; c < cols; c++) {
          final t = displayData[c]?[r.hour] ?? '';
          if (t.isEmpty) continue;
          final n = getDisplaySubjectName(t, lunch: true).split('\n').length;
          if (n > lines) lines = n;
        }
        heights.add((26 + lines * 15).clamp(_schoolH, 220).toDouble());
      } else if (r.type == _RType.free) {
        heights.add(46); // 전체 시간 모드의 빈 시간 행
      } else {
        heights.add(_schoolH);
      }
    }
    final offsets = _TimetableViewState._rowOffsets(heights);
    final totalH = offsets.last;
    final mergeGroups = _TimetableViewState._computeMerges(rows, offsets, displayData)
        .where((g) => g.col < cols)
        .toList();
    final mergeSet = _TimetableViewState._buildMergeSet(mergeGroups);
    final tableW = _labelW + cols * _dayColW;

    final now = DateTime.now();
    final dateLabel =
        '${days.first.month}.${days.first.day} ~ ${days[cols - 1].month}.${days[cols - 1].day}';

    return Container(
      width: tableW + 32,
      color: bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 제목
          Row(
            children: [
              const Icon(Icons.calendar_view_week_rounded,
                  size: 18, color: _accent),
              const SizedBox(width: 6),
              Text(tr('내 시간표'),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      letterSpacing: -0.3)),
              const Spacer(),
              Text(dateLabel,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: inkSoft)),
            ],
          ),
          const SizedBox(height: 12),
          // 요일 헤더
          Row(
            children: [
              SizedBox(width: _labelW),
              ...List.generate(cols, (i) {
                final isToday = du.isSameDay(days[i], now);
                return SizedBox(
                  width: _dayColW,
                  child: Container(
                    height: _headerH,
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: isToday
                          ? BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(999))
                          : null,
                      child: Text(tr(_dow[i]),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isToday ? Colors.white : ink)),
                    ),
                  ),
                );
              }),
            ],
          ),
          // 그리드
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 라벨열
              SizedBox(
                width: _labelW,
                child: Column(
                  children: [
                    for (int ri = 0; ri < rows.length; ri++)
                      SizedBox(
                        height: heights[ri],
                        child: Center(
                          child: rows[ri].type == _RType.lunch
                              ? Text(tr('점심'),
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: _accent))
                              : rows[ri].type == _RType.free
                                  // 전체 시간 모드의 빈 시간 — 시각 라벨.
                                  ? Text(trf('{0}시', [rows[ri].hour]),
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: inkSoft))
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${rows[ri].period}',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: ink,
                                                height: 1)),
                                        Text(tr('교시'),
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: inkSoft)),
                                      ],
                                    ),
                        ),
                      ),
                  ],
                ),
              ),
              // 셀
              SizedBox(
                width: cols * _dayColW,
                height: totalH,
                child: Stack(
                  children: [
                    Column(
                      children: List.generate(rows.length, (ri) {
                        return SizedBox(
                          height: heights[ri],
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(cols, (c) {
                              final isMerged = mergeSet.contains((c, ri));
                              final text = displayData[c]?[rows[ri].hour] ?? '';
                              return SizedBox(
                                width: _dayColW,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: line, width: 0.5),
                                      bottom:
                                          BorderSide(color: line, width: 0.5),
                                    ),
                                  ),
                                  child: (!isMerged && text.isNotEmpty)
                                      ? _expCard(text,
                                          rows[ri].type == _RType.lunch, ink)
                                      : null,
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                    ...mergeGroups.map((g) {
                      final row = rows[g.startRow];
                      return Positioned(
                        top: offsets[g.startRow],
                        left: g.col * _dayColW,
                        width: _dayColW,
                        height:
                            offsets[g.startRow + g.span] - offsets[g.startRow],
                        child: _expCard(g.text, row.type == _RType.lunch, ink),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expCard(String text, bool isLunch, Color ink) {
    final display = getDisplaySubjectName(text, lunch: isLunch);
    final cardBg = isLunch
        ? (_light ? const Color(0xFFFFF1E8) : const Color(0xFF2A2436))
        : _accent.withValues(alpha: _light ? 0.13 : 0.24);
    final textColor = isLunch ? ink : (_light ? const Color(0xFF3A2E6B) : Colors.white);
    return Container(
      width: double.infinity,
      height: double.infinity,
      margin: const EdgeInsets.all(3),
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: isLunch ? 4 : 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        display,
        textAlign: TextAlign.center,
        maxLines: isLunch ? 7 : 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isLunch ? 9 : 12.5,
          height: 1.2,
          letterSpacing: -0.2,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

/// 특정 날짜의 시간표 수업(시각 hour → 과목명) — 주간/일간 뷰 읽기전용 표시용.
/// NEIS·템플릿·주간반복을 모두 합쳐, 그 날 요일의 교시 수업만 돌려준다(점심 제외).
Map<int, String> timetableSubjectsForDate(WidgetRef ref, DateTime date) {
  final neis = ref.read(neisCacheProvider);
  final recurring = ref.read(recurringProvider);
  final maxP = _TimetableViewState._maxPeriod(neis.timetable);
  final rows = _TimetableViewState._buildRows(maxP);
  final monday = date.subtract(Duration(days: date.weekday - 1));
  final days = List.generate(
      7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  final di = date.weekday - 1; // 월=0
  final neisHour = _TimetableViewState._buildNeisHourData(neis.timetable);
  final weekly = {
    for (int c = 0; c < 7; c++)
      c: Map<int, String>.from(recurring[c] ?? const {}),
  };
  final tpl = _TimetableViewState._buildTemplateData(days);
  final display = _TimetableViewState._buildDisplayData(
      neisHour, tpl, weekly, neis.lunch, rows);
  final out = <int, String>{};
  for (final r in rows) {
    if (r.type != _RType.school) continue;
    final t = display[di]?[r.hour] ?? '';
    if (t.trim().isNotEmpty) out[r.hour] = t;
  }
  return out;
}
