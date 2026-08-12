import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surlap/core/constants/color_presets.dart';
import 'package:surlap/core/theme/app_theme.dart';
import 'package:surlap/core/theme/design_tokens.dart';
import 'package:surlap/widgets/screen_header.dart';
import 'package:surlap/widgets/ui_kit.dart';

/// 디자인 시스템 정리 후, 공통 컴포넌트가 실제로 같은 규격을 내는지 지킨다.
///
/// 화면마다 헤더·아이콘 버튼·세그먼트를 다시 만들면서 제목 크기가 34/26/24 로
/// 갈리고 터치 영역이 kMinTouch 에 못 미치던 것을 되돌리지 않기 위한 회귀 테스트.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(kDefaultPreset),
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );
  await tester.pump();
}

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  group('SurlapScreenHeader', () {
    testWidgets('standard 제목은 화면마다 같은 타이포를 쓴다', (tester) async {
      await _pump(tester, const SurlapScreenHeader(title: '할 일'));
      final style = _styleOf(tester, '할 일');
      expect(style.fontSize, AppType.screenTitle.fontSize);
      expect(style.fontWeight, AppType.screenTitle.fontWeight);
    });

    testWidgets('여러 화면이 같은 크기로 렌더된다 — 26/24 로 갈리지 않는다',
        (tester) async {
      for (final title in ['할 일', '공유', '내 정보']) {
        await _pump(tester, SurlapScreenHeader(title: title));
        expect(_styleOf(tester, title).fontSize, 24);
      }
    });

    testWidgets('hero 는 큰 날짜 + 위 첨자를 유지한다', (tester) async {
      await _pump(
        tester,
        const SurlapScreenHeader.hero(eyebrow: '2026년 8월 12일 수요일', title: '8월 12일'),
      );
      expect(_styleOf(tester, '8월 12일').fontSize, AppType.heroTitle.fontSize);
      expect(find.text('2026년 8월 12일 수요일'), findsOneWidget);
    });

    testWidgets('액션 아이콘이 헤더 오른쪽에 붙는다', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        SurlapScreenHeader(
          title: '공유',
          actions: [
            SurlapIconButton(
              icon: Icons.search_rounded,
              tooltip: '검색',
              onTap: () => taps++,
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(Icons.search_rounded));
      expect(taps, 1);
    });
  });

  group('SurlapIconButton', () {
    testWidgets('터치 영역이 kMinTouch(44) 이상이다', (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SurlapIconButton(
            icon: Icons.add_rounded,
            tooltip: '추가',
            onTap: () {},
          ),
        ),
      );
      final size = tester.getSize(find.byType(SurlapIconButton));
      expect(size.width, greaterThanOrEqualTo(kMinTouch));
      expect(size.height, greaterThanOrEqualTo(kMinTouch));
    });

    testWidgets('아이콘만 있는 버튼이라 접근성 라벨이 반드시 붙는다', (tester) async {
      await _pump(
        tester,
        SurlapIconButton(
          icon: Icons.bolt_rounded,
          tooltip: '빠른 추가',
          onTap: () {},
        ),
      );
      final node = tester.getSemantics(find.byIcon(Icons.bolt_rounded));
      expect(node.label, '빠른 추가');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    });
  });

  group('SurlapSection', () {
    testWidgets('heading 은 17/700', (tester) async {
      await _pump(tester, const SurlapSection(title: '다가오는 일정'));
      final style = _styleOf(tester, '다가오는 일정');
      expect(style.fontSize, AppType.section.fontSize);
      expect(style.fontWeight, FontWeight.w700);
    });

    testWidgets('overline 은 작은 라벨 — 두 티어가 구분된다', (tester) async {
      await _pump(
        tester,
        const SurlapSection(
            title: '날짜 없는 할 일', style: SurlapSectionStyle.overline),
      );
      expect(_styleOf(tester, '날짜 없는 할 일').fontSize, AppType.label.fontSize);
    });

    testWidgets('첫 섹션은 위 여백을 줄인다', (tester) async {
      EdgeInsets padOf() => tester
          .widget<Padding>(find
              .descendant(
                  of: find.byType(SurlapSection), matching: find.byType(Padding))
              .first)
          .padding as EdgeInsets;

      await _pump(tester, const SurlapSection(title: 'A', first: true));
      final first = padOf();
      await _pump(tester, const SurlapSection(title: 'A'));
      final rest = padOf();
      expect(first.top, Gap.md);
      expect(rest.top, Gap.xl);
      expect(first.top, lessThan(rest.top));
    });
  });

  group('SurlapSegmentedControl', () {
    testWidgets('캘린더 4칸과 공유 2칸이 같은 높이를 쓴다', (tester) async {
      await _pump(
        tester,
        SurlapSegmentedControl(
          segments: [
            for (final l in ['연', '월', '3일', '하루']) surlapSegment(l),
          ],
          index: 1,
          onChanged: (_) {},
        ),
      );
      final four = tester.getSize(find.byType(SurlapSegmentedControl)).height;

      await _pump(
        tester,
        SurlapSegmentedControl(
          segments: [surlapSegment('내가 공유 중 0'), surlapSegment('구독 중 0')],
          index: 0,
          onChanged: (_) {},
        ),
      );
      final two = tester.getSize(find.byType(SurlapSegmentedControl)).height;

      expect(four, two);
      expect(four, kSegmentHeight);
    });

    testWidgets('칸을 누르면 그 index 가 올라온다', (tester) async {
      int? picked;
      await _pump(
        tester,
        SurlapSegmentedControl(
          segments: [surlapSegment('연'), surlapSegment('월')],
          index: 0,
          onChanged: (i) => picked = i,
        ),
      );
      await tester.tap(find.text('월'));
      expect(picked, 1);
    });

    testWidgets('선택 칸은 accent 채움 + bg 글자', (tester) async {
      await _pump(
        tester,
        SurlapSegmentedControl(
          segments: [surlapSegment('연'), surlapSegment('월')],
          index: 0,
          onChanged: (_) {},
        ),
      );
      const sh = SurlapColors(preset: kDefaultPreset);
      expect(_styleOf(tester, '연').color, sh.bg);
      expect(_styleOf(tester, '월').color, sh.ink);
    });
  });

  group('카드와 행', () {
    testWidgets('SurlapCard.list 는 내부 여백 0 — 행이 카드 끝까지 닿는다',
        (tester) async {
      await _pump(
        tester,
        const SurlapCard(list: true, child: SizedBox(height: 10)),
      );
      final container = tester.widget<Container>(
        find.descendant(
            of: find.byType(SurlapCard), matching: find.byType(Container)),
      );
      expect(container.padding, EdgeInsets.zero);
    });

    testWidgets('SurlapRow 는 공통 여백을 쓰고 마지막 행만 divider 가 없다',
        (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            SurlapRow(child: Text('첫 행')),
            SurlapRow(last: true, child: Text('끝 행')),
          ],
        ),
      );
      Container boxOf(String text) => tester.widget<Container>(
            find
                .ancestor(of: find.text(text), matching: find.byType(Container))
                .first,
          );
      expect(boxOf('첫 행').padding, kListRowPadding);
      expect(boxOf('끝 행').padding, kListRowPadding);
      expect((boxOf('첫 행').decoration! as BoxDecoration).border, isNotNull);
      expect((boxOf('끝 행').decoration! as BoxDecoration).border, isNull);
    });

    testWidgets('행 여백은 화면 좌우 패딩과 같은 Gap.lg', (tester) async {
      expect((kListRowPadding).left, Gap.lg);
      expect((kListRowPadding).right, Gap.lg);
    });
  });

  group('빈 상태와 고지', () {
    testWidgets('인라인 빈 상태는 한 컴포넌트로 통일된다', (tester) async {
      await _pump(tester, const SurlapInlineEmptyState('할 일이 없습니다.'));
      expect(find.text('할 일이 없습니다.'), findsOneWidget);
      expect(find.byType(SurlapEmptyState), findsNothing);
    });

    testWidgets('boxed notice 는 card2 박스를 쓴다', (tester) async {
      await _pump(tester, const SurlapNotice('안내', boxed: true));
      const sh = SurlapColors(preset: kDefaultPreset);
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text('안내'), matching: find.byType(Container))
            .last,
      );
      expect((box.decoration! as BoxDecoration).color, sh.card2);
    });
  });
}
