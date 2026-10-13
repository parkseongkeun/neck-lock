import AppKit
import SwiftUI

/// 화면 가장자리에 붉은 빛이 천천히 맥동하는 경고. 화면 안쪽은 덮지 않고, 마우스·키 입력도 가로채지 않는다.
///
/// 광과민성을 고려해 한 주기를 1.6초로 둔다 (초당 3회 미만). 시스템 "동작 줄이기"가 켜져 있으면 맥동 없이 고정.
@MainActor
final class BorderAlarmController {
    private var windows: [NSWindow] = []
    private var previewTask: Task<Void, Never>?

    var isShowing: Bool { !windows.isEmpty }

    func show() {
        guard windows.isEmpty else { return }
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true   // 클릭·스크롤이 그대로 통과한다
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.contentView = NSHostingView(rootView: BorderGlow())
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            return window
        }
    }

    func hide() {
        previewTask?.cancel()
        previewTask = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }

    /// 설정·메뉴에서 모양을 미리 볼 때. 입력은 전혀 막지 않는다.
    func preview(seconds: TimeInterval = 6) {
        hide()
        show()
        previewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }
}

struct BorderGlow: View {
    private let period = 1.6
    private let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0.7 : 0.5 + 0.5 * sin(2 * .pi * t / period)   // 0...1
            let opacity = 0.35 + 0.55 * pulse

            ZStack {
                // 바깥으로 번지는 붉은 빛
                Rectangle()
                    .strokeBorder(Color.red, lineWidth: 46)
                    .blur(radius: 22)
                    .opacity(opacity)
                // 또렷한 가장자리 선
                Rectangle()
                    .strokeBorder(Color.red, lineWidth: 8)
                    .opacity(min(1, opacity + 0.1))
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
