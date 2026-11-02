import 'failure.dart';

/// 화면에 보이는 모든 한국어 문구를 이 파일 한 곳에 모아 관리한다.
class S {
  S._();

  static const appName = '유튜브 블로그 채널 관리 비서';
  static const practiceMode = '연습 모드';
  static const practiceModeHint = '아직 실제 계정이나 AI가 연결되지 않아 가짜 자료로 연습하고 있어요.';

  // ---- 공통 버튼 ----
  static const ok = '확인';
  static const cancel = '취소';
  static const close = '닫기';
  static const save = '저장';
  static const next = '다음';
  static const back = '이전';
  static const skip = '건너뛰기';
  static const retry = '다시 시도';
  static const reconnect = '다시 연결';
  static const yes = '예';
  static const no = '아니요';
  static const delete = '삭제';
  static const copy = '복사';
  static const copied = '복사했어요.';
  static const loadMore = '더 불러오기';
  static const loading = '불러오는 중이에요…';
  static const done = '완료';
  static const edit = '수정';
  static const start = '시작';
  static const stop = '멈춤';
  static const empty = '아직 아무것도 없어요.';
  static const working = '작업 중이에요…';

  // ---- 로그인 ----
  static const loginTitle = '누가 사용하나요?';
  static const loginNewUser = '새 사용자 만들기';
  static const loginName = '이름';
  static const loginPassword = '비밀번호 (4자 이상)';
  static const loginPasswordAgain = '비밀번호 한 번 더';
  static const loginButton = '들어가기';
  static const loginWrong = '비밀번호가 맞지 않아요. 다시 입력해 주세요.';
  static const loginNameTaken = '이미 있는 이름이에요. 다른 이름을 써 주세요.';
  static const loginNameEmpty = '이름을 입력해 주세요.';
  static const loginPasswordShort = '비밀번호는 4자 이상으로 정해 주세요.';
  static const loginPasswordMismatch = '두 비밀번호가 서로 달라요.';
  static const logout = '로그아웃';
  static String loginAs(String name) => '$name 님으로 들어가기';

  // ---- 첫 실행 안내 ----
  static const wizardTitle = '처음 사용 안내';
  static const wizardStep1 = '1. 언어와 글씨 크기';
  static const wizardLanguage = '언어';
  static const wizardLanguageKo = '한국어';
  static const wizardLanguageOther = '다른 언어 (준비 중)';
  static const wizardStep2 = '2. 권한 허락';
  static const wizardPermIntro = '아래 권한은 허락하지 않아도 앱은 동작해요. 필요한 기능만 꺼져요.';
  static const permMic = '마이크';
  static const permMicWhy = '말로 명령하고 음성 메모를 남길 때 필요해요.';
  static const permNotify = '알림';
  static const permNotifyWhy = '자동 작업 시작·끝, 아침 브리핑, 만료 알림을 보내 드려요.';
  static const permStorage = '파일 저장';
  static const permStorageWhy = '직접 찍은 영상, 백업 파일을 고르고 저장할 때 필요해요.';
  static const permAllow = '허락하기';
  static const permAllowed = '허락됨';
  static const permDenied = '허락 안 됨 (괜찮아요)';
  static const wizardStep3 = '3. 계정 연결';
  static const wizardAccountIntro = '유튜브·블로그 계정은 지금 연결하거나, 나중에 설정에서 연결할 수 있어요.';
  static const wizardConnectNow = '지금 구글 계정 연결하기';
  static const wizardStep4 = '4. 연습 모드 안내';
  static const wizardPracticeIntro =
      '계정이나 AI 키가 없으면 "연습 모드"로 동작해요. 가짜 채널과 영상으로 모든 기능을 미리 써 볼 수 있고, '
      '실제 유튜브에는 아무것도 바뀌지 않아요. 화면 위에 "연습 모드" 표시가 보이면 연습 중이라는 뜻이에요.';
  static const wizardFinish = '시작하기';

