import AppKit
import ApplicationServices

/// CGEventTap으로 키보드·마우스 입력을 막는다. (손쉬운 사용 권한 필요)
///
/// - 화면은 덮지 않는다. 입력 이벤트만 버린다.
/// - 마우스는 `allowedRect`(잠금 창 영역) 안에서만 통과시킨다 → "오늘 하루 끄기" 버튼을 누를 수 있게.
/// - 비상 해제: ⌃⌥⌘⇧ + Esc.
/// - 안전장치: 메인 스레드가 멈추면 시스템이 탭을 꺼서 입력이 풀린다.
final class InputBlocker {
    /// 마우스를 통과시킬 영역. 전역 좌표계(주 모니터 좌상단 원점).
    var allowedRect: CGRect = .zero
    var onEmergency: (() -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var mouseDownInside = false

    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// 시스템 권한 요청 창을 띄운다.
    static func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// 탭을 시작한다. 권한이 없어서 만들지 못하면 false.
    func start() -> Bool {
        guard tap == nil else { return true }

        let blocked: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .scrollWheel, .mouseMoved,
        ]
        var mask: CGEventMask = 0
        for type in blocked {
            mask |= CGEventMask(1) << CGEventMask(type.rawValue)
        }
        mask |= CGEventMask(1) << 14 // NX_SYSDEFINED: 볼륨·밝기 등 특수 키

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: inputBlockerCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
        mouseDownInside = false
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        mouseDownInside = false
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            if isEmergency(event) {
                let handler = onEmergency
                DispatchQueue.main.async { handler?() }
            }
            return nil

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            mouseDownInside = allowedRect.contains(event.location)
            return mouseDownInside ? Unmanaged.passUnretained(event) : nil

        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
             .leftMouseUp, .rightMouseUp, .otherMouseUp:
            // 버튼을 누른 채 영역 밖으로 나가도 마우스 업은 통과시켜 눌림이 남지 않게 한다.
            return mouseDownInside ? Unmanaged.passUnretained(event) : nil

        case .mouseMoved, .scrollWheel:
            return allowedRect.contains(event.location) ? Unmanaged.passUnretained(event) : nil

        default:
            // keyUp, flagsChanged, 시스템 이벤트 등
            return nil
        }
    }

    private func isEmergency(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let required: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        return keyCode == 53 && event.flags.contains(required) // 53 = Esc
    }
}

private func inputBlockerCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<InputBlocker>.fromOpaque(userInfo).takeUnretainedValue()
    return blocker.handle(type: type, event: event)
}
