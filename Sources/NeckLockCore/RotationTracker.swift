import Foundation

/// Vision이 준 머리 방향 (라디안).
public struct HeadPose: Equatable, Sendable {
    /// 좌우 회전 (y축).
    public var yaw: Double
    /// 상하 끄덕임 (x축).
    public var pitch: Double

    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }
}

public struct Vector2: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var length: Double { (x * x + y * y).squareRoot() }
}

public struct RotationConfig: Equatable, Codable, Sendable {
    /// 이 각도만큼 좌우로 돌리면 정규화 반지름 1.
    public var yawRange: Double
    /// 이 각도만큼 위아래로 숙이면 정규화 반지름 1. (상하는 좌우보다 덜 움직이므로 작게)
    public var pitchRange: Double
    /// 반지름이 이 값 이상이면 "충분히 돌린 상태"로 진입 → 각도 누적 시작.
    public var engageRadius: Double
    /// 진입 후 반지름이 이 값 아래로 떨어지면 해제 (깜빡임 방지용 히스테리시스).
    public var releaseRadius: Double
    /// 프레임 간 각도 변화가 이보다 크면 튐으로 보고 버린다.
    public var maxStep: Double
    /// 지수이동평균 계수 (0~1, 클수록 반응 빠름).
    public var smoothing: Double
    /// 해제에 필요한 바퀴 수.
    public var lapsRequired: Int

    public init(
        yawRange: Double = 20 * .pi / 180,
        pitchRange: Double = 12 * .pi / 180,
        engageRadius: Double = 1.0,
        releaseRadius: Double = 0.8,
        maxStep: Double = 75 * .pi / 180,
        smoothing: Double = 0.35,
        lapsRequired: Int = 2
    ) {
        self.yawRange = yawRange
        self.pitchRange = pitchRange
        self.engageRadius = engageRadius
        self.releaseRadius = releaseRadius
        self.maxStep = maxStep
        self.smoothing = smoothing
        self.lapsRequired = lapsRequired
    }
}

/// 고개 360° 회전 판정기.
///
/// 머리 방향을 2D 벡터 (yaw, pitch)로 보고, 이 벡터가 원점 둘레를 도는 각도를 누적한다.
/// - 충분히 크게 돌렸을 때(반지름 ≥ engageRadius)만 누적한다 → 원 중심을 가로지르는 동작은 인정 안 됨.
/// - 누적은 부호가 있다 → 좌우로 흔들기만 하면 서로 상쇄돼 진행되지 않는다.
/// - 방향(시계/반시계)은 무관하다. |누적 각도| ≥ 360° × 바퀴 수 이면 완료.
/// - Vision의 yaw·pitch 부호 규약과 무관하게 동작한다 (회전량만 보기 때문).
public struct RotationTracker: Sendable {
    public let config: RotationConfig
    /// 부호 있는 누적 회전량 (라디안).
    public private(set) var accumulated: Double = 0
    /// 평활화된 정규화 머리 방향. 얼굴이 없으면 nil.
    public private(set) var vector: Vector2?
    /// 지금 충분히 크게 돌린 상태인지.
    public private(set) var isEngaged = false
    /// 마지막으로 "충분히 돌린 상태"였을 때의 머리 방향 각도. 진행 선의 끝점으로 쓴다.
    /// 머리를 중앙으로 되돌려도 유지되고, 새 바퀴를 시작하면 갱신된다.
    public private(set) var trailAngle: Double?
    private var lastAngle: Double?

    private static let fullTurn = 2 * Double.pi

    /// 지금 머리가 가리키는 각도 (라디안). 수학 좌표: +x 오른쪽, +y 위, 반시계 방향이 +.
    /// 얼굴이 없으면 nil.
    public var headAngle: Double? {
        vector.map { atan2($0.y, $0.x) }
    }

    /// 진행 방향. +1 반시계, -1 시계, 0 아직 없음.
    public var direction: Double {
        accumulated > 0 ? 1 : (accumulated < 0 ? -1 : 0)
    }

    public init(config: RotationConfig = RotationConfig()) {
        self.config = config
    }

    public var isComplete: Bool {
        abs(accumulated) >= Self.fullTurn * Double(config.lapsRequired)
    }

    public var completedLaps: Int {
        min(max(0, config.lapsRequired), Int(abs(accumulated) / Self.fullTurn))
    }

    /// 현재 바퀴의 진행률 (0 ..< 1). 완료 시 1.
    public var lapProgress: Double {
        if isComplete { return 1 }
        let turns = abs(accumulated) / Self.fullTurn
        return turns - turns.rounded(.down)
    }

    /// 전체 진행률 (0 ... 1).
    public var totalProgress: Double {
        let needed = Self.fullTurn * Double(max(1, config.lapsRequired))
        return min(1, abs(accumulated) / needed)
    }

    /// 프레임마다 호출. 얼굴을 못 찾았으면 nil을 넘긴다 (진행률은 유지).
    public mutating func update(with pose: HeadPose?) {
        guard let pose else {
            vector = nil
            isEngaged = false
            lastAngle = nil
            return
        }

        let raw = Vector2(x: pose.yaw / config.yawRange, y: pose.pitch / config.pitchRange)
        let smoothed: Vector2
        if let previous = vector {
            let a = config.smoothing
            smoothed = Vector2(x: previous.x + a * (raw.x - previous.x),
                               y: previous.y + a * (raw.y - previous.y))
        } else {
            smoothed = raw
        }
        vector = smoothed

        let radius = smoothed.length
        if isEngaged {
            if radius < config.releaseRadius { isEngaged = false }
        } else if radius >= config.engageRadius {
            isEngaged = true
        }

        guard isEngaged else {
            lastAngle = nil
            return
        }

        let angle = atan2(smoothed.y, smoothed.x)
        if let last = lastAngle, !isComplete {
            let delta = Self.wrap(angle - last)
            if abs(delta) <= config.maxStep {
                accumulated += delta
            }
        }
        lastAngle = angle
        trailAngle = angle
    }

    /// (-π, π] 범위로 정규화.
    static func wrap(_ angle: Double) -> Double {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a <= -.pi { a += 2 * .pi }
        return a
    }
}
