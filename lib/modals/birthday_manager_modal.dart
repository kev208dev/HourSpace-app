import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';
import '../providers/birthdays_provider.dart';
import '../providers/birthday_notify_provider.dart';
import '../widgets/mascot/mascot.dart';
import '../widgets/mascot/mascot_feedback.dart';

Future<void> showBirthdayManagerModal(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BirthdayManagerModal(),
    );

class BirthdayManagerModal extends ConsumerStatefulWidget {
  const BirthdayManagerModal({super.key});

  @override
  ConsumerState<BirthdayManagerModal> createState() =>
      _BirthdayManagerModalState();
}

class _BirthdayManagerModalState extends ConsumerState<BirthdayManagerModal> {
  final _nameCtrl = TextEditingController();
  DateTime? _picked;
  bool _includeYear = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _picked ?? DateTime(now.year - 20, now.month, now.day);
    final last = DateTime(now.year + 10, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: context.sh.birthdayColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _picked = picked);
  }

  void _addManual() {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      MascotToast.error(context, tr('이름을 입력해 주세요'));
      return;
    }
    if (_picked == null) {
      MascotToast.error(context, tr('생일 날짜를 선택해 주세요'));
      return;
    }
    ref
        .read(birthdaysProvider.notifier)
        .add(
          Birthday.create(
            name: name,
            month: _picked!.month,
            day: _picked!.day,
            year: _includeYear ? _picked!.year : null,
          ),
        );
    ref.read(birthdayNotifyProvider.notifier).reschedule();
    setState(() {
      _nameCtrl.clear();
      _picked = null;
    });
    MascotToast.success(context, trf('{0} 생일을 추가했어요', [name]));
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final birthdays = ref.watch(birthdaysProvider);
    final notify = ref.watch(birthdayNotifyProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: sh.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.md,
                  Gap.sm,
                  Gap.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.cake_rounded, color: sh.birthdayColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      tr('생일 챙기기'),
                      style: AppType.titleLarge.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: sh.ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: sh.inkSoft, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(color: sh.border, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.md,
                    Gap.lg,
                    Gap.xl,
                  ),
                  children: [
                    // ── 알림 설정 ──
                    _Card(
                      sh: sh,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 20,
                                color: sh.inkSoft,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr('생일 알림'),
                                  style: AppType.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: sh.ink,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: notify.enabled,
                                activeThumbColor: sh.birthdayColor,
                                onChanged: (v) => ref
                                    .read(birthdayNotifyProvider.notifier)
                                    .setEnabled(v),
                              ),
                            ],
                          ),
                          if (notify.enabled) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                tr('미리 알림'),
                                style: AppType.labelMedium.copyWith(
                                  color: sh.inkSoft,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final d in const [0, 1, 3, 7, 30])
                                  _DayChip(
                                    label: d == 0
                                        ? tr('당일만')
                                        : d == 30
                                            ? tr('1달 전')
                                            : trf('{0}일 전', [d]),
                                    selected: notify.daysBefore == d,
                                    color: sh.birthdayColor,
                                    sh: sh,
                                    onTap: () => ref
                                        .read(birthdayNotifyProvider.notifier)
                                        .setDaysBefore(d),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── 직접 추가 ──
                    Text(
                      tr('직접 추가'),
                      style: AppType.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: sh.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Card(
                      sh: sh,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            style: AppType.bodyLarge.copyWith(color: sh.ink),
                            decoration: InputDecoration(
                              hintText: tr('이름'),
                              hintStyle: TextStyle(color: sh.inkFaint),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                          Divider(color: sh.border, height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.cake_outlined,
                                          size: 18,
                                          color: sh.birthdayColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _picked == null
                                                ? tr('생일 선택')
                                                : _includeYear
                                                    ? '${_picked!.year}.${_picked!.month}.${_picked!.day}'
                                                    : trf('{0}월 {1}일', [
                                                        _picked!.month,
                                                        _picked!.day
                                                      ]),
                                            style: AppType.bodyLarge.copyWith(
                                              color: _picked == null
                                                  ? sh.inkFaint
                                                  : sh.ink,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => setState(
                                    () => _includeYear = !_includeYear),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _includeYear
                                            ? Icons.check_box_rounded
                                            : Icons
                                                .check_box_outline_blank_rounded,
                                        size: 18,
                                        color: _includeYear
                                            ? sh.birthdayColor
                                            : sh.inkFaint,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tr('연도 포함'),
                                        style: AppType.labelMedium.copyWith(
                                          color: sh.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _addManual,
                              style: FilledButton.styleFrom(
                                backgroundColor: sh.birthdayColor,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                tr('추가'),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── 등록된 생일 목록 ──
                    Row(
                      children: [
                        Text(
                          trf('등록된 생일 ({0})', [birthdays.length]),
                          style: AppType.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: sh.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (birthdays.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: MascotEmptyState(
                          expression: MascotExpression.neutral,
                          title: tr('아직 등록된 생일이 없어요'),
                          message: tr('위에서 직접 추가해 보세요'),
                          mascotSize: 88,
                          showStars: false,
                        ),
                      )
                    else
                      ...birthdays.map(
                        (b) => _BirthdayRow(
                          b: b,
                          sh: sh,
                          onDelete: () {
                            ref
                                .read(birthdaysProvider.notifier)
                                .removeById(b.id);
                            ref
                                .read(birthdayNotifyProvider.notifier)
                                .reschedule();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── D-day/나이 표기 헬퍼 ──
String dDayLabel(Birthday b) {
  final d = b.daysUntilNext();
  return d == 0 ? tr('오늘 🎉') : 'D-$d';
}

class _BirthdayRow extends StatelessWidget {
  final Birthday b;
  final SurlapColors sh;
  final VoidCallback onDelete;
  const _BirthdayRow({
    required this.b,
    required this.sh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dday = b.daysUntilNext();
    final sub = b.year != null
        ? trf('{0}월 {1}일 · {2}년생', [b.month, b.day, b.year!])
        : trf('{0}월 {1}일', [b.month, b.day]);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
      decoration: BoxDecoration(
        color: sh.card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sh.ink.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: sh.birthdayColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.cake_rounded, size: 18, color: sh.birthdayColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name,
                  style: AppType.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: sh.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(sub, style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: dday == 0
                  ? sh.birthdayColor
                  : sh.birthdayColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              dDayLabel(b),
              style: AppType.labelMedium.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: dday == 0 ? Colors.white : sh.birthdayColor,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: sh.danger,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final SurlapColors sh;
  final Widget child;
  const _Card({required this.sh, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: sh.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: sh.ink.withValues(alpha: 0.06)),
    ),
    child: child,
  );
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final SurlapColors sh;
  final VoidCallback onTap;
  const _DayChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.sh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : sh.card2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : sh.ink.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: AppType.labelMedium.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? color : sh.inkSoft,
          ),
        ),
      ),
    );
  }
}
