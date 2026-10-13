#!/bin/bash
# NeckLock.app 번들을 만든다.
#
# 사용법:
#   scripts/build-app.sh            # release 빌드 → build/NeckLock.app
#   scripts/build-app.sh debug      # debug 빌드
#   SIGN_IDENTITY="Apple Development: 이름 (TEAMID)" scripts/build-app.sh
#
# 서명 참고: 기본값은 ad-hoc 서명(-)이다. ad-hoc 서명은 빌드할 때마다 서명이 바뀌어서
# 카메라·손쉬운 사용 권한이 매번 초기화될 수 있다. 권한을 유지하려면 SIGN_IDENTITY로
# 고정된 인증서(Apple Development 또는 직접 만든 자체 서명 인증서)를 지정한다.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
IDENTITY="${SIGN_IDENTITY:--}"
APP="build/NeckLock.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NeckLock" "$APP/Contents/MacOS/NeckLock"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign "$IDENTITY" "$APP"

echo "✅ 빌드 완료: $APP"
echo "   실행: open $APP"
echo "   (카메라·손쉬운 사용 권한이 필요하다. 반드시 .app으로 실행할 것 — 'swift run'은 권한 창이 뜨지 않고 종료된다)"
