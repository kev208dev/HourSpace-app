import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../i18n/app_lang.dart';
import '../i18n/strings.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/event_notify_provider.dart';
import '../providers/briefing_notify_provider.dart';
import '../providers/themes_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/birthdays_provider.dart';
import '../providers/academic_schedule_provider.dart';
import '../providers/user_type_provider.dart';
import '../models/user_type.dart';
import '../supabase/neis_service.dart';
import '../modals/neis_setup_modal.dart';
import '../modals/birthday_manager_modal.dart';
import '../widgets/coach_mark.dart';
import '../widgets/school_logo.dart';
import 'feature_intro/feature_intro_screen.dart';
import 'how_to_guide/how_to_guide_screen.dart';

/// 보기 설정 — 하단 nav의 한 탭으로, 다른 뷰처럼 좌우 viewer(AnimatedSwitcher)
/// 안에서 전환되는 in-shell 뷰. (push 페이지 아님 → 자체 헤더를 그린다)
/// 설정 섹션들 — 프로필 뷰 안에 인라인으로 들어간다(별도 설정 화면 없음).
class SettingsSections extends ConsumerWidget {
  const SettingsSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sh = context.sh;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final themes = ref.watch(themesProvider);
    final hidden = ref.watch(filterProvider);
    final birthdays = ref.watch(birthdaysProvider);
    final userType = ref.watch(userTypeProvider);
    // 학교 연동(NEIS)은 초·중·고만. 유형 미선택(레거시)은 종전대로 노출.
    final showSchool = userType == null || userType.isSchoolStudent;
    final school = NeisSchool.load();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 내 유형 ──
        SettingsSectionCard(
          sh: sh,
          title: tr('내 정보'),
          child: SettingsRow(
            sh: sh,
            icon: Icons.badge_outlined,
            title: tr('내 유형'),
            trailing: _TypePill(
                type: userType,
                sh: sh,
                onTap: () => _showTypePicker(context, ref, userType)),
            onTap: () => _showTypePicker(context, ref, userType),
          ),
        ),
        const SizedBox(height: 12),

