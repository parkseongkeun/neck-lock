import AppKit
import SwiftUI
import Combine
import ServiceManagement
import UserNotifications
import NeckLockCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private let coordinator = LockCoordinator()

    private var clock: LockClock!
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var screenLocked = false
    private var statusIssue: String?

    private var statusItem: NSStatusItem!
    private var nextItem = NSMenuItem()
    private var issueItem = NSMenuItem()
    private var skipItem = NSMenuItem()
    private var loginItem = NSMenuItem()
    private var settingsWindow: NSWindow?

    // MARK: - 시작

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        clock = LockClock(schedule: settings.schedule, now: Date())
        setupStatusItem()

        // 첫 실행 때 권한 창이 뜨도록 미리 요청한다. (잠금 도중에 뜨면 곤란하다)
        HeadPoseDetector.requestAccess { _ in }
        if !InputBlocker.hasPermission { InputBlocker.requestPermission() }
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }

        settings.$schedule
            .dropFirst()
            .sink { [weak self] schedule in
                guard let self else { return }
                self.clock.update(schedule: schedule, now: Date())
                self.refreshMenu()
            }
            .store(in: &cancellables)

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.screenLocked = true }
        }
        distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.screenLocked = false }
        }
        NotificationCenter.default.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.clock.reschedule(now: Date())
                self.refreshMenu()
            }
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        refreshMenu()
    }

    // MARK: - 스케줄

    private func tick() {
        let now = Date()
        switch clock.tick(now: now) {
        case .wait:
            break
        case .missed:
            refreshMenu()
        case .fire:
            handleFire(now: now)
            refreshMenu()
        }
    }

    private func handleFire(now: Date) {
        guard !DaySkip.isSkipped(settings.skippedDay, on: now) else { return }
        guard !screenLocked, !coordinator.isLocked else { return }
        startLock()
    }

    private func startLock() {
        let result = coordinator.start(settings: settings) { [weak self] reason in
            guard let self else { return }
            if reason == .skippedToday { self.settings.skippedDay = Date() }
            self.refreshMenu()
        }

        switch result {
        case .started:
            statusIssue = nil
        case .needsAccessibility:
            statusIssue = "⚠️ 손쉬운 사용 권한이 필요해요"
            notify("손쉬운 사용 권한이 필요해요",
                   "시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 NeckLock을 켜주세요.")
        case .needsCamera:
            statusIssue = "⚠️ 카메라를 쓸 수 없어요"
            notify("카메라를 쓸 수 없어요",
                   "카메라 권한을 허용했는지, 카메라가 연결돼 있는지 확인해주세요. 이번 잠금은 건너뛰었어요.")
        }
        refreshMenu()
    }

    private func notify(_ title: String, _ body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - 메뉴바

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "figure.mind.and.body", accessibilityDescription: "NeckLock")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self

        nextItem.isEnabled = false
        menu.addItem(nextItem)

        issueItem.isEnabled = false
        issueItem.isHidden = true
        menu.addItem(issueItem)

        menu.addItem(.separator())

        let test = NSMenuItem(title: "지금 테스트 잠금", action: #selector(testLock), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        let previewNag = NSMenuItem(title: "붉은 테두리 미리보기", action: #selector(previewNagAlarm), keyEquivalent: "")
        previewNag.target = self
        menu.addItem(previewNag)

        skipItem.action = #selector(toggleSkipToday)
        skipItem.target = self
        menu.addItem(skipItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        loginItem.title = "로그인 시 자동 실행"
        loginItem.action = #selector(toggleLaunchAtLogin)
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "NeckLock 종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenu()
    }

    private func refreshMenu() {
        nextItem.title = nextLockDescription()

        issueItem.title = statusIssue ?? ""
        issueItem.isHidden = statusIssue == nil

        skipItem.title = DaySkip.isSkipped(settings.skippedDay, on: Date())
            ? "오늘 다시 켜기"
            : "오늘 하루 끄기"

        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    /// "오늘 하루 끄기" 상태까지 반영한 다음 잠금 시각.
    private func effectiveNextLock() -> Date? {
        let now = Date()
        let calendar = Calendar.current
        var from = now
        if DaySkip.isSkipped(settings.skippedDay, on: now),
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            from = tomorrow.addingTimeInterval(-1)
        }
        return settings.schedule.nextLock(after: from)
    }

    private func nextLockDescription() -> String {
        guard let next = effectiveNextLock() else { return "다음 잠금: 없음" }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        if calendar.isDateInToday(next) {
            formatter.dateFormat = "HH:mm"
            return "다음 잠금: 오늘 " + formatter.string(from: next)
        }
        formatter.dateFormat = "M월 d일 (E) HH:mm"
        return "다음 잠금: " + formatter.string(from: next)
    }

    // MARK: - 메뉴 동작

    @objc private func testLock() {
        startLock()
    }

    @objc private func previewNagAlarm() {
        coordinator.previewAlarm()
    }

    @objc private func toggleSkipToday() {
        if DaySkip.isSkipped(settings.skippedDay, on: Date()) {
            settings.skippedDay = nil
        } else {
            settings.skippedDay = Date()
        }
        refreshMenu()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: controller)
            window.title = "NeckLock 설정"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            statusIssue = nil
        } catch {
            statusIssue = "⚠️ 로그인 항목 설정 실패: \(error.localizedDescription)"
        }
        refreshMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
