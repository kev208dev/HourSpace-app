import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../models/event_item.dart';

/// 읽기 전용 일정 상세 시트.
/// 스포츠 경기·학사일정·생일·구독 공유 일정처럼 편집할 수 없는 항목을
/// 탭하면 편집 모달 대신 이 상세를 띄운다.
Future<void> showEventDetailSheet(BuildContext context, EventItem e) =>
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventDetailSheet(e: e),
    );

class _EventDetailSheet extends StatelessWidget {
  final EventItem e;
  const _EventDetailSheet({required this.e});

  ({Color color, IconData? icon, String? emoji, String label}) _meta(
      SurlapColors sh) {
    if (e.sport) {
      return (
        color: Color(e.sportColor ?? 0xFF6C63FF),
        icon: null,
        emoji: e.sportEmoji ?? '🏅',
        label: '스포츠 경기'
      );
    }
    if (e.academic) {
      return (
        color: sh.academicColor,
        icon: Icons.school_rounded,
        emoji: null,
        label: '학사일정'
      );
    }
    if (e.birthday) {
      return (
        color: sh.birthdayColor,
        icon: Icons.cake_rounded,
        emoji: null,
        label: '생일'
      );
    }
    return (
      color: sh.accent,
      icon: Icons.event_rounded,
      emoji: null,
      label: '공유 캘린더 일정'
    );
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final m = _meta(sh);
    final time = !e.hasTime
        ? null
        : (e.te != null && e.te!.isNotEmpty ? '${e.tm} – ${e.te}' : e.tm);

    return Container(
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: sh.ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 제목 + 색/아이콘
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: _badgeChild(m),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.t,
                    style: AppType.titleMedium.copyWith(
                        fontWeight: FontWeight.w800, color: sh.ink)),
              ),
              // 항상 보이는 닫기(×) 버튼.
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: '닫기',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (time != null)
            _row(Icons.schedule_rounded, time, sh),
          _row(Icons.sell_outlined, m.label, sh, color: m.color),
          const SizedBox(height: 14),
          // 읽기 전용 안내
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: sh.ink.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: sh.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('읽기 전용 일정 — 외부 소스에서 자동으로 표시돼요.',
                      style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 헤더 배지 내용 — 스포츠 팀 로고가 있으면 로고, 없으면 이모지/아이콘.
  Widget _badgeChild(({Color color, IconData? icon, String? emoji, String label}) m) {
    final logo = e.sportLogo;
    final emojiW = m.emoji != null
        ? Text(m.emoji!, style: const TextStyle(fontSize: 20))
        : Icon(m.icon, size: 20, color: m.color);
    if (e.sport && logo != null && logo.isNotEmpty) {
      return Image.network(
        logo,
        width: 26,
        height: 26,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => emojiW,
      );
    }
    return emojiW;
  }

  Widget _row(IconData icon, String text, SurlapColors sh, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? sh.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppType.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600, color: sh.ink)),
          ),
        ],
      ),
    );
  }
}
