# 진행 상황

새 세션에서는 "PROGRESS.md를 읽고 이어서 진행" 한 줄이면 이어서 할 수 있습니다.

## 개발 환경 메모 (새 세션용)
- Flutter: `/opt/flutter/bin` 에 3.47.9 설치 (없으면 storage.googleapis.com 에서 다시 받기). `export PATH=/opt/flutter/bin:$PATH`
- 리눅스 빌드 도구: `apt-get install libgtk-3-dev libsecret-1-dev`
- 검사: `cd app && dart format --set-exit-if-changed lib test && flutter analyze --fatal-infos && flutter test && flutter build linux --release`

## 완료한 것
- 0단계 뼈대 (로그인, 첫 실행 안내, 설정, 음성 틀, 오류 처리, DB 변환, 백업·복원·초기화·문제 신고)
- 1단계 유튜브 채널 관리 + 검증 (docs/보고/1단계.md, docs/검증/1단계.md)
- GitHub Actions 워크플로 (.github/workflows/build.yml)

## 지금 하던 것
- 2단계 콘텐츠 제작과 업로드

## 다음에 할 일 (순서대로)
1. 2단계 콘텐츠 제작 (형식 선택, 비공개 업로드, 확인 대기 목록, AI 표시, 반복 방지, 도구 연결) + 검증
2. 3단계 블로그(Blogger)·티스토리(복사) + 검증
3. 4단계 사용자 코너 + 폴더에서 소재 가져오기 + 검증
4. 누락 점검(docs/검증/누락점검.md), README, docs/배포준비.md, 최종 보고

## 알려진 문제
- 안드로이드는 이 환경에서 직접 빌드 불가 → GitHub Actions 결과로 확인
