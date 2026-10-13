# Neck Lock (가칭)

거북목 방지용 맥북 메뉴바 앱.

업무 시간(평일 09–17시, 점심 12–13시 제외) 매시 정각에 키보드·마우스 입력이 잠기고, 카메라 앞에서 고개를 360° **2바퀴** 돌려야 다시 쓸 수 있다. 화면은 덮지 않는다.

- 스펙: [docs/PRD.md](docs/PRD.md)
- 대상: macOS 13+, 본인 맥 전용
- 상태: 코드 작성 완료, **macOS에서 아직 빌드·실행 전** (개발 환경이 Linux라서 컴파일을 못 해봤다)

## 구조

| 경로 | 내용 |
|---|---|
| `Sources/NeckLockCore` | 스케줄 계산, 잠금 시각 판정, 고개 회전 판정. Foundation만 써서 어디서든 테스트 가능 |
| `Sources/NeckLock` | 메뉴바 앱 (AppKit·SwiftUI·AVFoundation·Vision), 입력 차단(CGEventTap), 잠금 창, 설정 |
| `Tests/NeckLockCoreTests` | 코어 로직 단위 테스트 |
| `scripts/build-app.sh` | `.app` 번들 빌드 |

## 빌드와 실행 (맥에서)

Xcode 또는 Command Line Tools(Swift 5.9+)가 필요하다.

```bash
swift test                 # 코어 로직 테스트
scripts/build-app.sh       # build/NeckLock.app 생성
open build/NeckLock.app
```

반드시 `.app`으로 실행한다. `swift run`으로 실행하면 카메라 권한 창이 뜨지 않고 종료된다.

처음 실행하면 두 가지 권한을 요청한다.

- **카메라**: 고개 방향 인식
- **손쉬운 사용** (시스템 설정 > 개인정보 보호 및 보안): 키보드·마우스 입력 차단

ad-hoc 서명은 빌드할 때마다 서명이 바뀌어서 권한이 초기화될 수 있다. 계속 개발할 거면 고정된 인증서로 서명한다.

```bash
SIGN_IDENTITY="Apple Development: 이름 (TEAMID)" scripts/build-app.sh
```

## 사용

메뉴바 아이콘에서 다음을 할 수 있다.

- 다음 잠금 시각 확인
- **지금 테스트 잠금**: 정각을 기다리지 않고 동작 확인 (처음엔 이걸로 먼저 확인할 것)
- 오늘 하루 끄기 / 다시 켜기
- 설정 (업무 요일·시간, 점심, 바퀴 수, 최대 잠금 시간, 각도 표시)
- 로그인 시 자동 실행

## 안전장치

- 비상 해제: **⌃⌥⌘⇧ + Esc**
- 기본 10분이 지나면 자동 해제 (설정에서 변경)
- 권한이나 카메라가 없으면 잠그지 않고 메뉴바에 경고만 표시
