// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NeckLock",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NeckLock", targets: ["NeckLock"]),
    ],
    targets: [
        // 플랫폼 독립 로직 (스케줄, 회전 판정). Foundation만 사용 → 어디서든 테스트 가능.
        .target(name: "NeckLockCore"),
        // macOS 메뉴바 앱 (AppKit, AVFoundation, Vision, SwiftUI).
        .executableTarget(
            name: "NeckLock",
            dependencies: ["NeckLockCore"]
        ),
        .testTarget(
            name: "NeckLockCoreTests",
            dependencies: ["NeckLockCore"]
        ),
    ]
)
