import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../i18n/strings.dart';
import '../../widgets/mascot/mascot.dart';

/// 사용법 안내 — 풀스크린 가이드. 카테고리 + 펼침 카드 + 단계별 설명.
/// 검색으로 빠른 탐색을 지원한다.
Future<void> showHowToGuide(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => const HowToGuideScreen(),
        transitionsBuilder: (_, anim, _, child) {
          final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: t,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(t),
              child: child,
            ),
          );
        },
      ),
    );

class _Step {
  final String text;
  final String? tip;
  const _Step(this.text, {this.tip});
}

class _Topic {
  final IconData icon;
  final Color color;
  final String title;
  final String summary;
  final List<_Step> steps;
  const _Topic({
    required this.icon,
    required this.color,
    required this.title,
    required this.summary,
    required this.steps,
  });

  bool match(String q) {
    if (q.isEmpty) return true;
    final l = q.toLowerCase();
    if (title.toLowerCase().contains(l)) return true;
    if (summary.toLowerCase().contains(l)) return true;
    for (final s in steps) {
      if (s.text.toLowerCase().contains(l)) return true;
      if (s.tip != null && s.tip!.toLowerCase().contains(l)) return true;
    }
    return false;
  }
}

class _Category {
  final String label;
  final IconData icon;
  final List<_Topic> topics;
  const _Category(
      {required this.label, required this.icon, required this.topics});
}