  // ---- 메뉴 ----
  static const navHome = '현황';
  static const navChannels = '채널';
  static const navProduce = '제작';
  static const navBlog = '블로그';
  static const navCorner = '내 코너';
  static const navSettings = '설정';

  // ---- 현황 ----
  static const homeQuota = '오늘 남은 유튜브 사용량';
  static const homeCost = '이번 달 AI 비용';
  static const homeTodayEdits = '오늘 수정한 영상';
  static const homeReviewWaiting = '확인 기다리는 영상';
  static const homeBriefing = '아침 브리핑 듣기';
  static const homeDailyReport = '오늘 수정 내역 보기';
  static const homeRunEdits = '지금 수정 실행하기';
  static const homeVoiceSummary = '현황 음성으로 듣기';
  static const homeRunnerOff = '자동 작업: 꺼짐 (설정에서 켤 수 있어요)';
  static String homeRunnerOn(int from, int to) => '자동 작업: 켜짐 ($from시~$to시)';

  // ---- 채널 ----
  static const channelsTitle = '내 유튜브 채널';
  static const channelAdd = '채널 등록';
  static const channelUrl = '채널 주소 (예: https://youtube.com/@내채널)';
  static const channelConnectGoogle = '구글로 연결';
  static const channelConnectHint = '구글 로그인 창이 열려요. 비밀번호는 구글 창에만 입력하고, 이 앱에는 저장되지 않아요.';
  static const channelDisconnect = '연결 해제';
  static String channelDisconnectConfirm(String t) => '"$t" 채널 연결을 해제할까요? 앱에 저장된 이 채널 자료도 지워져요. (유튜브의 영상은 그대로예요)';
  static const channelSync = '새로 불러오기';
  static const channelVideos = '영상 목록';
  static const channelStyle = '채널 스타일 카드';
  static const channelEdits = '수정 내역';
  static const channelNone = '등록된 채널이 없어요. "채널 등록"을 눌러 시작해 보세요.';
  static String channelAdded(int n) => '채널 $n개를 등록했어요.';
  static String views(int n) => '조회수 ${_num(n)}';
  static String subscribers(int n) => '구독자 ${_num(n)}';
  static String videoCount(int n) => '영상 ${_num(n)}개';
  static const mockLoginTitle = '연습용 구글 로그인';
  static const mockLoginBody = '연습 모드라서 진짜 구글 창 대신 가짜 계정으로 연결해요. 실제 계정에는 아무 일도 일어나지 않아요.';
  static const mockLoginButton = '연습 계정으로 연결';

  // ---- 스타일 카드 ----
  static const styleAnalyze = '영상과 글을 분석해서 만들기';
  static const styleMood = '분위기';
  static const styleTone = '말투';
  static const styleTopics = '주로 다루는 주제';
  static const styleTitlePattern = '제목 스타일';
  static const styleAudience = '보는 사람';
  static const styleNotes = '기타 메모';
  static const styleSaved = '스타일 카드를 저장했어요.';
  static const styleEmpty = '아직 스타일 카드가 없어요. 분석 버튼을 눌러 만들어 보세요.';

  // ---- 자동 수정 ----
  static const editsTitle = '영상 제목·설명·키워드 수정';
  static const editRevert = '되돌리기';
  static const editRevertAll = '오늘 수정 모두 되돌리기';
  static const editReverted = '원래대로 되돌렸어요.';
  static const editRevertNewerFirst = '이 영상은 나중에 한 수정이 있어요. 가장 최근 수정부터 되돌려 주세요.';
  static const editRevertConflict = '수정한 뒤에 유튜브에서 이 영상 내용이 또 바뀌었어요. 그래도 수정 전 내용으로 되돌릴까요?';
  static const editRevertAnyway = '그래도 되돌리기';
  static const editBefore = '수정 전';
  static const editAfter = '수정 후';
  static String editViews(int before, int? after) =>
      after == null ? '수정 전 조회수 ${_num(before)}' : '조회수 ${_num(before)} → ${_num(after)}';
  static String editsDone(int n) => '영상 $n개를 수정했어요. 마음에 안 들면 언제든 되돌릴 수 있어요.';
  static const editsNone = '오늘은 수정할 영상이 없어요.';
  static const editsPreviewTitle = '이렇게 수정할게요';
  static const editsApply = '수정 적용하기';
  static String editsLimit(int n) => '채널당 하루 최대 $n개';
  static const editsFirstMonth = '처음 한 달은 채널당 하루 3개까지만 수정해요.';
  static const dailyReportTitle = '오늘 수정 내역 요약';
  static const editStatusApplied = '수정됨';
  static const editStatusReverted = '되돌림';
  static const editStatusFailed = '실패';

