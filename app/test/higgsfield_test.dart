import 'dart:convert';
import 'dart:io';

import 'package:channel_biseo/app/app.dart';
import 'package:channel_biseo/app/services.dart';
import 'package:channel_biseo/core/failure.dart';
import 'package:channel_biseo/features/ai/brain.dart';
import 'package:channel_biseo/features/production/production_service.dart';
import 'package:channel_biseo/features/tools/tools_service.dart';
import 'package:channel_biseo/stages.dart';
import 'package:channel_biseo/core/retry.dart';
import 'package:channel_biseo/ui/produce_screen.dart';
import 'package:channel_biseo/ui/tools_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

/// 힉스필드 공식 API 흉내 (공식 SDK higgsfield-client·higgsfield-js 와 같은 형식).
class FakeHiggsfield {
  final requests = <http.Request>[];
  final statuses = <String>['queued', 'in_progress', 'completed'];
  int submitCode = 200;
  int cancels = 0;

  late final client = MockClient((req) async {
    requests.add(req);
    final path = req.url.path;
    if (req.url.host == 'upload.example') {
      return http.Response('', 200); // 미리 받은 올리기 주소에 PUT
    }
    if (req.url.host == 'cdn.example') {
      return http.Response.bytes([0, 0, 0, 24, 102, 116, 121, 112], 200); // 영상 파일
    }
    expect(req.url.host, 'api.higgsfield.ai');
    expect(req.headers['authorization'], 'Key kid:ksecret');
    if (path == '/files/generate-upload-url') {
      return http.Response(
        jsonEncode({
          'upload_url': 'https://upload.example/put/abc',
          'public_url': 'https://cdn.example/img/abc.png',
          'upload_headers': {'x-amz-acl': 'public-read'},
        }),
        200,
      );
    }
    if (path == '/v1/image2video/dop') {
      if (submitCode != 200) return http.Response('{"detail":"Not enough credits"}', submitCode);
      return http.Response(
        jsonEncode({
          'status': 'queued',
          'request_id': 'req-1',
          'status_url': 'https://api.higgsfield.ai/requests/req-1/status',
          'cancel_url': 'https://api.higgsfield.ai/requests/req-1/cancel',
        }),
        200,
      );
    }
    if (path == '/requests/req-1/status') {
      final s = statuses.length > 1 ? statuses.removeAt(0) : statuses.first;
      return http.Response(
        jsonEncode({
          'status': s,
          'request_id': 'req-1',
          if (s == 'completed') 'video': {'url': 'https://cdn.example/video/req-1.mp4'},
        }),
        200,
      );
    }
    if (path == '/requests/req-1/cancel') {
      cancels++;
      return http.Response('', 202);
    }
    return http.Response('not found', 404);
  });
}

Future<(TestKit, UserContext, FakeHiggsfield, ProductionService, Production)> setup() async {
  registerStages();
  final hf = FakeHiggsfield();
  final k = TestKit(client: hf.client);
  final state = AppState(k.env);
  await state.login(k.env.accounts.create('힉스', '1234'));
  final u = state.user!;
  await u.youtube.connectGoogle();
  await u.tools.connectHiggsfield('kid:ksecret');
  final ps = productionOf(u);
  final pr = await ps.create(channelId: 'UC_mock_cook', format: ContentFormat.shorts, topic: '김치찌개');
  return (k, u, hf, ps, pr);
}

Future<void> thumb(ProductionService ps, int id) => ps.makeThumbnail(id, (text, seed) async => [137, 80, 78, 71]);