List<_Category> _buildCategories() => [
      _Category(
        label: tr('시작하기'),
        icon: Icons.flag_rounded,
        topics: [
          _Topic(
            icon: Icons.touch_app_rounded,
            color: const Color(0xFF6B3DF9),
            title: tr('화면 구성 이해하기'),
            summary: tr('아래 둥근 바로 5개 화면을 오간다.'),
            steps: [
              _Step(tr('아래 둥근 바에서 꾸미기 · 일정 · 플래너 · 시간표 · 프로필을 누른다.')),
              _Step(tr('일정 화면 상단의 月·週·日 버튼으로 보기 모드를 바꾼다.')),
              _Step(tr('달력 날짜를 길게 누르면 일별 액션 시트가 열린다.'),
                  tip: tr('일정·할 일·위젯 추가, 자세히 보기를 한 번에 고른다.')),
              _Step(tr('우상단 톱니바퀴는 보기 옵션과 카테고리 필터다.'),
                  tip: tr('카테고리를 끄면 해당 색 일정이 화면에서 숨겨진다.')),
            ],
          ),
          _Topic(
            icon: Icons.login_rounded,
            color: const Color(0xFF4F8DFD),
            title: tr('로그인과 클라우드 동기화'),
            summary: tr('로그인하면 데이터가 여러 기기에서 동기화된다.'),
            steps: [
              _Step(tr('프로필 화면에서 [로그인]을 누른다.')),
              _Step(tr('Apple · Google · 이메일 중 하나를 선택한다.')),
              _Step(tr('로그인 후 자동으로 모든 일정·할 일·기록이 동기화된다.'),
                  tip: tr('로그인 안 해도 모든 기능을 게스트로 사용할 수 있다.')),
            ],
          ),
        ],
      ),
      _Category(
        label: tr('일정 · 할 일'),
        icon: Icons.event_note_rounded,
        topics: [
          _Topic(
            icon: Icons.touch_app_rounded,
            color: const Color(0xFFE8943A),
            title: tr('달력 날짜를 길게 눌러보기'),
            summary: tr('이 한 가지만 알면 대부분의 동작이 풀린다.'),
            steps: [
              _Step(tr('월/주 보기에서 원하는 날짜를 1초 정도 꾹 누른다.')),
              _Step(
                  tr('일별 액션 시트가 열린다 — 일정 추가 · 할 일 추가 · 위젯 추가 · 이날 자세히 보기.')),
              _Step(tr('해당 날짜에 등록된 일정·할 일 목록도 같이 표시된다.'),
                  tip: tr('짧게 탭하면 해당 날짜로 선택만 되고, 길게 누르면 액션 시트가 뜬다.')),
            ],
          ),
          _Topic(
            icon: Icons.add_circle_outline_rounded,
            color: const Color(0xFF6B3DF9),
            title: tr('일정 추가하기'),
            summary: tr('두 가지 방법 — 빠른 입력 또는 직접 작성.'),
            steps: [
              _Step(tr('일정 화면 우하단 [+] 버튼을 누른다.')),
              _Step(tr('또는 달력 날짜를 길게 눌러 [일정 추가]를 고른다.')),
              _Step(tr('제목·날짜·시간·카테고리·메모를 채운다.')),
              _Step(
                tr('빠른 입력란에 "내일 3시 영어학원" 처럼 자연어로 적으면 자동 분석된다.'),
                tip: tr('"매주 월요일 7시 운동" 같은 반복 일정도 인식한다.'),
              ),
            ],
          ),
          _Topic(
            icon: Icons.swipe_rounded,
            color: const Color(0xFF14B8C4),
            title: tr('일정·할 일 빠르게 수정·삭제'),
            summary: tr('일정 칩을 길게 누르거나 옆으로 밀기.'),
            steps: [
              _Step(tr('월/주 보기의 일정 칩을 길게 누르면 옮기기·삭제 메뉴.')),
              _Step(tr('일별 시트의 할 일은 좌우로 밀어 삭제할 수 있다.')),
              _Step(tr('일정 상세에서 우상단 메뉴로 복제·반복 변환도 가능하다.')),
            ],
          ),
          _Topic(
            icon: Icons.repeat_rounded,
            color: const Color(0xFFEC6AA8),
            title: tr('반복 일정 만들기'),
            summary: tr('매일·매주·매월·매년 RRULE 기반.'),
            steps: [
              _Step(tr('일정 추가 화면에서 [반복]을 켠다.')),
              _Step(tr('빈도·간격·종료일 또는 횟수를 지정한다.')),
              _Step(tr('생성된 반복 일정은 한 회차만 수정하거나 전체 시리즈를 수정할 수 있다.'),
                  tip: tr('수정 시 "이 일정만" / "이후 모두" / "전체 시리즈"를 선택한다.')),
            ],
          ),
          _Topic(
            icon: Icons.drag_indicator_rounded,
            color: const Color(0xFF35B97A),
            title: tr('드래그로 이동·길이 조정'),
            summary: tr('주·일 보기에서 길게 눌러 옮긴다.'),
            steps: [
              _Step(tr('주·일 보기에서 일정을 길게 눌러 다른 시간으로 끌어 옮긴다.')),
              _Step(tr('일정 아래 모서리를 잡아 끌면 길이가 늘어난다.')),
              _Step(tr('이동·길이 조정 결과는 즉시 저장된다.')),
            ],
          ),
          _Topic(
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF14B8C4),
            title: tr('할 일(투두) 관리'),
            summary: tr('일정과 따로 일별 체크리스트.'),
            steps: [
              _Step(tr('플래너 화면 또는 일별 액션 시트에서 할 일을 추가한다.')),
              _Step(tr('체크박스를 눌러 완료 표시. 음성 입력으로도 추가할 수 있다.')),
              _Step(tr('미완료 할 일은 다음 날로 자동 이월되지 않는다 — 의도된 동작이다.')),
            ],
          ),
        ],
      ),
      _Category(
        label: tr('시간표 · 학교'),
        icon: Icons.school_rounded,
        topics: [
          _Topic(
            icon: Icons.account_tree_rounded,
            color: const Color(0xFF6B3DF9),
            title: tr('NEIS 학교 연결'),
            summary: tr('학교를 연결하면 시간표·급식·학사일정이 자동 채워진다.'),
            steps: [
              _Step(tr('프로필 · 또는 설정에서 [학교 연결]을 누른다.')),
              _Step(tr('학교 이름을 검색하고 학년·반을 선택한다.')),
              _Step(tr('시간표 화면이 자동으로 채워지고, 일정에 학사일정이 표시된다.'),
                  tip: tr('학교 정보는 변경하거나 해제할 수 있다.')),
            ],
          ),
          _Topic(
            icon: Icons.edit_calendar_rounded,
            color: const Color(0xFF4F8DFD),
            title: tr('시간표 직접 편집'),
            summary: tr('NEIS 자동 채움 위에 덮어쓸 수 있다.'),
            steps: [
              _Step(tr('시간표 화면에서 빈 칸을 눌러 과목·색을 지정한다.')),
              _Step(tr('교시 시간을 바꾸려면 우상단 옵션에서 [교시 시간]을 연다.')),
              _Step(tr('빈 교시 라벨(이동/자율/공강)을 설정에서 바꿀 수 있다.')),
            ],
          ),
          _Topic(
            icon: Icons.restaurant_rounded,
            color: const Color(0xFFE8943A),
            title: tr('급식 메뉴 확인'),
            summary: tr('NEIS 연결 시 일별 급식이 자동 표시.'),
            steps: [
              _Step(tr('시간표 또는 일정 상세에서 급식 메뉴를 확인한다.')),
              _Step(tr('주말·방학에는 표시되지 않는다.')),
            ],
          ),
        ],
      ),
      _Category(
        label: tr('기록 · 트래커'),
        icon: Icons.insights_rounded,
        topics: [
          _Topic(
            icon: Icons.note_add_rounded,
            color: const Color(0xFF6B3DF9),
            title: tr('기록 템플릿 만들기'),
            summary: tr('공부·운동·독서 시간을 측정 단위로 정의.'),
            steps: [
              _Step(tr('플래너 또는 일별 액션 시트에서 [기록 추가]를 누른다.')),
              _Step(tr('템플릿(공부/운동/독서 등)을 선택하거나 새로 만든다.')),
              _Step(tr('단위(시간·페이지·횟수)와 이모지·색을 지정한다.'),
                  tip: tr('템플릿은 여러 일정 카테고리에 묶어 한 번에 통계낼 수 있다.')),
            ],
          ),
          _Topic(
            icon: Icons.timer_rounded,
            color: const Color(0xFF35B97A),
            title: tr('하루 기록 입력'),
            summary: tr('값과 메모를 적어 달력 셀에 즉시 반영.'),
            steps: [
              _Step(tr('해당 날짜를 눌러 [기록]을 선택한다.')),
              _Step(tr('템플릿을 골라 값을 입력한다 — 시간·페이지·횟수 등.')),
              _Step(tr('달력 셀에 이모지와 숫자로 한눈에 보이게 된다.')),
            ],
          ),
        ],
      ),
      _Category(
        label: tr('생일 · 알림'),
        icon: Icons.notifications_active_rounded,
        topics: [
          _Topic(
            icon: Icons.cake_rounded,
            color: const Color(0xFFEC4899),
            title: tr('생일 등록과 미리 알림'),
            summary: tr('당일 · 1·3·7일 전 · 1달 전까지 선택 가능.'),
            steps: [
              _Step(tr('설정 · 더보기 · [생일 챙기기]를 연다.')),
              _Step(tr('[직접 추가] 카드에서 이름과 생일을 입력하고 [추가]를 누른다.')),
              _Step(tr('상단에서 [생일 알림]을 켜고 미리 알림 시점을 고른다.'),
                  tip: tr('연도 포함 체크 해제 시 나이는 표시되지 않는다.')),
              _Step(tr('알림은 매년 자동으로 반복된다.')),
            ],
          ),
          _Topic(
            icon: Icons.alarm_rounded,
            color: const Color(0xFF4F8DFD),
            title: tr('일정 알림 시간 설정'),
            summary: tr('일정마다 다중 알림 가능.'),
            steps: [
              _Step(tr('일정 작성 시 [알림] 항목에서 N분/시간/일 전을 선택한다.')),
              _Step(tr('여러 개의 사전 알림을 동시에 걸 수 있다.')),
              _Step(tr('처음 한 번 시스템 알림 권한을 허용해야 한다.')),
            ],
          ),
          _Topic(
            icon: Icons.coffee_rounded,
            color: const Color(0xFFE8943A),
            title: tr('아침 브리핑 받기'),
            summary: tr('오늘의 일정·할 일 요약을 정해진 시각에 알림으로 받는다.'),
            steps: [
              _Step(tr('설정 · 알림에서 [아침 브리핑]을 켠다.')),
              _Step(tr('시각을 지정한다 — 기본은 오전 7시.')),
              _Step(tr('충돌(겹친 일정)이 있으면 함께 알려준다.')),
            ],
          ),
        ],
      ),
      _Category(
        label: tr('공유 · 테마'),
        icon: Icons.ios_share_rounded,
        topics: [
          _Topic(
            icon: Icons.share_rounded,
            color: const Color(0xFF4F8DFD),
            title: tr('공유 코드로 일정 나누기'),
            summary: tr('상대는 읽기 전용으로 받아본다.'),
            steps: [
              _Step(tr('일정 카테고리에서 [공유]를 눌러 6자리 코드를 만든다.')),
              _Step(tr('상대에게 코드를 전달하면 구독해서 본다.')),
              _Step(tr('내가 추가·수정하면 구독자에게 실시간으로 반영된다.'),
                  tip: tr('공유는 언제든 해제할 수 있고, 구독자도 직접 해제할 수 있다.')),
            ],
          ),
          _Topic(
            icon: Icons.palette_rounded,
            color: const Color(0xFF6B3DF9),
            title: tr('테마 · 색 프리셋 바꾸기'),
            summary: tr('밝게 / 어둡게 / 색상 프리셋 선택.'),
            steps: [
              _Step(tr('설정 · 테마에서 라이트/다크/시스템을 고른다.')),
              _Step(tr('색 프리셋을 골라 액센트 색을 바꾼다.')),
              _Step(tr('테마는 코드로 받아 친구와 공유할 수 있다.')),
            ],
          ),
        ],
      ),
      _Category(
        label: tr('위젯 · 내보내기'),
        icon: Icons.widgets_rounded,
        topics: [
          _Topic(
            icon: Icons.dashboard_customize_rounded,
            color: const Color(0xFF35B97A),
            title: tr('홈 위젯 설치'),
            summary: tr('홈 화면에 오늘 · 이번 주를 띄운다.'),
            steps: [
              _Step(tr('홈 화면을 길게 눌러 위젯 추가 화면을 연다.')),
              _Step(tr('Surlap을 검색해 원하는 크기를 선택한다.')),
              _Step(tr('데이터는 자동으로 동기화된다.'),
                  tip: tr('일정·할 일 변경 후 즉시 위젯에도 반영된다.')),
            ],
          ),
          _Topic(
            icon: Icons.file_download_rounded,
            color: const Color(0xFF4F8DFD),
            title: tr('iCal로 내보내기'),
            summary: tr('다른 캘린더 앱으로 옮기기.'),
            steps: [
              _Step(tr('프로필 · 백업에서 [iCal 내보내기]를 누른다.')),
              _Step(tr('범위를 지정하고 .ics 파일을 저장·공유한다.')),
              _Step(tr('Google · Apple 캘린더 등에 그대로 불러올 수 있다.')),
            ],
          ),
          _Topic(
            icon: Icons.backup_rounded,
            color: const Color(0xFFE8943A),
            title: tr('전체 백업 · 복원'),
            summary: tr('JSON으로 통째 저장 / 불러오기.'),
            steps: [
              _Step(tr('프로필 · 백업에서 [전체 백업]을 누른다.')),
              _Step(tr('파일을 안전한 위치에 저장한다.')),
              _Step(tr('복원 시 같은 화면에서 [복원]을 누르고 파일을 선택한다.'),
                  tip: tr('복원은 기존 데이터를 덮어쓰니 주의.')),
            ],
          ),
        ],
      ),
      _Category(
        label: tr('자주 묻는 질문'),
        icon: Icons.help_outline_rounded,
        topics: [
          _Topic(
            icon: Icons.delete_forever_rounded,
            color: const Color(0xFFD9614E),
            title: tr('계정 · 데이터 삭제하기'),
            summary: tr('회원 탈퇴 시 클라우드 데이터는 영구 삭제된다.'),
            steps: [
              _Step(tr('프로필 · 계정 · [회원 탈퇴]를 누른다.')),
              _Step(tr('확인 절차 후 즉시 모든 클라우드 데이터가 삭제된다.')),
              _Step(tr('게스트는 앱 삭제 시 기기 내 데이터도 함께 사라진다.')),
            ],
          ),
          _Topic(
            icon: Icons.lock_outline_rounded,
            color: const Color(0xFF6B6B76),
            title: tr('개인정보는 어떻게 보호되나요?'),
            summary: tr('광고 식별자·제3자 추적 사용 안 함.'),
            steps: [
              _Step(tr('IDFA / 광고 SDK를 사용하지 않는다.')),
              _Step(tr('클라우드 데이터는 행 수준 보안(RLS)으로 본인만 접근 가능하다.')),
              _Step(tr('자세한 사항은 설정 · 개인정보 처리방침에서 확인할 수 있다.')),
            ],
          ),
          _Topic(
            icon: Icons.mail_outline_rounded,
            color: const Color(0xFF4F8DFD),
            title: tr('문의 · 피드백 보내기'),
            summary: tr('이메일로 직접 닿아주세요.'),
            steps: [
              _Step(tr('설정 화면 가장 아래의 연락처를 누른다.')),
              _Step(tr('또는 kev208dev@gmail.com 으로 메일을 보낸다.')),
            ],
          ),
        ],
      ),
    ];