  // ---- 음성 ----
  static const voiceListen = '말하기';
  static const voiceListening = '듣고 있어요… 말씀하세요.';
  static const voiceNotAvailable = '이 기기에서는 음성 인식을 쓸 수 없어요. 글자로 입력해 주세요.';
  static const voiceTypeInstead = '글자로 입력';
  static const voiceCommandHint = '예: "이번 주 조회수 보여줘", "요리 채널에 쇼츠 하나 만들어"';
  static const voiceUnknown = '무슨 말씀인지 잘 모르겠어요. "도움말"이라고 말하면 할 수 있는 말을 알려 드려요.';
  static const voiceHelp =
      '이렇게 말해 보세요. 이번 주 조회수 보여줘. 비공개 영상 목록 읽어줘. 요리 채널에 쇼츠 하나 만들어. '
      '오늘 수정 내역 알려줘. 아침 브리핑 해줘. 메모, 그리고 남길 내용.';
  static const voiceMemoSaved = '음성 메모를 저장했어요.';
  static const voiceMemoTitle = '음성 메모';
  static const voiceMemoRecord = '말로 메모 남기기';
  static const voiceConfirmTitle = '중요한 작업 확인';
  static const voicePublishNotAllowed = '공개 전환은 안전을 위해 앱이 하지 않아요. 확인 대기 목록에서 유튜브로 가서 직접 공개해 주세요.';
  static const voiceDeleteNotAllowed = '영상 삭제는 안전을 위해 앱이 하지 않아요. 유튜브 스튜디오에서 직접 해 주세요.';
  static String voiceWeeklyViews(int total, int delta) =>
      '이번 주 전체 조회수는 ${_num(total)}회예요. 지난 7일 동안 ${_num(delta)}회 늘었어요.';
  static String voicePrivateList(int n, String titles) =>
      n == 0 ? '확인을 기다리는 비공개 영상이 없어요.' : '확인을 기다리는 비공개 영상이 $n개 있어요. $titles';

  // ---- 아침 브리핑 ----
  static const briefingTitle = '아침 브리핑';
  static const briefingYesterday = '어제 채널 변화';
  static const briefingToday = '오늘 할 일';
  static const briefingExpiring = '만료 임박';

