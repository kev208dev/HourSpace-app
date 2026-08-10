import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../providers/birthday_notify_provider.dart';
import '../../providers/briefing_notify_provider.dart';
import '../../providers/event_notify_provider.dart';
import '../../utils/birthday_notifications.dart';
import '../../widgets/app_toast.dart';

/// 알림 (핸드오프 I2 · spec §17).
///
/// 로컬 알림만 쓴다. 시간대는 Asia/Seoul, 기기가 쉬는 중에도 보낼 수 있는
/// 느슨한 예약이다. 세 가지 모두 기본값은 꺼짐이고, 켤 때 권한을 요청한다.
///
/// 계통마다 알림 ID 대역이 나뉘어 있어 하나를 다시 예약해도 다른 알림이
/// 사라지지 않는다(NotificationIds).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const _leads = [0, 5, 15, 30, 60];
  static const _briefHours = [6, 7, 8, 9, 10, 12, 18, 21];
  static const _bdayDays = [0, 1, 3, 7, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final event = ref.watch(eventNotifyProvider);
    final brief = ref.watch(briefingNotifyProvider);
    final bday = ref.watch(birthdayNotifyProvider);

    Future<bool> ask() async {
      final granted = await BirthdayNotifications.requestPermission();
      if (!granted && context.mounted) {
        AppToast.error(context, tr('알림 권한이 없어 예약할 수 없습니다.'));
      }
      return granted;
    }

    return Scaffold(
      backgroundColor: sh.bg,
      appBar: AppBar(
        backgroundColor: sh.bg,
        elevation: 0,
        title: Text(tr('알림'), style: AppType.title.copyWith(color: sh.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        children: [
          Text(
            tr('모두 기본값은 꺼짐입니다. 켤 때 알림 권한을 요청하고, 기기가 쉬는 중에도 '
                '보낼 수 있는 느슨한 예약 방식(Asia/Seoul)을 씁니다.'),
            style: AppType.sub.copyWith(
                height: 1.6, color: sh.ink.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: Gap.md),

          // ── 일정 알림 ──
          _NotifCard(
            title: tr('일정 알림'),
            sub: tr('앞으로 올 내 시간 일정만 · 최대 60건'),
            on: event.enabled,
            onToggle: (v) async {
              if (v && !await ask()) return;
              await ref.read(eventNotifyProvider.notifier).setEnabled(v);
            },
            expanded: [
              _ChipRow(
                labels: [
                  for (final m in _leads) m == 0 ? tr('정시') : trf('{0}분 전', [m]),
                ],
                selectedIndex: _leads.indexOf(event.leadMinutes),
                onPick: (i) => ref
                    .read(eventNotifyProvider.notifier)
                    .setLeadMinutes(_leads[i]),
              ),
              const SizedBox(height: 10),
              _Note(tr('반복 생성 일정·공유·스포츠·학사일정·생일·시간표는 여기에 포함되지 않습니다.')),
            ],
          ),
          const SizedBox(height: Gap.sm),

          // ── 하루 브리핑 ──
          _NotifCard(
            title: tr('하루 브리핑'),
            sub: tr('매일 같은 시각에 오늘 요약'),
            on: brief.enabled,
            onToggle: (v) async {
              if (v && !await ask()) return;
              await ref.read(briefingNotifyProvider.notifier).setEnabled(v);
            },
            expanded: [
              _ChipRow(
                labels: [for (final h in _briefHours) trf('{0}시', [h])],
                selectedIndex: _briefHours.indexOf(brief.hour),
                onPick: (i) => ref
                    .read(briefingNotifyProvider.notifier)
                    .setHour(_briefHours[i]),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),

          // ── 생일 알림 ──
          _NotifCard(
            title: tr('생일 알림'),
            sub: tr('오전 9시 · 매년 반복'),
            on: bday.enabled,
            onToggle: (v) async {
              if (v && !await ask()) return;
              await ref.read(birthdayNotifyProvider.notifier).setEnabled(v);
            },
            expanded: [
              _ChipRow(
                labels: [
                  for (final d in _bdayDays)
                    d == 0 ? tr('당일') : trf('{0}일 전', [d]),
                ],
                selectedIndex: _bdayDays.indexOf(bday.daysBefore),
                onPick: (i) => ref
                    .read(birthdayNotifyProvider.notifier)
                    .setDaysBefore(_bdayDays[i]),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          _Note(tr('알림 계통마다 ID 대역이 나뉘어 있어, 하나를 다시 예약해도 '
              '다른 알림이 함께 사라지지 않습니다.')),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final String title;
  final String sub;
  final bool on;
  final ValueChanged<bool> onToggle;
  final List<Widget> expanded;

  const _NotifCard({
    required this.title,
    required this.sub,
    required this.on,
    required this.onToggle,
    this.expanded = const [],
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: sh.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppType.number
                            .copyWith(fontWeight: FontWeight.w600, color: sh.ink)),
                    const SizedBox(height: 3),
                    Text(sub,
                        style: AppType.caption.copyWith(
                            color: sh.ink.withValues(alpha: 0.50))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Switch(on: on, onChanged: onToggle),
            ],
          ),
          if (on && expanded.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            ...expanded,
          ],
        ],
      ),
    );
  }
}

/// 목업 규격 스위치 — 트랙 40×23, 노브 19, 켜짐 accent.
class _Switch extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Semantics(
      toggled: on,
      child: GestureDetector(
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: Motion.micro,
          curve: Motion.curve,
          width: 40,
          height: 23,
          decoration: BoxDecoration(
            color: on ? sh.accent : sh.border,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.micro,
                curve: Motion.curve,
                top: 2,
                left: on ? 19 : 2,
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: sh.shadowCard,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onPick;

  const _ChipRow({
    required this.labels,
    required this.selectedIndex,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onPick(i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: i == selectedIndex ? sh.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(
                    color: i == selectedIndex ? sh.accent : sh.border),
              ),
              child: Text(labels[i],
                  style: AppType.sub.copyWith(
                      fontWeight: FontWeight.w600,
                      color: i == selectedIndex ? sh.bg : sh.ink)),
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: AppType.caption.copyWith(
          height: 1.6, color: context.sh.ink.withValues(alpha: 0.48)));
}