        // ── 카테고리 ──
        SettingsSectionCard(
          sh: sh,
          title: tr('카테고리'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CategoryFilterChip(
                label: tr('전체'),
                color: sh.inkSoft,
                selected: hidden.isEmpty,
                sh: sh,
                onTap: () {
                  final f = ref.read(filterProvider.notifier);
                  if (hidden.isEmpty) {
                    f.setAll(themes.map((t) => t.id).toList());
                  } else {
                    f.clear();
                  }
                },
              ),
              ...themes.map((t) => CategoryFilterChip(
                    label: tr(t.name),
                    color: t.colorValue,
                    selected: !hidden.contains(t.id),
                    sh: sh,
                    onTap: () =>
                        ref.read(filterProvider.notifier).toggle(t.id),
                  )),
              // 생일 — 별도 카테고리. 등록된 생일이 있을 때만 노출.
              if (birthdays.isNotEmpty)
                CategoryFilterChip(
                  label: tr('생일'),
                  color: sh.birthdayColor,
                  selected: !hidden.contains(birthdayThemeId),
                  sh: sh,
                  onTap: () => ref
                      .read(filterProvider.notifier)
                      .toggle(birthdayThemeId),
                ),
              // 학사일정(NEIS) — 별도 카테고리. 데이터가 있을 때만 노출.
              if (ref.watch(academicScheduleProvider).isNotEmpty)
                CategoryFilterChip(
                  label: tr('학사일정'),
                  color: sh.academicColor,
                  selected: !hidden.contains(academicThemeId),
                  sh: sh,
                  onTap: () => ref
                      .read(filterProvider.notifier)
                      .toggle(academicThemeId),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 보기 옵션 ──
        SettingsSectionCard(
          sh: sh,
          title: tr('보기 옵션'),
          child: Column(
            children: [
              SettingsRow(
                sh: sh,
                iconColor: const Color(0xFFEC4899),
                icon: Icons.language_rounded,
                title: tr('언어'),
                trailing: _LanguagePill(
                    lang: ref.watch(localeProvider),
                    onSelected: (l) =>
                        ref.read(localeProvider.notifier).set(l),
                    sh: sh),
              ),
              SettingsRow(
                sh: sh,
                iconColor: const Color(0xFF8E8B98),
                icon: Icons.history_rounded,
                title: tr('지난 날 표시'),
                trailing: _IosSwitch(
                    value: settings.showPast,
                    onChanged: notifier.setShowPast,
                    sh: sh),
              ),
              Builder(builder: (_) {
                final en = ref.watch(eventNotifyProvider);
                final enNotifier = ref.read(eventNotifyProvider.notifier);
                final br = ref.watch(briefingNotifyProvider);
                final brNotifier = ref.read(briefingNotifyProvider.notifier);
                return Column(children: [
                  SettingsRow(
                    sh: sh,
                    iconColor: const Color(0xFFE8943A),
                    icon: Icons.notifications_outlined,
                    title: tr('일정 알림'),
                    trailing: _IosSwitch(
                        value: en.enabled,
                        onChanged: enNotifier.setEnabled,
                        sh: sh),
                  ),
                  if (en.enabled)
                    SettingsRow(
                      sh: sh,
                      icon: Icons.alarm_outlined,
                      title: tr('시작 전 알림'),
                      trailing: _LeadMinutesPill(
                          minutes: en.leadMinutes,
                          onSelected: enNotifier.setLeadMinutes,
                          sh: sh),
                    ),
                  SettingsRow(
                    sh: sh,
                    iconColor: const Color(0xFF0FB5AE),
                    icon: Icons.wb_sunny_outlined,
                    title: tr('오늘의 브리핑'),
                    trailing: _IosSwitch(
                        value: br.enabled,
                        onChanged: brNotifier.setEnabled,
                        sh: sh),
                  ),
                  if (br.enabled)
                    SettingsRow(
                      sh: sh,
                      icon: Icons.schedule_outlined,
                      title: tr('브리핑 시각'),
                      trailing: _HourPill(
                          hour: br.hour,
                          onSelected: brNotifier.setHour,
                          sh: sh),
                    ),
                ]);
              }),
              SettingsRow(
                sh: sh,
                iconColor: const Color(0xFF8B5CF6),
                icon: Icons.view_stream_outlined,
                title: tr('연속 보기'),
                trailing: _IosSwitch(
                    value: settings.continuousView,
                    onChanged: notifier.setContinuousView,
                    sh: sh),
              ),
              SettingsRow(
                sh: sh,
                iconColor: const Color(0xFF3B82F6),
                icon: Icons.calendar_today_outlined,
                title: tr('주 시작일'),
                trailing: _WeekStartPill(
                    dow: settings.weekStartDow,
                    onSelected: notifier.setWeekStart,
                    sh: sh),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.event_note_outlined,
                title: tr('빈 교시 라벨'),
                trailing: _EmptyLabelPill(
                    current: settings.timetableEmptyLabel,
                    onSelected: notifier.setTimetableEmptyLabel,
                    sh: sh),
              ),
              // 달력 한 칸 높이 — 0.8 ~ 1.4 슬라이더(1.0 기본).
              _MonthCellSizeRow(
                sh: sh,
                value: settings.monthCellHeightFactor,
                onChanged: notifier.setMonthCellHeightFactor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 더보기 ──
        SettingsSectionCard(
          sh: sh,
          title: tr('더보기'),
          child: Column(
            children: [
              SettingsRow(
                sh: sh,
                icon: Icons.menu_book_rounded,
                title: tr('사용법 안내'),
                onTap: () => showHowToGuide(context),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.tour_rounded,
                title: tr('화면 투어'),
                onTap: () {
                  final rootCtx =
                      Navigator.of(context, rootNavigator: true).context;
                  showCoachMarks(rootCtx);
                },
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.auto_awesome_rounded,
                title: tr('기능 둘러보기'),
                onTap: () => showFeatureIntro(context),
              ),
              if (showSchool)
                _SchoolRow(
                  sh: sh,
                  school: school,
                  onTap: () => showNeisSetupModal(context),
                ),
              SettingsRow(
                sh: sh,
                iconColor: const Color(0xFFEC4899),
                icon: Icons.cake_outlined,
                title: birthdays.isEmpty
                    ? tr('생일 챙기기')
                    : trf('생일 챙기기 ({0}명)', [birthdays.length]),
                onTap: () => showBirthdayManagerModal(context),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.privacy_tip_outlined,
                title: tr('개인정보 처리방침'),
                onTap: () => _openUrl(
                    'https://kev208dev.github.io/Surlap/privacy.html'),
              ),
              SettingsRow(
                sh: sh,
                icon: Icons.description_outlined,
                title: tr('이용약관'),
                onTap: () => _openUrl(
                    'https://kev208dev.github.io/Surlap/terms.html'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (ok) return;
    } catch (_) {}
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
  }
}

class SettingsSectionCard extends StatelessWidget {
  final SurlapColors sh;
  final String title;
  final Widget child;
  const SettingsSectionCard(
      {super.key, required this.sh, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 eyebrow — 대문자 트래킹으로 정체성 강화.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(title.toUpperCase(),
              style: AppType.eyebrow.copyWith(
                  fontSize: 11,
                  color: sh.ink.withValues(alpha: 0.45))),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: sh.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: sh.ink.withValues(alpha: 0.05)),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ─── 카테고리 칩 ─────────────────────────────────────────────────
class CategoryFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final SurlapColors sh;

  const CategoryFilterChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.sh,
  });

  @override
  Widget build(BuildContext context) {
    final brand = sh.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? brand.withValues(alpha: 0.10)
              : sh.ink.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? brand.withValues(alpha: 0.28) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 선택 표시는 채움/테두리/색으로만 — 체크 아이콘 제거(컴팩트).
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(label,
                style: AppType.labelMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? brand : sh.ink.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}

// ─── 달력 한 칸 크기 슬라이더 행 ──────────────────────────────────
class _MonthCellSizeRow extends StatelessWidget {
  final SurlapColors sh;
  final double value;
  final ValueChanged<double> onChanged;
  const _MonthCellSizeRow({
    required this.sh,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.height_rounded, size: 18, color: sh.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr('달력 한 칸 크기'),
                  style: AppType.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600, color: sh.ink)),
            ),
            Text('${(value * 100).round()}%',
                style: AppType.labelMedium
                    .copyWith(color: sh.inkSoft, fontWeight: FontWeight.w700)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: sh.accent,
              inactiveTrackColor: sh.ink.withValues(alpha: 0.08),
              thumbColor: sh.accent,
              overlayColor: sh.accent.withValues(alpha: 0.16),
            ),
            child: Slider(
              value: value,
              min: 0.8,
              max: 1.4,
              divisions: 12,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 설정 행 ─────────────────────────────────────────────────────
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final SurlapColors sh;
  /// 30×30 컬러 아이콘 타일 색. null이면 중성 회색.
  final Color? iconColor;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sh,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = iconColor;
    final iconFill = tileColor != null
        ? Colors.white
        : sh.ink.withValues(alpha: 0.62);
    final tileBg = tileColor ?? sh.ink.withValues(alpha: 0.05);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: sh.accent.withValues(alpha: 0.08),
        highlightColor: sh.accent.withValues(alpha: 0.04),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: [
                // 컬러 아이콘 타일 (30×30, radius 9, 흰 아이콘 18) — Apple Settings 감성.
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: iconFill),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: AppType.bodyLarge.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: sh.ink)),
                ),
                ?trailing,
                if (trailing == null && onTap != null)
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: sh.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── iOS 스타일 스위치 ───────────────────────────────────────────
class _IosSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final SurlapColors sh;
  const _IosSwitch(
      {required this.value, required this.onChanged, required this.sh});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.88,
      child: Switch.adaptive(
        value: value,
        activeThumbColor: sh.accent,
        activeTrackColor: sh.accent.withValues(alpha: 0.24),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: sh.ink.withValues(alpha: 0.10),
        onChanged: onChanged,
      ),
    );
  }
}

// ─── 내 유형 pill ────────────────────────────────────────────────
class _TypePill extends StatelessWidget {
  final UserType? type;
  final SurlapColors sh;
  final VoidCallback onTap;
  const _TypePill({required this.type, required this.sh, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = type;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sh.ink.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t != null) ...[
              Text(t.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(t?.label ?? tr('선택하기'),
                style: AppType.bodyLarge.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700, color: sh.ink)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: sh.ink.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}

// 유형 선택 바텀시트.
void _showTypePicker(BuildContext context, WidgetRef ref, UserType? current) {
  const order = [
    UserType.elementary,
    UserType.middle,
    UserType.high,
    UserType.university,
    UserType.general,
  ];
  final sh = context.sh;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: sh.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(tr('내 유형'),
              style: AppType.titleMedium.copyWith(
                  fontSize: 18, fontWeight: FontWeight.w800, color: sh.ink)),
          const SizedBox(height: 4),
          Text(tr('유형에 따라 급식·학교 연동 표시가 달라져요.'),
              style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
          const SizedBox(height: 12),
          ...order.map((t) {
            final sel = t == current;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(t.emoji, style: const TextStyle(fontSize: 22)),
              title: Text(t.label,
                  style: AppType.bodyLarge.copyWith(
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      color: sel ? sh.accentInk : sh.ink)),
              subtitle: Text(t.tagline,
                  style: AppType.labelMedium.copyWith(color: sh.inkSoft)),
              trailing: sel
                  ? Icon(Icons.check_circle_rounded, color: sh.accent, size: 20)
                  : null,
              onTap: () {
                ref.read(userTypeProvider.notifier).set(t);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    ),
  );
}

// ─── 학교 연결 행(로고/슬로건 표시) ────────────────────────────────
class _SchoolRow extends StatelessWidget {
  final SurlapColors sh;
  final NeisSchool? school;
  final VoidCallback onTap;
  const _SchoolRow({required this.sh, required this.school, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = school;
    if (s == null) {
      return SettingsRow(
        sh: sh,
        icon: Icons.school_outlined,
        title: tr('학교 연결 (NEIS)'),
        onTap: onTap,
      );
    }
    final logo = s.logoUrl;
    final sub = s.slogan.isNotEmpty
        ? s.slogan
        : '${tr(s.kind)} · ${trf('{0}학년 {1}반', [s.grade, s.classNm])}';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        child: Row(
          children: [
            SchoolLogo(
              name: s.name,
              logoUrl: logo,
              fallbackUrl: s.logoFallbackUrl,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyLarge.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: sh.ink)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelMedium.copyWith(
                          fontSize: 12, color: sh.inkSoft)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: sh.inkFaint),
          ],
        ),
      ),
    );
  }
}

// ─── 주 시작일 pill ──────────────────────────────────────────────
// ── 언어 선택 pill (국기 + 자기 언어 이름) ──
class _LanguagePill extends StatelessWidget {
  final AppLang lang;
  final ValueChanged<AppLang> onSelected;
  final SurlapColors sh;
  const _LanguagePill(
      {required this.lang, required this.onSelected, required this.sh});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLang>(
      onSelected: onSelected,
      color: sh.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final l in AppLang.values)
          PopupMenuItem(
            value: l,
            child: Row(children: [
              Text(l.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(l.nativeName,
                  style: AppType.bodyLarge.copyWith(
                      color: sh.ink,
                      fontWeight:
                          l == lang ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sh.ink.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(lang.nativeName,
                style: AppType.bodyLarge.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700, color: sh.ink)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: sh.ink.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}

class _WeekStartPill extends StatelessWidget {
  final int dow; // 0=일, 1=월, 6=토
  final ValueChanged<int> onSelected;
  final SurlapColors sh;
  const _WeekStartPill(
      {required this.dow, required this.onSelected, required this.sh});

  static const _labels = {1: '월요일', 0: '일요일', 6: '토요일'};

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: onSelected,
      color: sh.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final e in _labels.entries)
          PopupMenuItem(
            value: e.key,
            child: Text(tr(e.value),
                style: AppType.bodyLarge.copyWith(
                    color: sh.ink,
                    fontWeight:
                        e.key == dow ? FontWeight.w700 : FontWeight.w400)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sh.ink.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(_labels[dow] ?? '월요일'),
                style: AppType.bodyLarge.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700, color: sh.ink)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: sh.ink.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}

class _HourPill extends StatelessWidget {
  final int hour;
  final ValueChanged<int> onSelected;
  final SurlapColors sh;
  const _HourPill(
      {required this.hour, required this.onSelected, required this.sh});

  static const _opts = [6, 7, 8, 9, 10, 12, 18, 21];

  String _label(int h) => trf('{0}시', [h]);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: onSelected,
      color: sh.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final h in _opts)
          PopupMenuItem(
            value: h,
            child: Text(_label(h),
                style: AppType.bodyLarge.copyWith(
                    color: sh.ink,
                    fontWeight:
                        h == hour ? FontWeight.w700 : FontWeight.w400)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sh.ink.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_label(hour),
                style: AppType.bodyLarge.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700, color: sh.ink)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: sh.ink.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}

class _EmptyLabelPill extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelected;
  final SurlapColors sh;
  const _EmptyLabelPill(
      {required this.current, required this.onSelected, required this.sh});

  static const _opts = ['', '자습', '공강', '없음'];

  String _label(String v) => v.isEmpty ? tr('표시 안 함') : v;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: sh.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final v in _opts)
          PopupMenuItem(
            value: v,
            child: Text(_label(v),
                style: AppType.bodyLarge.copyWith(
                    color: sh.ink,
                    fontWeight:
                        v == current ? FontWeight.w700 : FontWeight.w400)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sh.ink.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_label(current),
                style: AppType.bodyLarge.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700, color: sh.ink)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: sh.ink.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}

class _LeadMinutesPill extends StatelessWidget {
  final int minutes; // 0/5/15/30/60
  final ValueChanged<int> onSelected;
  final SurlapColors sh;
  const _LeadMinutesPill(
      {required this.minutes, required this.onSelected, required this.sh});

  static const _opts = [0, 5, 15, 30, 60];

  String _label(int m) => m == 0 ? tr('정각') : trf('{0}분 전', [m]);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: onSelected,
      color: sh.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final m in _opts)
          PopupMenuItem(
            value: m,
            child: Text(_label(m),
                style: AppType.bodyLarge.copyWith(
                    color: sh.ink,
                    fontWeight:
                        m == minutes ? FontWeight.w700 : FontWeight.w400)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sh.ink.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_label(minutes),
                style: AppType.bodyLarge.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700, color: sh.ink)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: sh.ink.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}