  // ---- 설정 ----
  static const settingsTitle = '설정';
  static const settingsFontSize = '글씨 크기';
  static const settingsFontSmall = '보통';
  static const settingsFontLarge = '크게';
  static const settingsFontHuge = '아주 크게';
  static const settingsVoice = '음성 읽어주기';
  static const settingsVoiceRate = '읽는 속도';
  static const settingsBriefingTime = '아침 브리핑 시간';
  static const settingsBriefingOn = '아침 브리핑 켜기';
  static const settingsAi = 'AI 연결 (API 키)';
  static const settingsAiKey = 'Claude API 키';
  static const settingsAiModel = 'AI 모델';
  static const settingsAiProvider = 'AI 제공자';
  static const settingsAiLimit = '한 달 비용 한도 (달러)';
  static const settingsAiUsed = '이번 달 사용한 비용';
  static const settingsAiKeySaved = 'API 키를 안전한 곳(기기 보안 저장소)에 저장했어요.';
  static const settingsAiKeyRemove = 'API 키 지우기';
  static const settingsGoogle = '구글 연결 준비 (클라이언트 ID)';
  static const settingsGoogleClientId = '클라이언트 ID';
  static const settingsGoogleClientSecret = '클라이언트 보안 비밀 (데스크톱 앱용)';
  static const settingsGoogleHint = 'README의 "구글 연결 준비하기"를 보고 만든 값을 넣어 주세요. 비워 두면 연습 모드로 동작해요.';
  static const settingsQuotaLimit = '유튜브 하루 사용량 한도';
  static const settingsEditsPerDay = '채널당 하루 수정 개수';
  static const settingsRunner = '자동 작업 실행기';
  static const settingsRunnerOn = '자동 작업 켜기';
  static const settingsRunnerDesktopOnly = '자동 작업은 윈도우·맥 컴퓨터에서만 실행돼요. 휴대폰에서는 보기·승인·알림·음성만 쓸 수 있어요.';
  static const settingsRunnerFrom = '시작 시각';
  static const settingsRunnerTo = '끝 시각';
  static const settingsTools = '제작 도구 연결';
  static const settingsBackup = '백업 만들기';
  static const settingsRestore = '백업에서 복원';
  static const settingsBackupDone = '백업 파일을 만들었어요.';
  static const settingsRestoreDone = '복원했어요. 연결된 계정은 보안을 위해 다시 연결해 주세요.';
  static const settingsRestoreBad = '이 파일은 이 앱의 백업 파일이 아니에요.';
  static const settingsReset = '초기화 (모든 자료 삭제)';
  static const settingsReset1 = '정말 초기화할까요? 이 사용자의 채널·수정 내역·설정이 모두 지워져요. (유튜브의 영상은 그대로예요)';
  static const settingsReset2 = '마지막 확인이에요. 지운 자료는 되살릴 수 없어요. 그래도 초기화할까요?';
  static const settingsResetDone = '초기화했어요.';
  static const settingsReport = '문제 신고 (로그 내보내기)';
  static const settingsReportDone = '문제 신고 파일을 만들었어요. 이 파일을 Claude에게 보여 주세요. 비밀번호·토큰·키는 지워져 있어요.';
  static const settingsVersion = '앱 버전';
  static const settingsChangelog = '변경 내역';
  static const settingsIphone = '아이폰 지원 (준비 중)';
  static const settingsIphoneHint = '아이폰 앱은 준비 중이에요. 다른 기기를 쓰신다면 신경 쓰지 않으셔도 돼요.';
  static const settingsProduceLimit = '하루 제작 개수 한도';
  static const settingsAiLabel = 'AI 콘텐츠 표시 방법 (기본값)';
  static const settingsLanguage = '언어';
  static const settingsDeleteUser = '이 사용자 삭제';

  // ---- 자동 작업 ----
  static const runnerStarting = '자동 작업을 시작해요.';
  static String runnerDone(int edits, int deferred) =>
      '자동 작업이 끝났어요. 수정 $edits개${deferred > 0 ? ', 내일로 미룬 작업 $deferred개' : ''}.';
  static const runnerCostStop = 'AI 비용 한도에 도달해서 자동 작업을 멈췄어요.';
  static const runnerQuotaDefer = '유튜브 오늘 사용량이 다 되어서 남은 작업을 내일로 미뤘어요.';
  static const progressCancel = '작업 취소';
  static const progressCancelled = '작업을 취소했어요.';

