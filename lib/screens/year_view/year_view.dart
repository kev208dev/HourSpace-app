import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../providers/view_provider.dart';
import '../../core/utils/date_utils.dart' as du;
import '../../providers/events_provider.dart';

// 연간 미니 월 카드 라운드(홈·캘린더 톤과 통일).
const double _yRadius = 18;

class YearView extends ConsumerWidget {
  const YearView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewProvider);
    final events = ref.watch(eventsProvider);
    final sh = context.sh;
    final year = view.viewYear;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: Gap.sm,
        mainAxisSpacing: Gap.sm,
      ),
      itemCount: 12,
      itemBuilder: (context, i) {
        final month = i + 1;
        return _MiniMonthCard(
          year: year,
          month: month,
          events: events,
          sh: sh,
          // 셀이 제자리에서 커지며 펼쳐지는 zoom-in 후 월간으로 전환.
          onTap: (cardCtx) =>
              _zoomToMonth(cardCtx, ref, year, month, sh, events),
        );
      },
    );
  }

  // 탭한 미니 월 카드의 화면 위치를 잡아, 그 자리에서 풀스크린으로 커지는
  // 오버레이를 띄운 뒤 월간 뷰로 전환한다(뒤에서 월간이 빌드돼 끝에 드러남).
  void _zoomToMonth(BuildContext cardCtx, WidgetRef ref, int year, int month,
      SurlapColors sh, Map<String, List<dynamic>> events) {
    final notifier = ref.read(viewProvider.notifier);
    final box = cardCtx.findRenderObject();
    // rect/overlay를 전환 전에 확보(전환 시작하면 year 뷰가 사라짐).
    if (box is! RenderBox || !box.hasSize) {
      notifier.setYearMonth(year, month);
      notifier.setMode(ViewMode.events);
      return;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final overlay = Overlay.of(cardCtx);

    // 월간 뷰를 먼저 띄워 오버레이 뒤에서 빌드되게 한다.
    notifier.setYearMonth(year, month);
    notifier.setMode(ViewMode.events);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ZoomOverlay(
        startRect: rect,
        year: year,
        month: month,
        sh: sh,
        events: events,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

// ── 연간→월간 줌인 오버레이 ───────────────────────────────────────────
// 미니 월 카드를 시작 위치(startRect)에서 풀스크린까지 키우며, 마지막 구간엔
// 페이드아웃해 뒤에서 빌드된 실제 월간 뷰가 드러나게 한다.
class _ZoomOverlay extends StatefulWidget {
  final Rect startRect;
  final int year, month;
  final SurlapColors sh;
  final Map<String, List<dynamic>> events;
  final VoidCallback onDone;

  const _ZoomOverlay({
    required this.startRect,
    required this.year,
    required this.month,
    required this.sh,
    required this.events,
    required this.onDone,
  });

  @override
  State<_ZoomOverlay> createState() => _ZoomOverlayState();
}

class _ZoomOverlayState extends State<_ZoomOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _monthNames = [
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ];

  @override
  Widget build(BuildContext context) {
    final sh = widget.sh;
    final full = Offset.zero & MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        final rect = Rect.lerp(widget.startRect, full, t)!;
        final radius = lerpDouble(_yRadius, 0, t)!;
        // 마지막 22% 구간에 카드 페이드아웃 → 실제 월간 뷰 노출.
        final fade = (1 - ((t - 0.78) / 0.22)).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: rect,
                child: Opacity(
                  opacity: fade,
                  child: Container(
                    decoration: BoxDecoration(
                      color: sh.card,
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: sh.dark ? 0.3 : 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          width: double.infinity,
                          color: sh.card2,
                          child: Center(
                            child: Text(
                              _monthNames[widget.month - 1],
                              style: AppType.labelMedium.copyWith(
                                  fontSize: 12 + 8 * t,
                                  fontWeight: FontWeight.w800,
                                  color: sh.inkSoft),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _MiniMonthGrid(
                            year: widget.year,
                            month: widget.month,
                            sh: sh,
                            events: widget.events,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 미니 월 카드 ────────────────────────────────────────────────────

class _MiniMonthCard extends StatelessWidget {
  final int year, month;
  final Map<String, List<dynamic>> events;
  final SurlapColors sh;
  final void Function(BuildContext cardContext) onTap;

  const _MiniMonthCard({
    required this.year,
    required this.month,
    required this.events,
    required this.sh,
    required this.onTap,
  });

  static const _monthNames = [
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;

    return GestureDetector(
      onTap: () => onTap(context),
      child: Container(
        decoration: BoxDecoration(
          color: sh.card,
          borderRadius: BorderRadius.circular(_yRadius),
          border: isCurrentMonth
              ? Border.all(color: sh.accent, width: 1.5)
              : Border.all(color: sh.ink.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: sh.dark ? 0.28 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // 월 헤더
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isCurrentMonth
                    ? sh.accent.withValues(alpha: 0.12)
                    : sh.card2,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(_yRadius)),
              ),
              child: Center(
                child: Text(
                  _monthNames[month - 1],
                  style: AppType.labelMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isCurrentMonth ? sh.accent : sh.inkSoft,
                  ),
                ),
              ),
            ),
            // 미니 캘린더 그리드 (이벤트 dot 포함)
            Expanded(
              child: _MiniMonthGrid(
                year: year,
                month: month,
                sh: sh,
                events: events,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 공유 미니 그리드 위젯 ─────────────────────────────────────────────
// _MiniMonthCard(년 뷰)와 _ZoomOverlay(전환 중) 양쪽에서 재사용.

class _MiniMonthGrid extends StatelessWidget {
  final int year, month;
  final SurlapColors sh;
  /// null이면 이벤트 dot 표시 안 함 (줌 오버레이에서 사용).
  final Map<String, List<dynamic>>? events;

  const _MiniMonthGrid({
    required this.year,
    required this.month,
    required this.sh,
    this.events,
  });

  static const _dow = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    // 일요일 시작
    final startOffset = first.weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final cells = startOffset + daysInMonth;
    final rows = (cells / 7).ceil();
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        children: [
          // 요일 헤더 (일=빨강, 토=파랑 살짝)
          Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Center(
                  child: Text(_dow[i],
                      style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: i == 0
                              ? sh.sun.withValues(alpha: 0.7)
                              : i == 6
                                  ? sh.sat.withValues(alpha: 0.7)
                                  : sh.inkFaint)),
                ),
              ),
            ),
          ),
          // 날짜 셀
          Expanded(
            child: Column(
              children: List.generate(rows, (r) {
                return Expanded(
                  child: Row(
                    children: List.generate(7, (c) {
                      final idx = r * 7 + c;
                      final day = idx - startOffset + 1;
                      if (day < 1 || day > daysInMonth) {
                        return const Expanded(child: SizedBox());
                      }
                      final key =
                          du.toDateKey(DateTime(year, month, day));
                      final hasEvent =
                          events != null && (events![key] ?? []).isNotEmpty;
                      final isToday = year == now.year &&
                          month == now.month &&
                          day == now.day;
                      return Expanded(
                        child: Center(
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: isToday
                                ? BoxDecoration(
                                    color: sh.accent,
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    color: isToday ? Colors.white : sh.ink,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                                if (hasEvent)
                                  Positioned(
                                    bottom: isToday ? 1 : 0,
                                    child: Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color:
                                            isToday ? Colors.white : sh.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
