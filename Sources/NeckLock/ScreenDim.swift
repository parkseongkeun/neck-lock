import AppKit

/// 잠금 중 모든 모니터를 반투명하게 어둡게 덮는다. 내용은 비쳐 보이고, 마우스·키 입력은 가로채지 않는다.
///
/// 카메라 창(`.screenSaver`)과 붉은 테두리보다 한 단계 아래 레벨이라 둘 다 이 위에 보인다.
@MainActor
final class ScreenDimController {
    private var windows: [NSWindow] = []
    private let opacity: CGFloat = 0.55

    func show() {
        guard windows.isEmpty else { return }
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
            window.hasShadow = false
            window.ignoresMouseEvents = true   // 클릭이 그대로 통과한다
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.alphaValue = 0
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                window.animator().alphaValue = 1
            }
            return window
        }
    }

    func hide() {
        let closing = windows
        windows = []
        closing.forEach { $0.orderOut(nil) }
    }
}
