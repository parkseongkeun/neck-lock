# Neck Lock (가칭)

거북목 방지용 맥북 메뉴바 앱.

업무 시간(평일 09–17시, 점심 12–13시 제외) 매시 정각에 키보드·마우스 입력이 잠기고, 카메라 앞에서 고개를 360° **2바퀴** 돌려야 다시 쓸 수 있다. 화면은 덮지 않는다.

- 스펙: [docs/PRD.md](docs/PRD.md)
- 대상: macOS 13+, 본인 맥 전용
- 상태: macOS에서 컴파일·`.app` 빌드·코어 테스트 통과 확인. **카메라·입력 차단 실기기 동작은 아직 미확인** (권한 허용 후 "지금 테스트 잠금"으로 확인할 것)

## 구조

| 경로 | 내용 |
|---|---|
| `Sources/NeckLockCore` | 스케줄 계산, 잠금 시각 판정, 고개 회전 판정. Foundation만 써서 어디서든 테스트 가능 |
| `Sources/NeckLock` | 메뉴바 앱 (AppKit·SwiftUI·AVFoundation·Vision), 입력 차단(CGEventTap), 잠금 창, 설정 |
| `Tests/NeckLockCoreTests` | 코어 로직 단위 테스트 |
| `scripts/build-app.sh` | `.app` 번들 빌드 |

## 다운로드와 실행 (맥에서)

**1. 받기**

```bash
git clone https://github.com/opensmartyouth-art/neck-lock
cd neck-lock
```

**2. 개발 도구 확인.** `xcode-select -p`가 경로를 출력하면 설치된 것이다. 없으면:

```bash
xcode-select --install
```

**3. 빌드** (1분쯤 걸린다)

```bash
scripts/build-app.sh       # build/NeckLock.app 생성
```

**4. 실행.** 반드시 `.app`으로 연다. `swift run`으로 실행하면 카메라 권한 창이 뜨지 않고 종료된다.

```bash
open build/NeckLock.app
```

**5. 권한 허용**

- **손쉬운 사용**: 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 NeckLock을 켠다 (키보드·마우스 입력 차단용). 켠 뒤 앱을 다시 실행해야 적용될 수 있다.
- **카메라**: 처음 잠글 때 뜨는 팝업에서 허용한다 (고개 방향 인식용).

**6. 처음 확인하는 순서**

1. 메뉴바 아이콘(명상하는 사람) > **붉은 테두리 미리보기** — 입력을 막지 않는 안전한 확인
2. **비상 해제 키 ⌃⌥⌘⇧ + Esc를 먼저 외운다**
3. **지금 테스트 잠금** — 고개를 돌려 카메라 원 테두리의 점과 선이 따라오는지 본다. 20초쯤 가만히 있으면 화면 테두리가 붉게 맥동한다.

점이 얼굴과 반대로 움직이면 `Sources/NeckLock/ProgressRing.swift`의 `Orientation.flipHorizontal` 또는 `flipVertical`을 `true`로 바꾼다.

## 테스트

```bash
swift test                 # 코어 로직 테스트 (Xcode 필요)
```

`swift test`(XCTest)는 **Xcode가 설치돼 있어야** 돈다. Command Line Tools만 있으면 `no such module 'XCTest'`로 실패하는데, 앱 빌드(`scripts/build-app.sh`)에는 영향이 없다.

## 문제 해결

- **`swift`가 링크 에러(`libPackageDescription`, `SwiftBridging` 중복)를 낸다**: Command Line Tools가 꼬인 것이다.
  `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`
- **빌드 후 권한이 초기화된다**: 기본 ad-hoc 서명은 빌드할 때마다 서명이 바뀐다. 고정된 인증서로 서명한다.

  ```bash
  SIGN_IDENTITY="Apple Development: 이름 (TEAMID)" scripts/build-app.sh
  ```
- **잠금이 안 걸리고 메뉴바에 경고만 뜬다**: 손쉬운 사용 또는 카메라 권한이 없는 것이다 (의도된 안전장치).

## 사용

메뉴바 아이콘에서 다음을 할 수 있다.

- 다음 잠금 시각 확인
- **지금 테스트 잠금**: 정각을 기다리지 않고 동작 확인 (처음엔 이걸로 먼저 확인할 것)
- 오늘 하루 끄기 / 다시 켜기
- **붉은 테두리 미리보기**: 방치 경고 모양 확인 (입력은 막지 않음)
- 설정 (업무 요일·시간, 점심, 바퀴 수, 최대 잠금 시간, 방치 경고 on/off, 각도 표시)
- 로그인 시 자동 실행

## 안전장치

- 잠긴 뒤 20초 동안 고개를 안 돌리면 화면 테두리가 붉게 맥동한다 (클릭·입력은 막지 않음, 설정에서 끌 수 있음)

- 비상 해제: **⌃⌥⌘⇧ + Esc**
- 기본 10분이 지나면 자동 해제 (설정에서 변경)
- 권한이나 카메라가 없으면 잠그지 않고 메뉴바에 경고만 표시
