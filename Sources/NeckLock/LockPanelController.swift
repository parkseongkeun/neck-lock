import AppKit
import AVFoundation
import SwiftUI

private final class LockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 비활성 상태에서도 첫 클릭이 바로 버튼에 전달되게 한다.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// 화면 가운데에 뜨는 작은 플로팅 창. 화면 전체를 덮지 않는다.
@MainActor
final class LockPanelController {
    private var panel: NSPanel?
    private let size = NSSize(width: 360, height: 640)

    /// 창을 띄우고, 창이 차지하는 영역을 전역 좌표(좌상단 원점)로 돌려준다.
    func show(model: LockViewModel, session: AVCaptureSession) -> CGRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )

        let panel = LockPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = FirstMouseHostingView(rootView: LockView(model: model, session: session))

        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel

        return Self.globalRect(for: panel.frame)
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func close(after delay: TimeInterval) {
        let closing = panel
        panel = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            closing?.orderOut(nil)
        }
    }

    /// AppKit 좌표(좌하단 원점) → CGEvent 전역 좌표(주 모니터 좌상단 원점).
    private static func globalRect(for frame: NSRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.maxY
        return CGRect(
            x: frame.minX,
            y: primaryHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}
