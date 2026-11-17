import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/db.dart';
import '../../core/failure.dart';
import '../../core/http_json.dart';
import '../../core/logger.dart';
import '../../core/oauth.dart';
import '../../core/secret_store.dart';

enum ToolId { googleVids, higgsfield, figma, vrew }

enum ToolState { connected, notConnected, expired, preparing }

class ToolInfo {
  ToolInfo(this.id, this.name, this.role, this.state, {this.detail = ''});
  final ToolId id;
  final String name;
  final String role;
  final ToolState state;
  final String detail;
}

/// 영상 생성 도구 틀. 힉스필드(실제) / 연습용(가짜) 이 이 틀을 따른다.
abstract class VideoGenerator {
  /// 남은 크레딧. 알 수 없으면 null (힉스필드는 잔액을 알려 주는 API 가 없음).
  Future<int?> credits();
  int estimateCredits(String prompt, {int seconds = 10});

  /// 움직일 그림이 꼭 필요한지 (힉스필드 그림→영상)
  bool get needsImage;

  /// 만들기 시작. 작업 번호를 돌려준다.
  Future<String> start(String prompt, {int seconds = 10, File? image});

  /// 끝났으면 영상 주소, 아직이면 null. 실패면 예외.
  Future<String?> poll(String jobId);

  /// 아직 기다리는 중인 작업 취소 (이미 만드는 중이면 취소되지 않을 수 있음)
  Future<void> cancel(String jobId);
  Future<void> download(String url, File target);
}

/// 크레딧이 모자라 시작하지 못함. (다시 시도하지 않는 오류)
class NotEnoughCredits extends AppFailure {
  NotEnoughCredits() : super(FailureKind.invalidInput, 'not enough credits');
}

/// 내용 검사(성인·폭력 등)에 걸려 만들지 않음 (크레딧은 돌려받음). (다시 시도하지 않는 오류)
class GenerationRejected extends AppFailure {
  GenerationRejected() : super(FailureKind.invalidInput, 'nsfw');
}

/// 힉스필드 공식 API (2026년 공식 SDK higgsfield-client·higgsfield-js 와 같은 형식).
/// - 주소: https://api.higgsfield.ai
/// - 인증: Authorization: Key {키 ID}:{비밀 값}
/// - 만들기: POST {주소}/{모델 경로} (JSON) → request_id, status_url, cancel_url
/// - 상태: GET /requests/{id}/status → queued / in_progress / completed / failed / nsfw / canceled, 영상은 video.url
/// - 그림 올리기: POST /files/generate-upload-url → upload_url 에 PUT → public_url
/// 그림→영상(DoP) 모델로, 제작 콘텐츠의 썸네일 그림을 움직이는 영상으로 만든다.
/// 크레딧이 드는 작업은 사용자가 화면에서 직접 승인했을 때만 불린다(ProductionService 참고).
class HiggsfieldGenerator implements VideoGenerator {
  HiggsfieldGenerator(
    this.json,
    this.raw,
    this.apiKey, {
    this.baseUrl = defaultBaseUrl,
    this.modelPath = defaultModelPath,
    this.model = defaultModel,
  });
  static const defaultBaseUrl = 'https://api.higgsfield.ai';
  static const defaultModelPath = '/v1/image2video/dop';

  /// dop-lite(기본, 가장 저렴) / dop-turbo(빠름) / dop-standard(가장 좋은 품질)
  static const defaultModel = 'dop-lite';
  static const models = ['dop-lite', 'dop-turbo', 'dop-standard'];

  final JsonHttp json;
  final http.Client raw;

  /// "키 ID:비밀 값"
  final String apiKey;
  final String baseUrl;
  final String modelPath;
  final String model;

  Map<String, String> get _h => {
    'authorization': 'Key $apiKey',
    'accept': 'application/json',
    'user-agent': 'channel-biseo-app',
  };

  String get _base => baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  /// "키 ID:비밀 값" 모양인지
  static bool validKey(String k) {
    final i = k.trim().indexOf(':');
    return i > 0 && i < k.trim().length - 1;
  }

  @override
  bool get needsImage => true;

