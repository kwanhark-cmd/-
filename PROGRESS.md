# 진행 상황

새 세션에서는 "PROGRESS.md를 읽고 이어서 진행" 한 줄이면 이어서 할 수 있습니다.

## 개발 환경 메모 (새 세션용)
- Flutter: `/opt/flutter/bin` 에 3.47.9 설치 (없으면 storage.googleapis.com 에서 다시 받기). `export PATH=/opt/flutter/bin:$PATH`
- 리눅스 빌드 도구: `apt-get install libgtk-3-dev libsecret-1-dev`
- 검사: `cd app && dart format --set-exit-if-changed lib test && flutter analyze --fatal-infos && flutter test && flutter build linux --release`

## 완료한 것 (1.0.0)
- 0단계 뼈대 (로그인, 첫 실행 안내, 설정, 음성, 오류 처리, DB 변환, 백업·복원·초기화·문제 신고)
- 1단계 유튜브 채널 관리 + 검증
- 2단계 콘텐츠 제작·비공개 업로드·도구 연결 + 검증
- 3단계 구글 블로그·티스토리 + 검증
- 4단계 사용자 코너·폴더에서 소재 가져오기·저작권 확인 + 검증
- 누락 점검 후 보완 (화면 문구 한 파일로, 썸네일 그림·업로드, 작업별 예상 AI 비용, 자동 로그인, 음성 서비스 선택)
- README, docs/배포준비.md, docs/검증/누락점검.md, docs/보고/최종보고.md
- GitHub Actions: 테스트·리눅스·윈도우·맥·안드로이드 빌드

## 지금 하던 것
- 없음 (모든 단계 완료)

## 다음에 할 일 (사용자 쪽)
1. README 의 "구글 연결 준비하기" 로 실제 계정 연결
2. 실제 사용하면서 문제가 생기면 "문제 신고" 파일로 개선 요청
3. 판매를 원하면 docs/배포준비.md

## 다음에 할 일 (개발 쪽, 원하면)
- 힉스필드 공식 API 확인 후 주소·요금 맞추기 (BLOCKERS 3)
- 운영체제 예약 실행 (앱이 꺼져 있어도 자동 작업)
- 외부 음성 서비스 연결, 영상 소리 받아쓰기 자막

## 알려진 문제
- 안드로이드는 이 개발 환경에서 직접 빌드 불가 → GitHub Actions 결과로 확인
- 실제 외부 계정 연결은 가짜 응답으로만 확인됨 (BLOCKERS.md)
