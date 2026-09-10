# Window Text Watcher

- macOS 특정 창을 실시간 캡처
- 캡처 미리보기에서 OCR 대상 영역을 마우스로 지정
- Apple Vision 기반 한국어/영어 OCR 수행
- 지정 문자열 감지 시 macOS 시스템 알림 표시
- 동일 문자열이 계속 화면에 남아 있으면 설정한 재알림 주기마다 반복 알림

## 요구 환경

- macOS 14 이상
- Xcode Command Line Tools 또는 Xcode
- 별도 OCR Library 설치 불필요

## 실행

```bash
zsh scripts/run_app.sh
```

- 최초 실행 시 **알림 허용** 승인
- 화면 캡처가 차단되는 경우 **시스템 설정 → 개인정보 보호 및 보안 → 화면 및 시스템 오디오 녹음**에서 `Window Text Watcher` 허용
- 권한을 새로 허용한 경우 앱 재실행

## 사용 방법

- `새로고침`으로 현재 캡처 가능한 창 목록 로드
- 대상 프로그램의 창 선택
- 감지할 텍스트 입력
- `캡처 시작` 선택
- 미리보기에서 OCR할 영역을 마우스로 드래그
- 오른쪽 `OCR 결과`에서 실시간 인식 결과 확인
- 대상 문자열이 감지되면 시스템 알림 발생

## 감지 규칙

- 기본값: 대소문자 무시 부분 문자열 검색
- 줄바꿈/연속 공백: 하나의 공백으로 정규화 후 비교
- 대상 문자열이 계속 보이는 동안: `재알림` 시간마다 반복 알림
- 대상 문자열이 사라졌다 다시 나타난 경우에도 마지막 알림 이후 `재알림` 시간이 지나야 다시 알림
- OCR 수행 주기: 약 0.45초

## 테스트

```bash
swift test
```

- 텍스트 매칭
- 알림 중복 방지 및 cooldown
- Aspect Fit 미리보기 좌표와 Vision OCR ROI 좌표 변환

## 구조

- `ScreenCaptureService`: `ScreenCaptureKit` 기반 창 캡처
- `OCRService`: `Vision` 기반 OCR
- `NotificationService`: `UserNotifications` 기반 시스템 알림
- `RegionMapper`: 미리보기 드래그 영역과 OCR ROI 좌표 변환
- `TextMatcher`: OCR 결과와 대상 문자열 비교
- `DetectionGate`: 중복 알림 및 cooldown 제어

## 앱 이름 변경 및 권한

- 프로젝트명: `WindowTextWatcher`
- GitHub 저장소명: `window-text-watcher`
- Bundle Identifier: `com.dylan-kwon.WindowTextWatcher`
- 앱 식별자 변경에 따라 기존 권한과 별개로 화면 기록·알림 권한 허용 필요
- 서명 인증서 지정: `WINDOW_TEXT_WATCHER_SIGN_IDENTITY` 환경 변수 사용