  /// 잔액 조회 API 가 없음 → 힉스필드 웹사이트에서 확인
  @override
  Future<int?> credits() async => null;

  /// 대략적인 값 (모델별 실제 가격은 힉스필드 웹사이트 기준).
  @override
  int estimateCredits(String prompt, {int seconds = 10}) => switch (model) {
    'dop-standard' => 9,
    'dop-turbo' => 6,
    _ => 3,
  };

  Future<Map<String, dynamic>> _send(String method, String pathOrUrl, {Object? body, int maxAttempts = 3}) async {
    final url = pathOrUrl.startsWith('http') ? pathOrUrl : '$_base$pathOrUrl';
    try {
      return await json.send(method, Uri.parse(url), headers: _h, body: body, maxAttempts: maxAttempts);
    } on AppFailure catch (e) {
      // 402 = 크레딧 부족
      if (e.detail.contains('HTTP 402')) throw NotEnoughCredits();
      rethrow;
    }
  }

  /// 그림을 힉스필드에 올리고 공개 주소를 받는다.
  Future<String> upload(File image) async {
    final type = image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final j = await _send('POST', '/files/generate-upload-url', body: {'content_type': type});
    final uploadUrl = j['upload_url'] as String?;
    final publicUrl = j['public_url'] as String?;
    if (uploadUrl == null || publicUrl == null) throw AppFailure(FailureKind.unknown, 'no upload url');
    final headers = <String, String>{'content-type': type};
    final extra = j['upload_headers'];
    if (extra is Map) extra.forEach((k, v) => headers['$k'] = '$v');
    final res = await raw.put(Uri.parse(uploadUrl), headers: headers, body: await image.readAsBytes());
    if (res.statusCode >= 300) throw classifyHttpError(res.statusCode, res.body);
    return publicUrl;
  }

  @override
  Future<String> start(String prompt, {int seconds = 10, File? image}) async {
    if (image == null || !image.existsSync()) throw AppFailure(FailureKind.invalidInput, 'no image');
    final imageUrl = await upload(image);
    final j = await _send(
      'POST',
      modelPath.startsWith('/') ? modelPath : '/$modelPath',
      body: {
        'model': model,
        'prompt': prompt.length > 1000 ? prompt.substring(0, 1000) : prompt,
        'input_images': [
          {'type': 'image_url', 'image_url': imageUrl},
        ],
      },
      maxAttempts: 1, // 크레딧이 드는 요청은 다시 보내지 않음
    );
    final id = (j['request_id'] ?? j['id'])?.toString();
    if (id == null) throw AppFailure(FailureKind.unknown, 'no request id');
    return id;
  }

  @override
  Future<String?> poll(String jobId) async {
    final j = await _send('GET', '/requests/$jobId/status');
    switch ('${j['status'] ?? ''}') {
      case 'completed':
        final video = j['video'];
        final url = video is Map ? video['url'] : null;
        if (url == null) throw AppFailure(FailureKind.unknown, 'no video url');
        return '$url';
      case 'nsfw':
        throw GenerationRejected();
      case 'failed':
        throw AppFailure(FailureKind.unknown, 'generation failed');
      case 'canceled':
        throw AppFailure(FailureKind.cancelled, 'canceled');
      default: // queued, in_progress
        return null;
    }
  }

  @override
  Future<void> cancel(String jobId) async {
    try {
      await _send('POST', '/requests/$jobId/cancel', maxAttempts: 1);
    } catch (_) {
      // 이미 만드는 중이면 취소되지 않음 (400) — 괜찮음
    }
  }

  @override
  Future<void> download(String url, File target) async {
    final res = await raw.get(Uri.parse(url)).timeout(const Duration(minutes: 10));
    if (res.statusCode >= 300) throw classifyHttpError(res.statusCode, '');
    target.parent.createSync(recursive: true);
    await target.writeAsBytes(res.bodyBytes);
  }
}

