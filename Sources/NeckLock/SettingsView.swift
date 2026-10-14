import SwiftUI
import AVFoundation
import NeckLockCore

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    /// (표시 이름, Calendar 요일 번호). 월요일부터 표시.
    private let days: [(name: String, weekday: Int)] = [
        ("월", 2), ("화", 3), ("수", 4), ("목", 5), ("금", 6), ("토", 7), ("일", 1),
    ]

    var body: some View {
        Form {
            Section("업무 요일") {
                HStack {
                    ForEach(days, id: \.weekday) { day in
                        Toggle(day.name, isOn: weekdayBinding(day.weekday))
                            .toggleStyle(.button)
                    }
                }
            }

            Section("업무 시간") {
                Stepper("시작  \(settings.schedule.startHour)시", value: $settings.schedule.startHour, in: 0...23)
                Stepper("종료  \(settings.schedule.endHour)시", value: $settings.schedule.endHour, in: 1...24)
                Stepper("점심 시작  \(settings.schedule.lunchStartHour)시", value: $settings.schedule.lunchStartHour, in: 0...23)
                Stepper("점심 종료  \(settings.schedule.lunchEndHour)시", value: $settings.schedule.lunchEndHour, in: 0...24)
                Text(lockSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("스트레칭") {
                Stepper("해제에 필요한 바퀴 수  \(settings.laps)바퀴", value: $settings.laps, in: 1...5)
                Stepper(
                    settings.maxLockMinutes == 0
                        ? "최대 잠금 시간  제한 없음"
                        : "최대 잠금 시간  \(settings.maxLockMinutes)분",
                    value: $settings.maxLockMinutes,
                    in: 0...60
                )
                Text("이 시간이 지나면 잠금이 자동으로 풀려요. 비상 해제 단축키: ⌃⌥⌘⇧ + Esc")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("잠금 중 화면 어둡게", isOn: $settings.dimEnabled)
                Picker("카메라", selection: $settings.cameraID) {
                    Text("자동 (시스템 기본)").tag(String?.none)
                    ForEach(cameras, id: \.uniqueID) { camera in
                        Text(camera.localizedName).tag(Optional(camera.uniqueID))
                    }
                }
                Toggle("방치하면 화면 테두리가 붉게 깜빡임", isOn: $settings.nagEnabled)
                Text("잠긴 뒤 20초 동안 고개를 안 돌리면 켜져요. 클릭·입력은 막지 않아요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("개발") {
                Toggle("잠금 창에 각도 표시 (민감도 튜닝용)", isOn: $settings.debugOverlay)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 740)
    }

    private var cameras: [AVCaptureDevice] { HeadPoseDetector.availableCameras() }

    private var lockSummary: String {
        let hours = settings.schedule.lockHours
        guard !hours.isEmpty else { return "잠금 시각 없음" }
        return "잠금 시각: " + hours.map { "\($0)시" }.joined(separator: " · ")
    }

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { settings.schedule.weekdays.contains(weekday) },
            set: { isOn in
                if isOn {
                    settings.schedule.weekdays.insert(weekday)
                } else {
                    settings.schedule.weekdays.remove(weekday)
                }
            }
        )
    }
}
