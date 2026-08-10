import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../theme/app_theme.dart';

/// 할 일 상태(0 시작 전 / 1 진행 중 / 2 완료) 아이콘.
/// 상태는 모양으로 구분한다 — 색을 우선순위 신호로 쓰지 않는다.
IconData todoStatusIcon(int status) => switch (status) {
      2 => AppIcons.checkSquare,
      1 => AppIcons.circleHalf,
      _ => AppIcons.square,
    };

/// 상태 라벨.
String todoStatusLabel(int status) => switch (status) {
      2 => '완료',
      1 => '진행 중',
      _ => '시작 전',
    };

/// 상태별 아이콘 색. 진행 중·완료는 accent, 시작 전은 흐린 잉크.
Color todoStatusColor(int status, int priority, SurlapColors sh) =>
    status >= 1 ? sh.accent : sh.ink.withValues(alpha: 0.42);

/// 우선순위 배지 배경. P1 만 경고 틴트, 나머지는 중립.
Color todoPriorityBg(int priority, SurlapColors sh) =>
    priority == 1 ? sh.accent2Bg : sh.card2;

/// 우선순위 배지 글자색.
Color todoPriorityFg(int priority, SurlapColors sh) =>
    priority == 1 ? sh.accent2Ink : sh.ink.withValues(alpha: 0.75);

/// 우선순위 색 — 목록 좌측 바 등 단색이 필요한 자리.
/// 새 디자인에서는 P1 만 경고색이고 나머지는 중립이다.
Color todoPriorityColor(int priority, SurlapColors sh) =>
    priority == 1 ? sh.accent2 : sh.inkSoft;
