import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';

/// 탭 화면 상단 제목 줄 — 앱 전체가 쓰는 단 하나의 헤더.
///
/// 화면마다 제목 크기와 아이콘 여백이 제각각이던 것을 두 variant 로 묶는다.
///
///  * [SurlapScreenHeader.hero] — 날짜가 화면의 주인공인 홈. 큰 날짜 + 위 첨자.
///  * [SurlapScreenHeader] (standard) — 할 일 · 공유 · 내 정보. 제목 한 줄.
///
/// 캘린더는 이전/다음 이동 구조가 달라 자체 헤더를 쓰지만, 그쪽도 아이콘은
/// [SurlapIconButton], 제목은 `AppType.navTitle` 로 같은 규격을 따른다.
class SurlapScreenHeader extends StatelessWidget {
  /// 큰 제목. hero 는 날짜, standard 는 화면 이름.
  final String title;

  /// hero 에서 제목 위에 붙는 작은 줄(예: 전체 날짜).
  final String? eyebrow;

  /// 우측 액션 — [SurlapIconButton] 을 넣는다.
  final List<Widget> actions;

  final bool hero;

  const SurlapScreenHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.eyebrow,
  }) : hero = false;

  const SurlapScreenHeader.hero({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const [],
  }) : hero = true;

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    return Row(
      crossAxisAlignment:
          hero ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: AppType.label.copyWith(
                    fontSize: 12,
                    color: sh.inkCaption,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                title,
                style: (hero ? AppType.heroTitle : AppType.screenTitle)
                    .copyWith(color: sh.ink),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// 헤더·툴바 아이콘 버튼 — 아이콘 20, 터치 영역 kMinTouch(44).
///
/// 화면마다 InkResponse + Padding 을 손으로 조합하며 아이콘이 19/20/21 로
/// 갈리고 터치 영역이 33px 밖에 안 나오던 것을 하나로 모은다.
class SurlapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// 접근성 라벨 겸 툴팁. 아이콘만 있는 버튼이라 반드시 채운다.
  final String tooltip;

  final double size;
  final Color? color;

  const SurlapIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = kHeaderIconSize,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: kMinTouch / 2,
          child: SizedBox(
            width: kMinTouch,
            height: kMinTouch,
            child: Icon(icon, size: size, color: color ?? context.sh.ink),
          ),
        ),
      ),
    );
  }
}
