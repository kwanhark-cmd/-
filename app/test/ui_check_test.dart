import 'dart:io';

import 'package:channel_biseo/app/app.dart';
import 'package:channel_biseo/features/ai/brain.dart';
import 'package:channel_biseo/stages.dart';
import 'package:channel_biseo/ui/blog_screen.dart';
import 'package:channel_biseo/ui/calendar_screen.dart';
import 'package:channel_biseo/ui/common.dart' show BigButton;
import 'package:channel_biseo/ui/channels_screen.dart';
import 'package:channel_biseo/ui/corner_screen.dart';
import 'package:channel_biseo/ui/edits_screen.dart';
import 'package:channel_biseo/ui/memos_screen.dart';
import 'package:channel_biseo/ui/produce_screen.dart';
import 'package:channel_biseo/ui/theme.dart';
import 'package:channel_biseo/ui/tools_screen.dart';
import 'package:channel_biseo/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 화면 개선 검증: 대비, 가장 큰 글씨·가장 작은 화면·어두운 모드, 움직임 줄이기.
void main() {
  setUpAll(registerStages);

  group('글자와 바탕의 대비 (WCAG AAA 7:1 이상)', () {
    final themes = {
      '밝음': AppTokens.light(),
      '어두움': AppTokens.dark(),
      '고대비 밝음': AppTokens.contrast(darkMode: false),
      '고대비 어두움': AppTokens.contrast(darkMode: true),
    };
    themes.forEach((name, t) {
      test(name, () {
        final pairs = <String, (Color, Color)>{
          '본문/바탕': (t.text, t.background),
          '본문/카드': (t.text, t.card),
          '보조 글자/바탕': (t.textSoft, t.background),
          '보조 글자/카드': (t.textSoft, t.card),
          '강조 버튼': (t.onAccent, t.accent),
          '주요 버튼': (t.onPrimary, t.primary),
          '보조 버튼': (t.onTonal, t.tonal),
          '위험 버튼': (t.onDanger, t.danger),
          for (final s in Status.values) '상태 ${s.name}': (t.onStatusFor(s), t.statusColor(s)),
          '연습 모드 띠': (t.onStatusDark, t.warning),
          '눌린 강조 버튼': (t.onAccent, AppTokens.pressedBg(t.accent)),
          '눌린 주요 버튼': (t.onPrimary, AppTokens.pressedBg(t.primary)),
          '눌린 보조 버튼': (t.onTonal, AppTokens.pressedBg(t.tonal)),
          '눌린 위험 버튼': (t.onDanger, AppTokens.pressedBg(t.danger)),
        };
        pairs.forEach((label, p) {
          final r = contrastRatio(p.$1, p.$2);
          expect(r, greaterThanOrEqualTo(7), reason: '$name $label: ${r.toStringAsFixed(2)}');
        });
      });
    });
  });

  group('잘 보이는 버튼과 글자 (테마 전체)', () {
    final themes = <String, AppTokens>{
      for (final p in ColorTheme.values) ...{
        '밝음 ${p.name}': AppTokens.light().withPalette(p),
        '어두움 ${p.name}': AppTokens.dark().withPalette(p),
      },
      '고대비 밝음': AppTokens.contrast(darkMode: false),
      '고대비 어두움': AppTokens.contrast(darkMode: true),
    };
    const states = <String, Set<WidgetState>>{
      '보통': {},
      '눌림': {WidgetState.pressed},
      '마우스 올림': {WidgetState.hovered},
      '초점': {WidgetState.focused},
    };

    bool isRed(Color c) {
      final h = HSLColor.fromColor(c).hue;
      return h <= 15 || h >= 345;
    }

    themes.forEach((name, t) {
      final b = t.background.computeLuminance() < 0.2 ? Brightness.dark : Brightness.light;
      final theme = buildAppTheme(t, b);

      void checkButton(String label, ButtonStyle s, {required bool outlined}) {
        final r = '$name $label';
        expect(s.minimumSize!.resolve({})!.height, greaterThanOrEqualTo(52), reason: '$r 높이');
        expect(s.minimumSize!.resolve({})!.width, greaterThanOrEqualTo(48), reason: '$r 폭');
        final ts = s.textStyle!.resolve({})!;
        expect(ts.fontSize, greaterThanOrEqualTo(17), reason: '$r 글자 크기');
        expect(ts.fontWeight!.value, greaterThanOrEqualTo(FontWeight.w700.value), reason: '$r 굵기');
        expect(s.tapTargetSize ?? theme.materialTapTargetSize, MaterialTapTargetSize.padded);
        final normalBg = s.backgroundColor!.resolve({})!;
        final overlay = s.overlayColor?.resolve({WidgetState.pressed}) ?? Colors.transparent;
        expect(overlay.a, 0, reason: '$r 글자를 흐리게 하는 덮개 없음');
        states.forEach((sn, st) {
          final bg = s.backgroundColor!.resolve(st)!;
          final fg = s.foregroundColor!.resolve(st)!;
          final c = contrastRatio(bg, fg);
          expect(c, greaterThanOrEqualTo(7), reason: '$r $sn 대비 ${c.toStringAsFixed(2)}');
        });
        // 눌림: 바탕색이 바뀌어 보임
        expect(s.backgroundColor!.resolve({WidgetState.pressed}), isNot(normalBg), reason: '$r 눌림이 보임');
        // 초점: 굵은 둘레 선, 바탕과 대비 3:1 이상
        final focus = s.side!.resolve({WidgetState.focused})!;
        expect(focus.width, greaterThanOrEqualTo(3), reason: '$r 초점 선');
        expect(contrastRatio(focus.color, t.card), greaterThanOrEqualTo(3), reason: '$r 초점 선 색');
        if (outlined) {
          final side = s.side!.resolve({})!;
          expect(side.width, greaterThanOrEqualTo(2), reason: '$r 테두리 2px');
          for (final around in [t.background, t.card]) {
            expect(contrastRatio(side.color, around), greaterThanOrEqualTo(3), reason: '$r 테두리 색');
          }
          expect(s.side!.resolve({WidgetState.pressed})!.width, greaterThan(side.width), reason: '$r 눌림 선');
        }
      }

      test('$name: 버튼 높이 52 이상·글자 17 이상 굵게·대비 7:1 (눌림·초점 포함)·테두리 2px', () {
        checkButton('채운 버튼', theme.filledButtonTheme.style!, outlined: false);
        checkButton('테두리 버튼', theme.outlinedButtonTheme.style!, outlined: true);
        checkButton('글자 버튼', theme.textButtonTheme.style!, outlined: true);
        checkButton('위험 버튼', dangerButtonStyle(t), outlined: false);
        expect(isRed(t.danger), isTrue, reason: '$name 위험은 빨강');
        expect(dangerButtonStyle(t).backgroundColor!.resolve({}), t.danger);
        final icon = theme.iconButtonTheme.style!;
        expect(icon.minimumSize!.resolve({})!.shortestSide, greaterThanOrEqualTo(48), reason: '$name 아이콘 버튼');
        expect(icon.side!.resolve({WidgetState.focused})!.width, greaterThanOrEqualTo(3));
        expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
        expect(AppTokens.buttonHeight, greaterThanOrEqualTo(AppTokens.buttonMinHeight));
        expect(AppTokens.fontButton, greaterThanOrEqualTo(AppTokens.fontButtonMin));
      });

      test('$name: 본문 글자 16 이상, 바탕·카드와 대비 7:1 이상', () {
        final tt = theme.textTheme;
        for (final (label, st) in [
          ('bodyLarge', tt.bodyLarge),
          ('bodyMedium', tt.bodyMedium),
          ('bodySmall', tt.bodySmall),
          ('labelMedium', tt.labelMedium),
          ('labelSmall', tt.labelSmall),
          ('titleMedium', tt.titleMedium),
        ]) {
          expect(st!.fontSize, greaterThanOrEqualTo(16), reason: '$name $label 크기');
          for (final bg in [t.background, t.card]) {
            final c = contrastRatio(st.color!, bg);
            expect(c, greaterThanOrEqualTo(7), reason: '$name $label 대비 ${c.toStringAsFixed(2)}');
          }
        }
        expect(AppTokens.fontSmall, greaterThanOrEqualTo(16));
        for (final bg in [t.background, t.card]) {
          expect(contrastRatio(theme.colorScheme.onSurfaceVariant, bg), greaterThanOrEqualTo(7));
        }
      });
    });

    Future<void> pumpButtons(WidgetTester t, AppTokens tokens) async {
      final b = tokens.background.computeLuminance() < 0.2 ? Brightness.dark : Brightness.light;
      await t.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(tokens, b),
          home: Scaffold(
            body: Column(
              children: [
                BigButton(key: const Key('b-main'), label: '주요', onPressed: () {}),
                BigButton(key: const Key('b-sub'), label: '보조', primary: false, onPressed: () {}),
                BigButton(key: const Key('b-danger'), label: '삭제', danger: true, onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    ShapeBorder materialShape(WidgetTester t, String key) =>
        t.widget<Material>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Material)).first).shape!;

    for (final e in {
      '밝음': AppTokens.light(),
      '어두움': AppTokens.dark(),
      '고대비 밝음': AppTokens.contrast(darkMode: false),
      '고대비 어두움': AppTokens.contrast(darkMode: true),
      '바다 어두움': AppTokens.dark().withPalette(ColorTheme.ocean),
    }.entries) {
      testWidgets('공통 큰 버튼 (${e.key}): 높이 52 이상, 글자 17 이상 굵게, 보조는 2px 테두리, 위험은 빨강, 초점·눌림이 보임', (t) async {
        final tokens = e.value;
        await pumpButtons(t, tokens);
        for (final k in ['b-main', 'b-sub', 'b-danger']) {
          final size = t.getSize(find.byKey(Key(k)));
          expect(size.height, greaterThanOrEqualTo(52), reason: k);
          expect(size.width, greaterThanOrEqualTo(48), reason: k);
          final label = t.widget<Text>(find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text)));
          expect(label.style!.fontSize, greaterThanOrEqualTo(17));
          expect(label.style!.fontWeight!.value, greaterThanOrEqualTo(FontWeight.w700.value));
        }
        final sub = (materialShape(t, 'b-sub') as RoundedRectangleBorder).side;
        expect(sub.width, greaterThanOrEqualTo(2));
        expect(contrastRatio(sub.color, tokens.card), greaterThanOrEqualTo(3));
        final danger = t.widget<Material>(
          find.descendant(of: find.byKey(const Key('b-danger')), matching: find.byType(Material)).first,
        );
        expect(danger.color, tokens.danger);
        // 눌림: 덮는 색이 바탕을 글자에서 멀어지게 해 대비가 7:1 이상 그대로
        final ink = t.widget<InkWell>(
          find.descendant(of: find.byKey(const Key('b-main')), matching: find.byType(InkWell)),
        );
        final pressed = Color.alphaBlend(ink.overlayColor!.resolve({WidgetState.pressed})!, tokens.accent);
        expect(contrastRatio(pressed, tokens.onAccent), greaterThanOrEqualTo(7));
        expect(pressed, isNot(tokens.accent));
        final g = await t.startGesture(t.getCenter(find.byKey(const Key('b-sub'))));
        await t.pump(const Duration(milliseconds: 50));
        expect((materialShape(t, 'b-sub') as RoundedRectangleBorder).side.width, greaterThan(sub.width));
        await g.up();
        await t.pumpAndSettle();
        // 초점: 키보드(탭 키)로 고르면 굵은 둘레 선
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        final focus = (materialShape(t, 'b-main') as RoundedRectangleBorder).side;
        expect(focus.width, greaterThanOrEqualTo(3));
        expect(focus.color, tokens.focusRing);
        await t.pumpWidget(const SizedBox());
      });
    }
  });

  group('움직임 줄이기', () {
    test('켜면 모든 움직임 시간이 0', () {
      final t = AppTokens.light(reduceMotion: true);
      expect([t.fast, t.normal, t.slow, t.stagger], everyElement(Duration.zero));
      final on = AppTokens.light();
      expect(on.normal, greaterThan(Duration.zero));
      expect(on.normal.inMilliseconds, inInclusiveRange(200, 300)); // 화면 전환 200~300ms
    });

    Future<double?> firstFrameOpacity(WidgetTester t, bool reduce) async {
      await t.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppTokens.light(reduceMotion: reduce), Brightness.light),
          home: const Scaffold(body: Appear(index: 3, child: Text('항목'))),
        ),
      );
      final op = find.ancestor(of: find.text('항목'), matching: find.byType(Opacity));
      final v = op.evaluate().isEmpty ? null : t.widget<Opacity>(op.first).opacity;
      await t.pumpAndSettle();
      return v;
    }

    testWidgets('목록 나타나기 효과: 기본은 움직이고, 줄이기면 바로 보인다', (t) async {
      expect(await firstFrameOpacity(t, false), lessThan(1));
      final reduced = await firstFrameOpacity(t, true);
      expect(reduced == null || reduced == 1.0, isTrue); // 효과 없이 바로 그림
    });

    testWidgets('설정의 "움직임 줄이기" 를 켜면 앱 전체 테마에 반영', (t) async {
      final k = TestKit();
      final state = AppState(k.env);
      await state.login(k.env.accounts.create('a', '1234'));
      state.user!.settings.onboardingDone = true;
      await t.pumpWidget(ChannelBiseoApp(state: state));
      await t.pumpAndSettle();
      BuildContext ctx() => t.element(find.byType(NavigationBar));
      expect(ctx().tokens.reduceMotion, isFalse);
      state.setView(reduceMotion: true);
      await t.pumpAndSettle();
      expect(ctx().tokens.reduceMotion, isTrue);
      expect(ctx().tokens.normal, Duration.zero);
      expect(state.user!.settings.reduceMotion, isTrue);
      await t.pumpWidget(const SizedBox());
    });
  });

  // 가장 작은 화면(320×568) + 가장 큰 글씨 + 어두운 모드(그리고 고대비)에서 모든 화면을 끝까지 내려 보며 잘림 확인
  for (final (mode, width, height) in [('dark', 320.0, 568.0), ('contrast', 320.0, 568.0), ('light', 360.0, 640.0)]) {
    final label = switch (mode) {
      'dark' => '작은 화면(320) + 아주 큰 글씨 + 어두운 모드',
      'contrast' => '작은 화면(320) + 아주 큰 글씨 + 고대비 어두운 모드',
      _ => '휴대폰(360) + 아주 큰 글씨 + 밝은 모드 + 색 묶음 노을',
    };
    testWidgets('모든 화면 잘림 없음: $label', (t) async {
      t.view.physicalSize = Size(width * 2, height * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final k = TestKit();
      final state = AppState(k.env);
      await state.login(k.env.accounts.create('긴이름사용자님', '1234'));
      final u = state.user!;
      u.settings.onboardingDone = true;
      state.setTextScale(1.6);
      state.setView(themeMode: mode == 'light' ? 'light' : 'dark', highContrast: mode == 'contrast');
      if (mode == 'light') u.settings.colorTheme = 'sunset';
      // 자료 채우기
      await u.youtube.connectGoogle();
      await u.youtube.syncChannel('UC_mock_cook');
      await u.edits.apply(await u.edits.plan('UC_mock_cook'));
      final ps = productionOf(u);
      final p1 = await ps.create(
        channelId: 'UC_mock_cook',
        format: ContentFormat.long,
        topic: '아주 긴 주제 이름으로 만든 콘텐츠 제목 시험',
      );
      final v = File('${Directory.systemTemp.createTempSync('v').path}/a.mp4')..writeAsBytesSync([1]);
      ps.attachOwnVideo(p1.id, v.path);
      await ps.uploadPrivate(p1.id, userConfirmed: true, aiLabelMethod: 'setting');
      final site = blogOf(u).addTistory('내 티스토리 블로그', 'https://me.tistory.com');
      await blogOf(u).newPost(site.id, topic: '가을');
      final corner = cornerOf(u).create('사장님의 하루', 'UC_mock_cook');
      cornerOf(u).addText(corner.id, '오늘 가게 문을 열었어요.');
      u.memos.add('메모 하나');

      await t.pumpWidget(ChannelBiseoApp(state: state));
      await t.pumpAndSettle();

      Future<void> scrollAll(String where) async {
        final widgets = find.byType(Scrollable).evaluate().map((e) => e.widget as Scrollable).toList();
        for (final st in widgets) {
          if (st.axisDirection != AxisDirection.down) continue;
          final f = find.byWidget(st);
          if (f.evaluate().isEmpty) continue;
          await t.drag(f.first, const Offset(0, -4000), warnIfMissed: false);
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull, reason: where);
      }

      Future<void> push(Widget w, String where) async {
        final nav = t.state<NavigatorState>(find.byType(Navigator).first);
        // ignore: unawaited_futures
        nav.push(MaterialPageRoute<void>(builder: (_) => w));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '$where 열기');
        await scrollAll(where);
        nav.pop();
        await t.pumpAndSettle();
      }

      // 아래 메뉴 화면들
      final tabs = find.descendant(of: find.byType(NavigationBar), matching: find.byType(NavigationDestination));
      final n = tabs.evaluate().length;
      for (var i = 0; i < n; i++) {
        await t.tap(tabs.at(i));
        await t.pumpAndSettle();
        await scrollAll('메뉴 $i');
      }
      // 하위 화면들
      await push(ChannelDetailScreen(user: u, channelId: 'UC_mock_cook'), '채널 상세');
      await push(EditsScreen(user: u), '수정 내역');
      await push(ProductionDetailScreen(user: u, id: p1.id), '제작 상세');
      await push(ReviewScreen(user: u), '확인 대기');
      await push(BlogDetailScreen(user: u, siteId: site.id), '블로그 상세');
      await push(CornerDetailScreen(user: u, cornerId: corner.id), '코너 상세');
      await push(MemosScreen(user: u), '음성 메모');
      await push(ToolsScreen(user: u), '도구 연결');
      await push(CalendarScreen(user: u), '게시 달력');
      // 첫 실행 안내 4단계
      u.settings.onboardingDone = false;
      state.refresh();
      await t.pumpAndSettle();
      for (var step = 0; step < 4; step++) {
        await scrollAll('첫 실행 안내 ${step + 1}');
        if (step < 3) {
          await t.tap(find.byKey(const Key('wizard-next')));
          await t.pumpAndSettle();
        }
      }
      // 로그인 화면
      state.logout();
      await t.pumpAndSettle();
      await scrollAll('로그인');
      await t.pumpWidget(const SizedBox());
    });
  }
}