/// 연습 모드용 가짜 영상 생성기 (크레딧 0, 작은 가짜 파일).
class MockVideoGenerator implements VideoGenerator {
  int left = 500;
  int started = 0;
  @override
  bool get needsImage => false;
  int cancelled = 0;
  @override
  Future<void> cancel(String jobId) async => cancelled++;
  @override
  Future<int?> credits() async => left;
  @override
  int estimateCredits(String prompt, {int seconds = 10}) => (seconds / 5).ceil() * 10;
  @override
  Future<String> start(String prompt, {int seconds = 10, File? image}) async {
    started++;
    left -= estimateCredits(prompt, seconds: seconds);
    return 'mockjob$started';
  }

  @override
  Future<String?> poll(String jobId) async => 'mock://$jobId.mp4';
  @override
  Future<void> download(String url, File target) async {
    target.parent.createSync(recursive: true);
    await target.writeAsBytes(utf8.encode('연습용 가짜 영상 $url'));
  }
}

/// 앱 금고(5번 앱) 연동 틀. 첫 버전은 연결하지 않는다. 도구 비밀번호는 저장하지 않는다.
abstract class AppVault {
  bool get available;
  Future<String?> credentialFor(ToolId tool);
}

class NoVault implements AppVault {
  @override
  bool get available => false;
  @override
  Future<String?> credentialFor(ToolId tool) async => null;
}

/// 제작 도구 연결 관리 (연결 상태·테스트·해제·만료).
class ToolsService {
  ToolsService({
    required this.db,
    required this.secrets,
    required this.json,
    required this.raw,
    required this.oauth,
    required this.now,
    this.logger,
    VideoGenerator? mockGenerator,
  }) : mockGenerator = mockGenerator ?? MockVideoGenerator();

  final AppDatabase db;
  final UserSecrets secrets;
  final JsonHttp json;
  final http.Client raw;
  final OAuthFlow oauth;
  final DateTime Function() now;
  final AppLogger? logger;
  final VideoGenerator mockGenerator;
  final AppVault vault = NoVault();

  static const higgsKey = 'tools/higgsfield/key';
  static const figmaTokens = 'tools/figma/tokens';
  static const figmaSecret = 'tools/figma/clientSecret';

  /// 예전 버전이 저장한 옛 주소(platform.higgsfield.ai)는 공식 주소로 바꿔 읽는다.
  String get higgsBaseUrl {
    final v = db.getSetting<String>('higgsBaseUrl') ?? '';
    return v.isEmpty || v.contains('platform.higgsfield.ai') ? HiggsfieldGenerator.defaultBaseUrl : v;
  }

  set higgsBaseUrl(String v) => db.setSetting('higgsBaseUrl', v.trim());

  /// dop-lite / dop-turbo / dop-standard
  String get higgsModel {
    final v = db.getSetting<String>('higgsModel') ?? '';
    return HiggsfieldGenerator.models.contains(v) ? v : HiggsfieldGenerator.defaultModel;
  }

  set higgsModel(String v) => db.setSetting('higgsModel', v);
  String get figmaClientId => db.getSetting<String>('figmaClientId') ?? '';
  set figmaClientId(String v) => db.setSetting('figmaClientId', v.trim());

  void _setStatus(ToolId t, String status, {DateTime? expires}) => db.execute(
    'INSERT INTO tool_status(tool, connected_at, expires_at, status) VALUES(?,?,?,?) '
    'ON CONFLICT(tool) DO UPDATE SET connected_at=excluded.connected_at, expires_at=excluded.expires_at, status=excluded.status',
    [t.name, now().toIso8601String(), expires?.toIso8601String(), status],
  );

  ({String status, DateTime? expires})? _status(ToolId t) {
    final r = db.select('SELECT status, expires_at FROM tool_status WHERE tool = ?', [t.name]);
    if (r.isEmpty) return null;
    final e = r.first['expires_at'] as String?;
    return (status: r.first['status'] as String, expires: e == null ? null : DateTime.parse(e));
  }

