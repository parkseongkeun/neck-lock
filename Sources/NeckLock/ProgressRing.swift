import SwiftUI

/// 카메라 원 테두리의 진행 표시.
///
/// - 점: 지금 고개가 향한 방향 (테두리 위를 따라 움직인다).
/// - 선: 현재 바퀴의 진행량. 끝이 점을 따라가고 한 바퀴 = 360°.
/// - 옅게 채워진 링: 이미 끝낸 바퀴.
struct ProgressRing: View {
    let side: CGFloat
    let lapProgress: Double
    let completedLaps: Int
    /// +1 반시계, -1 시계, 0 없음 (수학 좌표 기준).
    let direction: Double
    let trailAngle: Double?
    let headAngle: Double?
    let isEngaged: Bool
    let completed: Bool

    /// Vision의 yaw·pitch 부호가 화면과 반대로 느껴지면 여기서 뒤집는다.
    /// 거울처럼 보이는 프리뷰 기준으로 "내가 오른쪽으로 돌리면 점도 오른쪽"이어야 한다.
    enum Orientation {
        static let flipHorizontal = false
        static let flipVertical = false
    }

    private let lineWidth: CGFloat = 10
    private var radius: CGFloat { (side - lineWidth) / 2 }
    private var tint: Color { completed ? .green : .accentColor }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: lineWidth)

            if completed || completedLaps > 0 {
                Circle()
                    .stroke(tint.opacity(completed ? 1 : 0.35), lineWidth: lineWidth)
            }

            if !completed, let end = trailAngle, lapProgress > 0 {
                TrailShape(end: end, length: lapProgress * 2 * .pi, direction: direction, radius: radius)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }

            if !completed, let head = headAngle {
                let p = Self.point(angle: head, radius: radius, in: side)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(tint, lineWidth: 3))
                    .frame(width: isEngaged ? 20 : 14, height: isEngaged ? 20 : 14)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .position(p)
                    .animation(.easeOut(duration: 0.08), value: isEngaged)
            }
        }
        .frame(width: side, height: side)
    }

    /// 수학 각도(+x 오른쪽, +y 위, 반시계 +)를 화면 각도로 바꾼다. 반전 설정 반영.
    static func screenAngle(_ a: Double) -> Double {
        var x = cos(a), y = sin(a)
        if Orientation.flipHorizontal { x = -x }
        if Orientation.flipVertical { y = -y }
        return atan2(y, x)
    }

    /// 중심이 (side/2, side/2)인 뷰 좌표 (y는 아래로 증가).
    static func point(angle: Double, radius: CGFloat, in side: CGFloat) -> CGPoint {
        let a = screenAngle(angle)
        return CGPoint(x: side / 2 + radius * CGFloat(cos(a)), y: side / 2 - radius * CGFloat(sin(a)))
    }
}

/// 끝점 `end`에서 `direction` 반대쪽으로 `length`만큼 뻗은 호.
struct TrailShape: Shape {
    let end: Double
    let length: Double
    let direction: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = max(2, Int((length / (.pi / 90)).rounded(.up)))   // 2°마다 한 점
        let sign = direction == 0 ? 1.0 : direction
        let cx = rect.midX, cy = rect.midY
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let a = ProgressRing.screenAngle(end - sign * length * (1 - t))
            let p = CGPoint(x: cx + radius * CGFloat(cos(a)), y: cy - radius * CGFloat(sin(a)))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
}
