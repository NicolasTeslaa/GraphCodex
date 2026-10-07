import XCTest
@testable import GraphCodex

final class OfficeLayoutTests: XCTestCase {
    func testDepartmentPlacementIsStableAndKeepsSeparateIslands() {
        let first = group("verval", sessionIDs: ["a", "b"])
        let second = group("dose", sessionIDs: ["c"])

        let layoutA = OfficeSceneBuilder.layout(for: [first, second])
        let layoutB = OfficeSceneBuilder.layout(for: [second, first])

        XCTAssertEqual(layoutA["dose"]?.center, layoutB["dose"]?.center)
        XCTAssertEqual(layoutA["verval"]?.center, layoutB["verval"]?.center)
        XCTAssertGreaterThan(abs(layoutA["dose"]!.center.x - layoutA["verval"]!.center.x)
                             + abs(layoutA["dose"]!.center.z - layoutA["verval"]!.center.z), 10)
    }

    private func group(_ id: String, sessionIDs: [String]) -> ProjectGroup {
        let project = Project(id: id, name: id)
        let sessions = sessionIDs.map {
            CodexSession(id: $0, name: nil, cwd: "/work/\(id)", updatedAt: .distantPast,
                         state: .working, reason: nil, project: id, promptSummary: nil)
        }
        return ProjectGroup(project: project, sessions: sessions)
    }
}

final class CameraFramingTests: XCTestCase {
    func testReducedMotionRemovesCameraTransitionsAndLoops() {
        XCTAssertEqual(OfficeMotionPolicy.transitionDuration(reduceMotion: true), 0)
        XCTAssertEqual(OfficeMotionPolicy.transitionDuration(reduceMotion: false), 0.38)
        XCTAssertFalse(OfficeMotionPolicy.runsContinuousAnimations(reduceMotion: true))
        XCTAssertTrue(OfficeMotionPolicy.runsContinuousAnimations(reduceMotion: false))
    }

    func testOverviewShowsOfficeBoundsAndZoomHasSafeLimits() {
        XCTAssertEqual(OfficeCameraFraming.overviewScale(forMaximumDimension: 30), 30)
        XCTAssertEqual(OfficeCameraFraming.overviewScale(forMaximumDimension: 100), 100)
        XCTAssertEqual(OfficeCameraFraming.clampedScale(1), 8)
        XCTAssertEqual(OfficeCameraFraming.clampedScale(130), 100)
    }
}