  // ---- 2단계: 제작 ----
  static const produceTitle = '콘텐츠 만들기';
  static const produceNew = '새로 만들기';
  static const produceChannel = '어느 채널에 만들까요?';
  static const produceFormat = '어떤 형식으로 만들까요?';
  static const produceTopic = '주제나 아이디어 (비워 두면 AI가 정해요)';
  static const produceUseMemo = '음성 메모 사용';
  static const produceMake = '만들기';
  static const produceReviewList = '확인 대기 목록';
  static const produceDrafts = '만든 콘텐츠';
  static const produceLimitReached = '오늘 만들 수 있는 개수를 다 썼어요. 설정에서 한도를 바꾸거나 내일 다시 만들어 주세요.';
  static const produceTooSimilar = '최근에 만든 콘텐츠와 너무 비슷해요. 주제를 바꿔서 다시 만들어 주세요.';
  static const produceUpload = '유튜브에 비공개로 올리기';
  static const produceUploadConfirm = '이 콘텐츠를 유튜브에 "비공개"로 올릴까요? 다른 사람에게는 보이지 않고, 확인 대기 목록에 들어가요.';
  static const produceAiLabelCheck = 'AI 콘텐츠 표시를 확인해 주세요';
  static const produceAiLabelDesc = '설명 글에 표시';
  static const produceAiLabelChannel = '채널 소개에 표시';
  static const produceAiLabelSetting = '업로드 설정의 AI 항목에 표시';
  static const produceNeedVideo = '올릴 영상 파일이 없어요. "내가 만든 영상 넣기" 또는 "힉스필드로 영상 만들기"를 먼저 해 주세요.';
  static const produceAddOwnVideo = '내가 만든 영상 넣기';
  static const produceHiggsfield = '힉스필드로 영상 만들기';
  static String produceHiggsfieldConfirm(int est, int left) =>
      '힉스필드로 영상을 만들면 크레딧이 약 $est 들어요. 지금 남은 크레딧은 $left이에요. 만들까요?';
  static const produceHiggsfieldNotEnough = '힉스필드 크레딧이 부족해요.';
  static const produceOpenYoutube = '유튜브에서 확인하기';
  static const produceMarkPublished = '확인하고 공개했어요';
  static const produceUploaded = '비공개로 올렸어요. 확인 대기 목록에서 확인해 주세요.';
  static const produceDeferred = '오늘 유튜브 사용량이 부족해서 내일 올릴 수 있게 준비해 두었어요. 내일 확인 대기 목록에서 "올리기"를 눌러 주세요.';
  static const produceThumbnail = '썸네일 문구';
  static const produceScript = '대본·구성';
  static const formatShorts = '쇼츠';
  static const formatLong = '롱폼';
  static const formatDocu = '다큐멘터리';
  static const formatImage = '사진·이미지 게시물';
  static const formatTalk = '음성 대화형';

  // ---- 도구 연결 ----
  static const toolsTitle = '제작 도구 연결';
  static const toolConnected = '연결됨';
  static const toolNotConnected = '연결 안 됨';
  static const toolPreparing = '준비 중';
  static const toolTest = '연결 테스트';
  static const toolDisconnect = '연결 해제';
  static const toolConnect = '연결하기';
  static const toolApiKey = 'API 키';
  static const toolTestOk = '연결이 잘 되어 있어요.';
  static const toolExpired = '연결이 만료되었어요. 다시 연결해 주세요.';
  static const toolPriority = '사용 우선순위';
  static const toolVideoGen = '영상 생성';
  static const toolMotion = '모션 그래픽';
  static const toolNarration = '음성 나레이션';
  static const toolVault = '앱 금고 연동 (준비 중)';

  // ---- 3단계: 블로그 ----
  static const blogTitle = '블로그 관리';
  static const blogAddBlogger = '구글 블로그 연결';
  static const blogAddTistory = '티스토리 블로그 추가';
  static const blogTistoryName = '티스토리 블로그 이름';
  static const blogTistoryUrl = '티스토리 주소 (예: https://내블로그.tistory.com)';
  static const blogPosts = '글 목록';
  static const blogNewPost = '새 글 만들기';
  static const blogRunEdits = '기존 글 다듬기';
  static const blogDraftSaved = '구글 블로그에 "초안(비공개)"으로 올렸어요. 블로그에서 확인 후 공개해 주세요.';
  static const blogTistoryCopyHint = '티스토리는 자동으로 올릴 수 없어요. 아래 "복사" 버튼으로 복사한 뒤 티스토리 글쓰기에 붙여 넣어 주세요.';
  static const blogCopyTitle = '제목 복사';
  static const blogCopyBody = '본문 복사';
  static const blogCopyTags = '태그 복사';
  static const blogNone = '등록된 블로그가 없어요.';
  static const blogPerDay = '새 글은 하루 1~2개씩만 만들어요.';

