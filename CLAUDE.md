# Neck Lock — Claude Code 인수인계

거북목 방지용 macOS 메뉴바 앱. 업무 시간 매시 정각에 키보드·마우스 입력을 잠그고, 카메라 앞에서 고개를 360° 2바퀴 돌려야 해제된다. 화면은 덮지 않는다. 본인 맥 전용 (App Store 배포 안 함).

스펙은 `docs/PRD.md`, 사용법은 `README.md`. 사용자는 한국어로 소통하고, 구조화된 결과를 선호한다. 보고는 짧게, 한 일과 다음 할 일만.

## 현재 상태 (중요)

macOS에서 컴파일·`.app` 빌드·코어 테스트(27개)까지 확인했다. **카메라 인식과 입력 차단은 실기기에서 아직 돌려보지 않았다.**
- 개발 맥에 Xcode가 없고 Command Line Tools만 있으면 `swift test`가 `no such module 'XCTest'`로 실패한다. 이때는 XCTest 대용 모듈로 원본 테스트를 돌릴 수 있다 (레포 밖 스크래치에서). 코드 문제가 아니다.
- CLT가 깨졌으면(`SwiftBridging` 모듈 중복 정의, `libPackageDescription` 링크 실패) `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.
- 고개 방향 점·진행 선(`ProgressRing`)의 좌우·상하 방향은 Vision 부호 규약에 따라 반대일 수 있다. 실기기에서 점이 거울처럼 어긋나면 `ProgressRing.Orientation`의 `flipHorizontal`/`flipVertical`을 뒤집는다.
- 방치 경고(붉은 테두리, `BorderAlarm`·`StretchNag`)는 모양만 미리보기로 확인했다. 잠금 중 20초 무동작 → 켜짐 흐름은 실기기 확인 전이다.

## 먼저 할 일

1. 손쉬운 사용·카메라 권한 허용 → 메뉴바 "지금 테스트 잠금"으로 동작 확인 (비상 해제 키를 먼저 확인).
2. 점이 얼굴 방향과 맞는지, 20초 무동작 시 붉은 테두리가 뜨고 움직이면 꺼지는지 확인.
3. 설정의 "각도 표시"를 켜고 목을 돌려보며 임계값 튜닝 (`RotationConfig`: yawRange 20°, pitchRange 12°, engage 1.0 / release 0.8).
4. `docs/PRD.md` §10 항목 확인: Vision pitch 정확도, ⌘Tab·전체화면 앱 위 동작, 다중 모니터(붉은 테두리 포함), 외장 웹캠.

## 지켜야 할 것

- **안전장치를 약화하지 말 것.** 입력을 막는 앱이라 버그가 나면 맥을 못 쓰게 된다. 비상 해제(⌃⌥⌘⇧+Esc), 최대 잠금 시간(기본 10분), fail-open(권한·카메라 없으면 잠그지 않음)은 유지한다. 잠금 동작을 테스트할 때는 항상 비상 해제 방법을 먼저 확인한다.
- `swift run`으로 실행하지 말 것. 카메라 권한 문구(Info.plist)가 없어서 종료된다. 항상 `.app`으로 실행.
- ad-hoc 서명은 빌드마다 권한이 초기화될 수 있다. 계속 개발하려면 `SIGN_IDENTITY`로 고정 인증서를 쓴다.

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

## 작업 규칙

- 커밋은 작게, 메시지는 한국어 요약. 푸시는 `main`에 바로 해도 된다 (개인 프로젝트).
- 스펙이 바뀌면 `docs/PRD.md`도 같이 갱신한다.
