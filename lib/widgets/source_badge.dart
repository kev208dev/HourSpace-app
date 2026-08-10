import 'package:flutter/material.dart';

import '../core/calendar/calendar_item.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/strings.dart';

/// 항목의 출처를 한 눈에 보여주는 작은 라벨.
///
/// 검색 결과·아젠다·오늘 화면에서 "이건 학교에서 온 거다 / 내가 넣은 거다"를
/// 구분하는 단일 컴포넌트. 화면마다 다른 뱃지를 만들지 않기 위해 여기 하나만 쓴다.
class SourceBadge extends StatelessWidget {
  final CalendarSource source;

  /// 소스 색이 따로 있으면(테마·스포츠 구독 색) 그 색을 쓴다.
  final Color? color;

  const SourceBadge({super.key, required this.source, this.color});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final c = color ?? sh.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        tr(source.badgeLabel),
        style: AppType.label.copyWith(
          color: c,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 할 일용 뱃지 — [SourceBadge]와 같은 모양을 유지한다.
class TodoBadge extends StatelessWidget {
  final Color? color;
  const TodoBadge({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final c = color ?? sh.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        tr('할 일'),
        style: AppType.label.copyWith(
          color: c,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