  Future<List<ToolInfo>> all() async {
    ToolState st(ToolId t) {
      final s = _status(t);
      if (s == null || s.status == 'none') return ToolState.notConnected;
      if (s.status == 'expired' || (s.expires != null && now().isAfter(s.expires!))) return ToolState.expired;
      return ToolState.connected;
    }

    return [
      ToolInfo(
        ToolId.googleVids,
        '구글 비즈 (Google Vids)',
        '영상 생성 1순위',
        ToolState.preparing,
        detail: '공식 API 가 없어 다음 버전에서 지원 예정이에요.',
      ),
      ToolInfo(
        ToolId.higgsfield,
        '힉스필드 (Higgsfield)',
        '영상 생성 · 음성 나레이션',
        (await secrets.read(higgsKey)) == null ? ToolState.notConnected : st(ToolId.higgsfield),
      ),
      ToolInfo(
        ToolId.figma,
        '피그마 (Figma)',
        '모션 그래픽',
        (await secrets.read(figmaTokens)) == null ? ToolState.notConnected : st(ToolId.figma),
      ),
      ToolInfo(ToolId.vrew, '브루 (Vrew)', '음성 나레이션', ToolState.preparing, detail: '공식 API 가 없어 다음 버전에서 지원 예정이에요.'),
    ];
  }

  // ---- 힉스필드 ----
  Future<void> connectHiggsfield(String key) async {
    if (!HiggsfieldGenerator.validKey(key)) throw AppFailure(FailureKind.invalidInput, 'key format');
    await secrets.write(higgsKey, key.trim());
    _setStatus(ToolId.higgsfield, 'ok');
  }

  Future<bool> get higgsConnected async => (await secrets.read(higgsKey)) != null;

  /// 키가 있으면 실제, 없으면 연습용.
  Future<VideoGenerator> videoGenerator() async {
    final k = await secrets.read(higgsKey);
    if (k == null) return mockGenerator;
    return HiggsfieldGenerator(json, raw, k, baseUrl: higgsBaseUrl, model: higgsModel);
  }

  // ---- 피그마 ----
  Future<void> connectFigma() async {
    final cfg = OAuthConfig.figma(figmaClientId, (await secrets.read(figmaSecret)) ?? '');
    final t = await oauth.authorize(cfg);
    await secrets.write(figmaTokens, t.encode());
    _setStatus(ToolId.figma, 'ok', expires: t.refreshToken == null ? t.expiresAt : null);
  }

  /// 연결 테스트. 실패 원인에 따라 상태를 "만료" 로 바꾼다.
  Future<bool> test(ToolId t) async {
    try {
      switch (t) {
        case ToolId.higgsfield:
          await (await videoGenerator()).credits();
        case ToolId.figma:
          final tok = OAuthTokens.decode(await secrets.read(figmaTokens));
          if (tok == null) throw AppFailure(FailureKind.notConnected);
          await json.send(
            'GET',
            Uri.parse('https://api.figma.com/v1/me'),
            headers: {'authorization': 'Bearer ${tok.accessToken}'},
          );
        case ToolId.googleVids:
        case ToolId.vrew:
          return false;
      }
      _setStatus(t, 'ok', expires: _status(t)?.expires);
      return true;
    } on AppFailure catch (e) {
      if (e.kind == FailureKind.tokenExpired || e.kind == FailureKind.permissionRevoked) _setStatus(t, 'expired');
      rethrow;
    }
  }

  Future<void> disconnect(ToolId t) async {
    switch (t) {
      case ToolId.higgsfield:
        await secrets.delete(higgsKey);
      case ToolId.figma:
        await secrets.delete(figmaTokens);
      case ToolId.googleVids:
      case ToolId.vrew:
        break;
    }
    db.execute('DELETE FROM tool_status WHERE tool = ?', [t.name]);
  }

  /// 만료되었거나 3일 안에 만료되는 도구 (브리핑·알림용).
  Future<List<String>> expiringNotices() async {
    final out = <String>[];
    for (final t in await all()) {
      if (t.state == ToolState.expired) out.add('${t.name} 연결이 만료되었어요. 설정 → 제작 도구 연결에서 다시 연결해 주세요');
      final s = _status(t.id);
      if (t.state == ToolState.connected && s?.expires != null && s!.expires!.difference(now()).inDays < 3) {
        out.add('${t.name} 연결이 곧 만료돼요');
      }
    }
    return out;
  }
}
