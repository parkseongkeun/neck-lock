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
scripts/build-app.sh       # build/NeckLock.app 생성 (ad-hoc 서명)
```

계속 개발할 거면 권한이 안 풀리도록 고정 인증서로 빌드한다 (아래 "문제 해결" 참고).

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
- **빌드할 때마다 권한을 다시 묻는다**: 기본 ad-hoc 서명은 빌드마다 서명이 달라져서 맥이 다른 앱으로 본다. 고정된 자체 서명 인증서를 한 번 만들어 두면 해결된다.
  1. 키체인 접근을 연다 (최신 맥에서 `open -a "Keychain Access"`는 "암호" 앱이 열리므로, 경로로 연다: `open "/System/Library/CoreServices/Applications/Keychain Access.app"`).
  2. 왼쪽에서 **로그인** 선택 → 메뉴바 **키체인 접근 → 인증서 지원 → 인증서 생성…**
  3. 이름 `NeckLock Dev`, 신원 유형 **자체 서명 루트**, 인증서 유형 **코드 서명**으로 생성.
  4. 이 인증서로 빌드한다. (`CSSMERR_TP_NOT_TRUSTED`로 보여도 서명과 권한 유지에는 문제없다.)

  ```bash
  SIGN_IDENTITY="NeckLock Dev" scripts/build-app.sh
  ```

  처음 한 번만 손쉬운 사용 권한을 다시 켜면 된다 (`tccutil reset Accessibility com.opensmartyouth.necklock` 후 앱 실행 → 허용 → 앱 재실행). 이후 빌드에서는 유지된다.
- **잠금이 안 걸리고 메뉴바에 경고만 뜬다**: 손쉬운 사용 또는 카메라 권한이 없는 것이다 (의도된 안전장치).

## 사용

메뉴바 아이콘에서 다음을 할 수 있다.

- 다음 잠금 시각 확인
- **지금 테스트 잠금**: 정각을 기다리지 않고 동작 확인 (처음엔 이걸로 먼저 확인할 것)
- 오늘 하루 끄기 / 다시 켜기
- **붉은 테두리 미리보기**: 방치 경고 모양 확인 (입력은 막지 않음)
- 설정 (업무 요일·시간, 점심, 바퀴 수, 최대 잠금 시간, 방치 경고 on/off, 각도 표시)
- 로그인 시 자동 실행

## 카메라

- 기본은 시스템 기본 카메라이고, 메뉴바 **카메라** 또는 설정에서 고른다. 잠금 중에는 카메라 창의 **카메라 전환** 버튼으로 바꾼다 (카메라가 2개 이상일 때만 보인다).
- **아이폰(연속성 카메라)은 후면 카메라 하나로만 잡힌다.** 이 맥에서 확인한 결과 전면/후면으로 나뉜 장치가 없고(방향 정보 없음), 애플 문서도 후면 카메라 기준이다. 앱에서 전면을 고를 수는 없다.
- **안드로이드폰**은 연속성 카메라를 쓸 수 없다. 이 경우 맥 내장 카메라(기본값)로 그대로 동작한다. 폰 카메라를 쓰고 싶으면 폰을 웹캠으로 만들어 주는 앱(예: Iriun Webcam)을 설치하면 외장 카메라로 목록에 나타날 수 있다 (미검증).

## 개발용 옵션

```bash
open build/NeckLock.app --args --test-lock   # 실행 2초 뒤 테스트 잠금을 건다
/usr/bin/log show --last 10m --info --predicate 'subsystem == "com.opensmartyouth.necklock"' --style compact
```

zsh의 `log`는 내장 명령이라 반드시 `/usr/bin/log`로 쓴다.

## 안전장치

- 잠긴 뒤 20초 동안 고개를 안 돌리면 화면 테두리가 붉게 맥동한다 (클릭·입력은 막지 않음, 설정에서 끌 수 있음)

- 비상 해제: **⌃⌥⌘⇧ + Esc**
- 기본 10분이 지나면 자동 해제 (설정에서 변경)
- 권한이나 카메라가 없으면 잠그지 않고 메뉴바에 경고만 표시
