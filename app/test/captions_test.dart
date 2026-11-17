import 'dart:io';
import 'dart:typed_data';

import 'package:channel_biseo/app/app.dart';
import 'package:channel_biseo/app/services.dart';
import 'package:channel_biseo/features/ai/brain.dart';
import 'package:channel_biseo/features/production/captions.dart';
import 'package:channel_biseo/features/production/production_service.dart';
import 'package:channel_biseo/stages.dart';
import 'package:channel_biseo/ui/common.dart';
import 'package:channel_biseo/ui/produce_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 대본으로 자막 만들기 → 고치기 → 비공개 업로드 때 함께 올리기.

/// 최소 MP4: ftyp + moov(mvhd). 길이 = duration / timescale.
File fakeMp4({int timescale = 1000, int duration = 12345, int version = 0}) {
  Uint8List box(String type, List<int> payload) {
    final b = ByteData(8 + payload.length)..setUint32(0, 8 + payload.length);
    for (var i = 0; i < 4; i++) {
      b.setUint8(4 + i, type.codeUnitAt(i));
    }
    final out = b.buffer.asUint8List();
    out.setRange(8, out.length, payload);
    return out;
  }

  final mvhd = ByteData(version == 1 ? 32 : 24);
  mvhd.setUint8(0, version);
  if (version == 1) {
    mvhd.setUint32(20, timescale);
    mvhd.setUint64(24, duration);
  } else {
    mvhd.setUint32(12, timescale);
    mvhd.setUint32(16, duration);
  }
  final bytes = [
    ...box('ftyp', 'isom0000'.codeUnits),
    ...box('free', List.filled(10, 0)),
    ...box('moov', box('mvhd', mvhd.buffer.asUint8List())),
  ];
  return File('${Directory.systemTemp.createTempSync('mp4').path}/v.mp4')..writeAsBytesSync(bytes);
}

const script = '''[장면 1: 냄비에 물을 붓는다]
나레이션: 오늘은 김치찌개를 끓여 볼게요. 묵은지가 있으면 훨씬 맛있어요!
(효과음: 보글보글)
장면 2: 돼지고기를 먼저 볶아 주세요. 기름이 나오면 김치를 넣고 함께 볶아요.
마지막으로 두부를 넣으면 끝이에요.''';

Future<(TestKit, UserContext, ProductionService, Production)> setup() async {
  registerStages();
  final k = TestKit();
  final s = AppState(k.env);
  await s.login(k.env.accounts.create('자막', '1234'));
  final u = s.user!;
  u.settings.onboardingDone = true;
  await u.youtube.connectGoogle();
  final ps = productionOf(u);
  final p = await ps.create(channelId: 'UC_mock_cook', format: ContentFormat.shorts, topic: '김치찌개');
  ps.updateText(p.id, script: script);
  return (k, u, ps, ps.byId(p.id)!);
}

