import Foundation

enum CameraMode: String, CaseIterable, Identifiable {
    case overview, orbit, firstPerson
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .orbit: "Orbit"
        case .firstPerson: "1ª pessoa"
        }
    }
}

enum OfficeCameraFraming {
    static let minimumScale: CGFloat = 8
    static let maximumScale: CGFloat = 42

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }

    static func overviewScale(forMaximumDimension dimension: Double) -> CGFloat {
        clampedScale(CGFloat(max(dimension, 16)))
    }
}

enum OfficeMotionPolicy {
    static func transitionDuration(reduceMotion: Bool) -> TimeInterval { reduceMotion ? 0 : 0.38 }
    static func runsContinuousAnimations(reduceMotion: Bool) -> Bool { !reduceMotion }
}

final class OfficeCameraController {
    private(set) var mode: CameraMode = .overview
    private(set) var scale: CGFloat = 30

    func setMode(_ mode: CameraMode) {
        self.mode = mode
        if mode == .overview { scale = OfficeCameraFraming.clampedScale(30) }
        if mode == .orbit { scale = OfficeCameraFraming.clampedScale(16) }
    }

    func zoom(by factor: CGFloat) {
        scale = OfficeCameraFraming.clampedScale(scale * factor)
    }
}