void main() {
  test('키는 "키 ID:비밀 값" 모양만', () {
    expect(HiggsfieldGenerator.validKey('kid:ksecret'), isTrue);
    expect(HiggsfieldGenerator.validKey('onlyone'), isFalse);
    expect(HiggsfieldGenerator.validKey(':s'), isFalse);
    expect(HiggsfieldGenerator.validKey('k:'), isFalse);
  });

  test('승인하면: 썸네일 올리기 → 그림→영상 요청 → 기다리기 → 영상 받기', () async {
    final (k, u, hf, ps, pr) = await setup();
    await thumb(ps, pr.id);
    final fast = ps..pollDelay = Duration.zero;
    final q = await fast.higgsfieldQuote(pr.id);
    expect(q.left, isNull); // 잔액 API 없음 → 웹사이트에서 확인
    await fast.generateWithHiggsfield(pr.id, userApproved: true);
    final submit = hf.requests.firstWhere((r) => r.url.path == '/v1/image2video/dop');
    final body = jsonDecode(submit.body) as Map<String, dynamic>;
    expect(body['model'], 'dop-lite');
    expect(body['prompt'], contains('김치찌개'));
    expect((body['input_images'] as List).single, {
      'type': 'image_url',
      'image_url': 'https://cdn.example/img/abc.png',
    });
    final put = hf.requests.firstWhere((r) => r.url.host == 'upload.example');
    expect(put.method, 'PUT');
    expect(put.headers['x-amz-acl'], 'public-read');
    expect(put.bodyBytes, [137, 80, 78, 71]);
    // 만들기 요청은 한 번만 (크레딧이 드는 요청은 다시 보내지 않음)
    expect(hf.requests.where((r) => r.url.path == '/v1/image2video/dop').length, 1);
    final done = ps.byId(pr.id)!;
    expect(done.videoSource, 'higgsfield');
    expect(File(done.videoPath).lengthSync(), 8);
    // 키가 로그에 남지 않음
    expect(k.logger.recentLines().join('\n'), isNot(contains('ksecret')));
    u.close();
  });

  test('승인 없이는 아무 요청도 보내지 않음', () async {
    final (_, _, hf, ps, pr) = await setup();
    await thumb(ps, pr.id);
    await expectLater(ps.generateWithHiggsfield(pr.id, userApproved: false), throwsA(isA<AppFailure>()));
    expect(hf.requests.where((r) => r.url.host != 'cdn.example'), isEmpty);
  });

  test('썸네일 그림이 없으면 크레딧을 쓰기 전에 안내', () async {
    final (_, _, hf, ps, pr) = await setup();
    await expectLater(
      ps.generateWithHiggsfield(pr.id, userApproved: true),
      throwsA(isA<ProductionBlocked>().having((e) => e.message, 'm', contains('그림'))),
    );
    expect(hf.requests, isEmpty);
  });

  test('크레딧 부족(402) → 충전 안내', () async {
    final (_, _, hf, ps, pr) = await setup();
    await thumb(ps, pr.id);
    hf.submitCode = 402;
    await expectLater(
      (ps..pollDelay = Duration.zero).generateWithHiggsfield(pr.id, userApproved: true),
      throwsA(isA<ProductionBlocked>().having((e) => e.message, 'm', contains('부족'))),
    );
  });

  test('내용 검사(nsfw) → 크레딧 돌려받는다는 안내, 실패(failed) → 오류', () async {
    final (_, _, hf, ps, pr) = await setup();
    await thumb(ps, pr.id);
    hf.statuses
      ..clear()
      ..add('nsfw');
    await expectLater(
      (ps..pollDelay = Duration.zero).generateWithHiggsfield(pr.id, userApproved: true),
      throwsA(isA<ProductionBlocked>().having((e) => e.message, 'm', contains('돌려받아요'))),
    );
    hf.statuses
      ..clear()
      ..add('failed');
    await expectLater(
      (ps..pollDelay = Duration.zero).generateWithHiggsfield(pr.id, userApproved: true),
      throwsA(isA<AppFailure>()),
    );
  });

  test('기다리는 중 취소하면 힉스필드에도 취소 요청', () async {
    final (_, _, hf, ps, pr) = await setup();
    await thumb(ps, pr.id);
    hf.statuses
      ..clear()
      ..add('queued');
    final cancel = CancelToken();
    final run = (ps..pollDelay = const Duration(milliseconds: 5)).generateWithHiggsfield(
      pr.id,
      userApproved: true,
      cancel: cancel,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    cancel.cancel();
    await expectLater(run, throwsA(isA<AppFailure>()));
    expect(hf.cancels, 1);
  });

  test('예전 버전이 저장한 옛 주소는 공식 주소로', () async {
    final (_, u, _, _, _) = await setup();
    u.db.setSetting('higgsBaseUrl', 'https://platform.higgsfield.ai');
    expect(u.tools.higgsBaseUrl, 'https://api.higgsfield.ai');
    u.tools.higgsModel = 'dop-turbo';
    expect(((await u.tools.videoGenerator()) as HiggsfieldGenerator).model, 'dop-turbo');
    u.tools.higgsModel = 'weird';
    expect(u.tools.higgsModel, 'dop-lite');
  });
}
