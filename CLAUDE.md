# Neck Lock — Claude Code 인수인계

거북목 방지용 macOS 메뉴바 앱. 업무 시간 매시 정각에 키보드·마우스 입력을 잠그고(화면은 반투명하게 어두워짐), 카메라 앞에서 고개를 360° 2바퀴 돌려야 해제된다. 본인 맥 전용 (App Store 배포 안 함).

스펙은 `docs/PRD.md`, 사용법은 `README.md`. 사용자는 한국어로 소통하고, 구조화된 결과를 선호한다. 보고는 짧게, 한 일과 다음 할 일만.

## 현재 상태 (중요)

macOS에서 컴파일·`.app` 빌드·코어 테스트(32개)를 확인했고, **실기기에서 잠금 → 카메라 인식 → 해제까지 한 번 성공**했다 (사용자 확인, 2026-10-13). 아직 확인 못 한 것:
- 진행 링의 점이 얼굴과 같은 방향인지 (확인 기록 없음). 어긋나면 `ProgressRing.Orientation`의 `flipHorizontal`/`flipVertical`을 뒤집는다.
- 방치 경고(붉은 테두리, `BorderAlarm`·`StretchNag`): 메뉴 "붉은 테두리 미리보기"로 모양은 확인했지만, 실제 잠금 중 20초 무동작 → 켜짐은 **안 뜬 것으로 보고됨**. 바퀴 수를 1로 줄여 20초 안에 풀렸을 가능성이 크지만 확인 전이다. 20초 이상 가만히 있는 상태로 다시 확인할 것.
- 개발 맥에 Xcode가 없고 Command Line Tools만 있으면 `swift test`가 `no such module 'XCTest'`로 실패한다. 이때는 XCTest 대용 모듈로 원본 테스트를 돌릴 수 있다 (레포 밖 스크래치에서). 코드 문제가 아니다.
- CLT가 깨졌으면(`SwiftBridging` 모듈 중복 정의, `libPackageDescription` 링크 실패) `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.

### 권한이 반복해서 묻는 문제 (해결됨: 고정 인증서)
ad-hoc 서명은 빌드마다 서명이 달라져서 설정에 스위치가 켜져 있어도 "손쉬운 사용 접근 권한" 팝업이 반복됐다. 개발 맥에 자체 서명 인증서 `NeckLock Dev`(로그인 키체인)를 만들어 해결했다. **항상 이 인증서로 빌드한다:**

```bash
SIGN_IDENTITY="NeckLock Dev" scripts/build-app.sh
```

- 지정 요구사항이 `certificate leaf = H"b32f390d..."`로 고정돼 빌드가 바뀌어도 권한이 유지된다 (연속 두 번 빌드로 확인).
- `security find-identity`에서 `CSSMERR_TP_NOT_TRUSTED`로 나와도 서명에는 문제없다.
- 인증서가 없는 맥에서는 README "문제 해결"의 절차로 만든다. 권한을 한 번 새로 받으려면 `tccutil reset Accessibility com.opensmartyouth.necklock` 후 앱 실행 → 허용 → 앱 재실행.

### 방치 경고(붉은 테두리) 디버깅
2026-10-14 사용자가 "붉은 테두리가 안 뜬다"고 재보고했다. 원인 후보: 잠금 쪽 타이머가 메뉴 조작 중 default 모드에서만 돌 수 있음 → common 모드로 변경, 상태 전환을 `os.Logger`로 남김, "각도 표시"를 켜면 `경고까지 N초`가 보이게 함. 아직 실기기 재확인 전이다. 확인할 때:

```bash
/usr/bin/log show --last 10m --info --predicate 'subsystem == "com.opensmartyouth.necklock"' --style compact
```
**주의: zsh의 `log`는 내장 명령이라 반드시 `/usr/bin/log`로 쓴다.** `방치 경고 켜짐` 로그가 있는데 화면에 안 보이면 창 문제, 로그가 없으면 판정/타이머 문제다.

## 먼저 할 일

1. 점이 얼굴 방향과 맞는지, 잠금 중 화면 어둡게·카메라 전환 버튼 동작, 20초 무동작 시 붉은 테두리가 뜨고 움직이면 꺼지는지 확인 (비상 해제 키를 먼저 확인).
2. 화면 잠금(⌃⌘Q) 중 지나간 정각의 보충 잠금을 실기기로 확인 (정각 직전 ⌃⌘Q → 같은 시간대 안에 풀기). 오늘 확인하려면 설정에서 업무 종료 시각을 늘려 정각이 오게 만든다.
3. 설정의 "각도 표시"를 켜고 목을 돌려보며 임계값 튜닝 (`RotationConfig`: yawRange 20°, pitchRange 12°, engage 1.0 / release 0.8).
4. `docs/PRD.md` §10 항목 확인: Vision pitch 정확도, ⌘Tab·전체화면 앱 위 동작, 다중 모니터(붉은 테두리 포함), 외장 웹캠.

## 지켜야 할 것

- **안전장치를 약화하지 말 것.** 입력을 막는 앱이라 버그가 나면 맥을 못 쓰게 된다. 비상 해제(⌃⌥⌘⇧+Esc), 최대 잠금 시간(기본 10분), fail-open(권한·카메라 없으면 잠그지 않음)은 유지한다. 잠금 동작을 테스트할 때는 항상 비상 해제 방법을 먼저 확인한다.
- `swift run`으로 실행하지 말 것. 카메라 권한 문구(Info.plist)가 없어서 종료된다. 항상 `.app`으로 실행.
- 빌드는 항상 `SIGN_IDENTITY="NeckLock Dev"`로 한다 (ad-hoc이면 권한이 초기화된다).

## 구조

| 경로 | 내용 |
|---|---|
| `Sources/NeckLockCore` | 플랫폼 독립 로직 (Foundation만): `WorkSchedule`, `LockClock`, `RotationTracker` |
| `Sources/NeckLock` | 메뉴바 앱: `AppDelegate`, `LockCoordinator`, `InputBlocker`(CGEventTap), `HeadPoseDetector`(AVFoundation+Vision), `LockView`, `SettingsView` |
| `Tests/NeckLockCoreTests` | 코어 단위 테스트 |

## 확정된 스펙

- 업무: 평일 09–17시, 점심 12–13시 제외, 해제 조건 2바퀴
- 얼굴 판별 없음 (누구 얼굴이든 동작만 판정)
- 카메라 실패 대응은 v1 범위 밖 (지금은 잠그지 않고 경고만)

## 사용자 확인이 필요한 미결 사항

- 12:00, 17:00 정각에 잠글지 → 현재 기본안은 **둘 다 안 잠금** (하루 5회: 10, 11, 14, 15, 16시)
- "오늘 하루 끄기"를 "오늘 남은 잠금 전부 건너뛰기"로 해석해서 구현함. 짧은 스누즈가 의도였다면 바꿔야 한다.

- (해결) 맥 화면 잠금 중 정각이 온 경우: 풀린 직후 **같은 시간대일 때만 보충**한다 (`LockMakeup`, `AppDelegate.makeUpSkippedLock`). 코어 테스트는 통과했고 실기기 확인은 전이다. "지금 테스트 잠금"은 화면 잠금 가드를 타지 않으므로 이 경로는 정각 트리거로만 확인된다.

## 작업 규칙

- 커밋은 작게, 메시지는 한국어 요약. 푸시는 `main`에 바로 해도 된다 (개인 프로젝트).
- 스펙이 바뀌면 `docs/PRD.md`도 같이 갱신한다.