void main() {
  group('자막 만들기', () {
    test('무대 지시·장면 머리·말하는 사람은 빼고, 한 줄 18자·두 줄까지', () {
      final parts = CaptionMaker.chunks(script);
      final all = parts.join(' ');
      expect(all, isNot(contains('장면')));
      expect(all, isNot(contains('효과음')));
      expect(all, isNot(contains('나레이션')));
      expect(all, contains('김치찌개를'));
      expect(all, contains('두부를'));
      for (final c in parts) {
        final lines = c.split('\n');
        expect(lines.length, lessThanOrEqualTo(2), reason: c);
        for (final l in lines) {
          expect(l.length, lessThanOrEqualTo(CaptionMaker.lineMax), reason: l);
        }
      }
      // 띄어쓰기 없는 아주 긴 낱말도 잘림
      expect(CaptionMaker.chunks('가' * 50).every((c) => c.split('\n').every((l) => l.length <= 18)), isTrue);
    });

    test('시간: 영상 길이에 딱 맞게, 겹치지 않게, 글자 수에 비례', () {
      final parts = ['짧다', '이건 훨씬 더 긴 자막 문장이에요'];
      final cues = CaptionMaker.timed(parts, const Duration(seconds: 10));
      expect(cues.first.start, Duration.zero);
      expect(cues.last.end, const Duration(seconds: 10));
      expect(cues[1].start, cues[0].end);
      expect(cues[1].end - cues[1].start, greaterThan(cues[0].end - cues[0].start));
      // 길이를 모르면 읽는 속도(초당 6.5자)
      final est = CaptionMaker.timed(['가나다라마바사아자차카타파'], null);
      expect(est.last.end.inMilliseconds, (13 / 6.5 * 1000).round());
    });

    test('SRT 쓰기·읽기, 틀린 형식은 거절', () {
      final cues = CaptionMaker.timed(['첫 줄', '둘째\n줄'], const Duration(milliseconds: 3723500));
      final srt = CaptionMaker.toSrt(cues);
      expect(srt, startsWith('1\n00:00:00,000 --> '));
      expect(srt, contains('--> 01:02:03,500\n둘째\n줄'));
      final back = CaptionMaker.parseSrt(srt);
      expect(back.map((c) => c.text), ['첫 줄', '둘째\n줄']);
      expect(() => CaptionMaker.parseSrt('아무 글'), throwsFormatException);
      expect(() => CaptionMaker.parseSrt('1\n00:00:05,000 --> 00:00:01,000\n거꾸로'), throwsFormatException);
      expect(() => CaptionMaker.parseSrt(''), throwsFormatException);
    });

    test('MP4 길이 읽기 (mvhd 0판·1판), 영상이 아니면 null', () {
      expect(CaptionMaker.mp4Duration(fakeMp4()), const Duration(milliseconds: 12345));
      expect(
        CaptionMaker.mp4Duration(fakeMp4(version: 1, timescale: 90000, duration: 90000 * 61)),
        const Duration(seconds: 61),
      );
      final txt = File('${Directory.systemTemp.createTempSync('x').path}/a.mp4')..writeAsStringSync('영상 아님');
      expect(CaptionMaker.mp4Duration(txt), isNull);
    });
  });

  group('제작 콘텐츠', () {
    test('영상이 없으면 읽는 속도로, 영상을 넣으면 영상 길이에 맞춤', () async {
      final (_, _, ps, p) = await setup();
      final a = ps.makeCaptions(p.id);
      expect(a.fromVideo, isFalse);
      ps.attachOwnVideo(p.id, fakeMp4(duration: 30000).path);
      final b = ps.makeCaptions(p.id);
      expect(b.fromVideo, isTrue);
      expect(CaptionMaker.parseSrt(b.srt).last.end, const Duration(seconds: 30));
      expect(ps.captionsText(p.id), b.srt);
    });

    test('대본이 비면 안내, 고친 자막이 틀리면 저장하지 않음', () async {
      final (_, _, ps, p) = await setup();
      ps.updateText(p.id, script: '[장면만 있음]');
      expect(() => ps.makeCaptions(p.id), throwsA(isA<ProductionBlocked>()));
      ps.updateText(p.id, script: script);
      final ok = ps.makeCaptions(p.id).srt;
      expect(() => ps.saveCaptions(p.id, '엉망'), throwsA(isA<ProductionBlocked>()));
      expect(ps.captionsText(p.id), ok);
      ps.saveCaptions(p.id, '1\n00:00:00,000 --> 00:00:02,000\n고쳤어요\n');
      expect(ps.captionsText(p.id), contains('고쳤어요'));
      ps.deleteCaptions(p.id);
      expect(ps.byId(p.id)!.hasCaptions, isFalse);
    });

    test('비공개로 올릴 때 자막도 함께 (사용량 400 더)', () async {
      final (k, u, ps, p) = await setup();
      ps.attachOwnVideo(p.id, fakeMp4().path);
      final srt = ps.makeCaptions(p.id).srt;
      final before = u.quota.used;
      await ps.uploadPrivate(p.id, userConfirmed: true, aiLabelMethod: 'setting');
      final done = ps.byId(p.id)!;
      expect(done.status, ProductionStatus.uploadedPrivate);
      expect(k.mockYt.captions[done.uploadedVideoId], srt);
      expect(done.extra['captionsUploaded'], isTrue);
      expect(u.quota.used - before, 1600 + 400);
    });

    test('자막만 실패하면 영상은 올라간 것으로, 안내만', () async {
      final (k, _, ps, p) = await setup();
      ps.attachOwnVideo(p.id, fakeMp4().path);
      ps.makeCaptions(p.id);
      k.mockYt.failCaption = true;
      expect(
        await ps.uploadPrivate(p.id, userConfirmed: true, aiLabelMethod: 'setting'),
        ProductionStatus.uploadedPrivate,
      );
      expect(ps.byId(p.id)!.extra['captionsUploaded'], isFalse);
    });

    test('자막이 없으면 자막 요청을 보내지 않음', () async {
      final (k, _, ps, p) = await setup();
      ps.attachOwnVideo(p.id, fakeMp4().path);
      await ps.uploadPrivate(p.id, userConfirmed: true, aiLabelMethod: 'setting');
      expect(k.mockYt.captions, isEmpty);
    });
  });

  testWidgets('화면: 만들기 → 고치기 → 저장', (t) async {
    t.view.physicalSize = const Size(390 * 2, 1800 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final (_, u, ps, p) = await setup();
    await t.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppTokens.light(), Brightness.light),
        home: ProductionDetailScreen(user: u, id: p.id),
      ),
    );
    await t.pumpAndSettle();
    final make = find.byKey(const Key('make-captions'));
    await t.scrollUntilVisible(make, 200, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(make);
    await t.pumpAndSettle();
    await t.tap(make);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('captions-text')), findsOneWidget);
    final text = ps.captionsText(p.id).replaceFirst('김치찌개를', '맛있는 김치찌개를');
    await t.enterText(find.byKey(const Key('captions-text')), text);
    await t.ensureVisible(find.byKey(const Key('save-captions')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('save-captions')));
    await t.pumpAndSettle();
    expect(ps.captionsText(p.id), contains('맛있는 김치찌개를'));
    await t.pumpWidget(const SizedBox());
  });
}