  // ---- 4단계: 사용자 코너 ----
  static const cornerTitle = '내 이야기 코너';
  static const cornerNew = '코너 만들기';
  static const cornerName = '코너 이름';
  static const cornerChannel = '올릴 채널';
  static const cornerAddVideo = '내가 찍은 영상 넣기';
  static const cornerAddMemo = '음성 메모 고르기';
  static const cornerImport = '폴더에서 소재 가져오기';
  static const cornerMake = '자동으로 만들기';
  static const cornerSubtitles = '자막';
  static const cornerCopyright = '저작권 확인';
  static const cornerCopyrightAsk = '이 소재는 저작권이 있을 수 있어요. 직접 찍었거나 사용 허락을 받은 소재인가요?';
  static const cornerCopyrightYes = '네, 사용해도 돼요';
  static const cornerCopyrightNo = '아니요, 빼 주세요';
  static const cornerNone = '아직 코너가 없어요.';

  // ---- 오류 ----
  static const errorGeneric = '문제가 생겼어요. 잠시 뒤 다시 해 주세요. 계속되면 설정 → 문제 신고를 눌러 주세요.';
  static const errorScreen = '이 화면을 보여 주는 중에 문제가 생겼어요. 뒤로 갔다가 다시 들어와 주세요.';

  static String failureMessage(FailureKind kind) {
    switch (kind) {
      case FailureKind.network:
        return '인터넷 연결이 불안정해요. 연결을 확인하고 "다시 시도"를 눌러 주세요. 저장된 자료는 그대로 볼 수 있어요.';
      case FailureKind.timeout:
        return '응답이 너무 늦어요. 잠시 뒤 "다시 시도"를 눌러 주세요.';
      case FailureKind.tokenExpired:
        return '계정 연결이 만료되었어요. "다시 연결"을 눌러 주세요.';
      case FailureKind.permissionRevoked:
        return '계정 권한이 취소되었어요. "다시 연결"을 눌러 권한을 다시 허락해 주세요.';
      case FailureKind.quotaExceeded:
        return '오늘 쓸 수 있는 유튜브 사용량을 다 썼어요. 남은 작업은 내일 이어서 할게요.';
      case FailureKind.rateLimited:
        return '잠깐 동안 요청이 너무 많았어요. 조금 뒤 "다시 시도"를 눌러 주세요.';
      case FailureKind.costLimit:
        return '이번 달 AI 비용 한도에 도달했어요. 설정에서 한도를 바꾸거나 다음 달에 다시 써 주세요. 그동안은 연습 모드로 동작해요.';
      case FailureKind.notConnected:
        return '아직 연결되지 않았어요. 설정에서 먼저 연결해 주세요.';
      case FailureKind.notFound:
        return '찾는 자료가 없어요. 이미 지워졌을 수 있어요.';
      case FailureKind.invalidInput:
        return '입력한 내용을 확인해 주세요.';
      case FailureKind.conflict:
        return '다른 곳에서 내용이 바뀌었어요. 새로 불러온 뒤 다시 해 주세요.';
      case FailureKind.cancelled:
        return '작업을 취소했어요.';
      case FailureKind.unknown:
        return errorGeneric;
    }
  }

  static String nextActionLabel(NextAction a) {
    switch (a) {
      case NextAction.retry:
        return retry;
      case NextAction.reconnect:
        return reconnect;
      case NextAction.tryTomorrow:
        return '내일 다시 시도';
      case NextAction.checkSettings:
        return '설정 열기';
      case NextAction.none:
        return ok;
    }
  }

  static String _num(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  static String num(int n) => _num(n);
}
