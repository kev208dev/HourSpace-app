import 'package:flutter/material.dart';

/// 아이콘 세트.
///
/// 핸드오프는 Phosphor Icons(regular 기본, 활성 상태만 fill)를 지정한다.
/// `phosphor_flutter` 2.1.0 은 `IconData` 를 상속하는데 Flutter 3.44 에서
/// `IconData` 가 final class 가 되어 컴파일되지 않는다. 그래서 같은 이름·같은
/// 획 인상을 갖는 Material 아이콘으로 1:1 대응시켜 둔다.
///
/// Phosphor 가 Flutter 3.44 를 지원하면 이 파일의 매핑만 교체하면 된다.
/// 화면 코드는 Phosphor 이름 그대로 `AppIcons.house` 식으로 참조한다.
abstract final class AppIcons {
  // ── 탭바 ──
  static const house = Icons.home_outlined;
  static const houseFill = Icons.home_rounded;
  static const calendarBlank = Icons.calendar_today_outlined;
  static const calendarBlankFill = Icons.calendar_month_rounded;
  static const checkSquare = Icons.check_box_rounded;
  static const checkSquareFill = Icons.check_box_rounded;
  static const shareNetwork = Icons.share_outlined;
  static const shareNetworkFill = Icons.share_rounded;
  static const userCircle = Icons.account_circle_outlined;
  static const userCircleFill = Icons.account_circle_rounded;

  // ── 이동 ──
  static const caretLeft = Icons.chevron_left_rounded;
  static const caretRight = Icons.chevron_right_rounded;
  static const caretUp = Icons.expand_less_rounded;
  static const caretDown = Icons.expand_more_rounded;

  // ── 액션 ──
  static const magnifyingGlass = Icons.search_rounded;
  static const lightning = Icons.bolt_outlined;
  static const plus = Icons.add_rounded;
  static const plusCircle = Icons.add_circle_outline_rounded;
  static const check = Icons.check_rounded;
  static const x = Icons.close_rounded;
  static const trash = Icons.delete_outline_rounded;
  static const notePencil = Icons.edit_note_rounded;
  static const arrowClockwise = Icons.refresh_rounded;

  // ── 개체 ──
  static const squaresFour = Icons.grid_view_outlined;
  static const calendarPlus = Icons.edit_calendar_outlined;
  static const cards = Icons.dashboard_customize_outlined;
  static const cake = Icons.cake_outlined;
  static const clock = Icons.schedule_rounded;
  static const circleDashed = Icons.circle_outlined;

  // ── 할 일 상태 (시작 전 / 진행 중 / 완료) ──
  static const square = Icons.check_box_outline_blank_rounded;
  static const circleHalf = Icons.contrast_rounded;

  // ── 상태·고지 ──
  static const info = Icons.info_outline_rounded;
  static const warningCircle = Icons.error_outline_rounded;
  static const shieldWarning = Icons.gpp_maybe_outlined;
  static const cloudSlash = Icons.cloud_off_outlined;
  static const lockSimple = Icons.lock_outline_rounded;
  static const circleNotch = Icons.refresh_rounded;

  // ── 로그인 ──
  static const googleLogo = Icons.g_mobiledata_rounded;
  static const appleLogo = Icons.apple_rounded;
}