class HowToGuideScreen extends StatefulWidget {
  const HowToGuideScreen({super.key});

  @override
  State<HowToGuideScreen> createState() => _HowToGuideScreenState();
}

class _HowToGuideScreenState extends State<HowToGuideScreen> {
  late final List<_Category> _all = _buildCategories();
  final _searchCtrl = TextEditingController();
  String _q = '';
  int _cat = 0;
  final Set<String> _open = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Topic> get _filteredTopics {
    final cat = _all[_cat];
    if (_q.isEmpty) return cat.topics;
    return cat.topics.where((t) => t.match(_q)).toList();
  }

  List<_MatchedTopic> get _globalMatches {
    if (_q.isEmpty) return const [];
    final out = <_MatchedTopic>[];
    for (final c in _all) {
      for (final t in c.topics) {
        if (t.match(_q)) out.add(_MatchedTopic(c, t));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final searching = _q.isNotEmpty;

    return Scaffold(
      backgroundColor: sh.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(sh: sh),
            _SearchField(
              sh: sh,
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            if (!searching) _CategoryTabs(
              sh: sh,
              cats: _all,
              current: _cat,
              onSelect: (i) => setState(() => _cat = i),
            ),
            Expanded(
              child: searching ? _buildSearchResults(sh) : _buildCategoryBody(sh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBody(SurlapColors sh) {
    final topics = _filteredTopics;
    if (topics.isEmpty) return _EmptyHint(sh: sh);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 6, Gap.lg, Gap.xl),
      itemCount: topics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final t = topics[i];
        return _TopicCard(
          sh: sh,
          topic: t,
          expanded: _open.contains(t.title),
          onTap: () => setState(() {
            if (!_open.add(t.title)) _open.remove(t.title);
          }),
        );
      },
    );
  }

  Widget _buildSearchResults(SurlapColors sh) {
    final matches = _globalMatches;
    if (matches.isEmpty) return _EmptyHint(sh: sh);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 6, Gap.lg, Gap.xl),
      itemCount: matches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = matches[i];
        return _TopicCard(
          sh: sh,
          topic: m.topic,
          expanded: _open.contains(m.topic.title),
          categoryLabel: m.cat.label,
          onTap: () => setState(() {
            if (!_open.add(m.topic.title)) _open.remove(m.topic.title);
          }),
        );
      },
    );
  }
}

class _MatchedTopic {
  final _Category cat;
  final _Topic topic;
  const _MatchedTopic(this.cat, this.topic);
}

class _Header extends StatelessWidget {
  final SurlapColors sh;
  const _Header({required this.sh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 8, Gap.sm, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('사용법 안내'),
                    style: AppType.titleLarge.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: sh.ink)),
                const SizedBox(height: 2),
                Text(tr('찾는 기능을 검색하거나 카테고리에서 골라보세요.'),
                    style: AppType.labelMedium.copyWith(color: sh.inkSoft)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, color: sh.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final SurlapColors sh;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.sh, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 6, Gap.lg, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: sh.card2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sh.ink.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: sh.inkFaint, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: AppType.bodyLarge.copyWith(color: sh.ink, fontSize: 15),
                decoration: InputDecoration(
                  hintText: tr('생일 알림, 반복 일정, 위젯…'),
                  hintStyle: TextStyle(color: sh.inkFaint, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Icon(Icons.cancel_rounded,
                    color: sh.inkFaint, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final SurlapColors sh;
  final List<_Category> cats;
  final int current;
  final ValueChanged<int> onSelect;
  const _CategoryTabs({
    required this.sh,
    required this.cats,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 4),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = cats[i];
          final on = i == current;
          return GestureDetector(
            onTap: () => onSelect(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: on ? sh.accent : sh.card2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: on ? sh.accent : sh.ink.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Icon(c.icon,
                      size: 15, color: on ? Colors.white : sh.inkSoft),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: AppType.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : sh.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final SurlapColors sh;
  final _Topic topic;
  final bool expanded;
  final VoidCallback onTap;
  final String? categoryLabel;
  const _TopicCard({
    required this.sh,
    required this.topic,
    required this.expanded,
    required this.onTap,
    this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: sh.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: expanded
                    ? topic.color.withValues(alpha: 0.45)
                    : sh.ink.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: topic.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(topic.icon, size: 20, color: topic.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (categoryLabel != null)
                          Text(categoryLabel!,
                              style: AppType.bodySmall.copyWith(
                                  color: topic.color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5)),
                        Text(topic.title,
                            style: AppType.bodyLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                color: sh.ink,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(topic.summary,
                            style: AppType.bodySmall.copyWith(color: sh.inkSoft)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: expanded ? 0.5 : 0,
                    child: Icon(Icons.expand_more_rounded, color: sh.inkSoft),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12, left: 2, right: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < topic.steps.length; i++)
                        _StepRow(
                            sh: sh,
                            color: topic.color,
                            n: i + 1,
                            step: topic.steps[i]),
                    ],
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

class _StepRow extends StatelessWidget {
  final SurlapColors sh;
  final Color color;
  final int n;
  final _Step step;
  const _StepRow(
      {required this.sh, required this.color, required this.n, required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('$n',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(step.text,
                    style: AppType.bodyLarge
                        .copyWith(color: sh.ink, fontSize: 14, height: 1.5)),
              ),
            ],
          ),
          if (step.tip != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(step.tip!,
                          style: AppType.bodySmall.copyWith(
                              color: sh.inkSoft, height: 1.45, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final SurlapColors sh;
  const _EmptyHint({required this.sh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotView(
                expression: MascotExpression.thinking, size: 96),
            const SizedBox(height: 16),
            Text(tr('찾는 내용이 없어요'),
                style: AppType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800, color: sh.ink)),
            const SizedBox(height: 6),
            Text(tr('다른 단어로 검색해 보세요.'),
                style: AppType.labelMedium.copyWith(color: sh.inkSoft)),
          ],
        ),
      ),
    );
  }
}
