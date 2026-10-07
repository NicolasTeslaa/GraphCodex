import AppKit
import CoreGraphics
import SceneKit
import SwiftUI

/// Procedural, repeatable appearance palette: every station gets a distinct set of colors
/// and the geometry details vary independently from its current work state.
private struct AvatarStyle {
    let skin: UInt32
    let hair: UInt32
    let shirt: UInt32
    let trousers: UInt32
    let shoes: UInt32
    let eye: UInt32
    let mouth: UInt32
    let accessory: UInt32
    let hairStyle: Int
    let faceShape: Float
    let hasGlasses: Bool
    let hasBeard: Bool

    init(index: Int, salt: String = "") {
        var seed = UInt64(bitPattern: Int64(index &* 7919 &+ salt.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }))
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(UInt64.max >> 11)
        }
        func color(hue: Double, saturation: Double, lightness: Double) -> UInt32 {
            let h = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
            let c = (1 - abs(2 * lightness - 1)) * saturation
            let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
            let (r1, g1, b1): (Double, Double, Double)
            switch Int(h) {
            case 0: (r1, g1, b1) = (c, x, 0)
            case 1: (r1, g1, b1) = (x, c, 0)
            case 2: (r1, g1, b1) = (0, c, x)
            case 3: (r1, g1, b1) = (0, x, c)
            case 4: (r1, g1, b1) = (x, 0, c)
            default: (r1, g1, b1) = (c, 0, x)
            }
            let m = lightness - c / 2
            return (UInt32((r1 + m) * 255) << 16) | (UInt32((g1 + m) * 255) << 8) | UInt32((b1 + m) * 255)
        }

        let hue = next()
        skin = color(hue: 0.055 + next() * 0.065, saturation: 0.25 + next() * 0.36, lightness: 0.43 + next() * 0.31)
        hair = color(hue: hue, saturation: 0.26 + next() * 0.52, lightness: 0.15 + next() * 0.25)
        shirt = color(hue: hue + 0.19 + next() * 0.18, saturation: 0.58 + next() * 0.32, lightness: 0.39 + next() * 0.2)
        trousers = color(hue: hue + 0.42, saturation: 0.28 + next() * 0.33, lightness: 0.2 + next() * 0.16)
        shoes = color(hue: hue + 0.63, saturation: 0.18 + next() * 0.42, lightness: 0.55 + next() * 0.22)
        eye = color(hue: hue + 0.11, saturation: 0.25, lightness: 0.12)
        mouth = color(hue: 0.94 + next() * 0.07, saturation: 0.34, lightness: 0.46)
        accessory = color(hue: hue + 0.55, saturation: 0.7, lightness: 0.72)
        hairStyle = Int(next() * 8)
        faceShape = Float(next())
        hasGlasses = next() > 0.62
        hasBeard = next() > 0.58
    }
}

/// Isometric, interactive office map. SceneKit keeps the room and the agents animated
/// while their identity and state continue to come from the local Codex monitor.
struct Office3DView: NSViewRepresentable {
    let groups: [ProjectGroup]
    let selectedSessionID: String?
    let selectedProjectID: String?
    let cameraMode: CameraMode
    let reduceMotion: Bool
    let onSelect: (CodexSession) -> Void
    let onOpen: (CodexSession) -> Void
    let onSelectProject: (Project) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> OfficeSceneView {
        let view = OfficeSceneView(frame: .zero)
        view.backgroundColor = NSColor(hex: 0x1C2030)
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        // Camera framing is local to the player; SceneKit's automatic controller frames
        // the whole room and would pull the view away from the avatar.
        view.allowsCameraControl = false
        view.isPlaying = OfficeMotionPolicy.runsContinuousAnimations(reduceMotion: reduceMotion)
        view.preferredFramesPerSecond = 30
        view.rendersContinuously = true
        view.onZoom = { [weak coordinator = context.coordinator] amount in coordinator?.zoomCamera(by: amount) }
        view.onOrbit = { [weak coordinator = context.coordinator] deltaX, deltaY in
            coordinator?.orbitCamera(deltaX: deltaX, deltaY: deltaY)
        }
        view.onToggleCamera = { [weak coordinator = context.coordinator] in coordinator?.toggleCameraMode() }
        view.onCameraMode = { [weak coordinator = context.coordinator] mode in coordinator?.setCameraMode(mode) }

        let singleClick = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didClick(_:)))
        singleClick.numberOfClicksRequired = 1
        let doubleClick = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didDoubleClick(_:)))
        doubleClick.numberOfClicksRequired = 2
        view.addGestureRecognizer(singleClick)
        view.addGestureRecognizer(doubleClick)

        context.coordinator.view = view
        context.coordinator.onSelect = onSelect
        context.coordinator.onOpen = onOpen
        context.coordinator.onSelectProject = onSelectProject
        context.coordinator.reduceMotion = reduceMotion
        view.onMovementKey = { [weak coordinator = context.coordinator] keyCode, isPressed in
            coordinator?.setMovementKey(keyCode, isPressed: isPressed)
        }
        context.coordinator.synchronize(groups, selectedID: selectedSessionID, selectedProjectID: selectedProjectID)
        context.coordinator.setCameraMode(cameraMode, animated: false)
        view.scene?.rootNode.isPaused = reduceMotion
        view.onLayout = { [weak coordinator = context.coordinator] in coordinator?.updateCameraFraming() }
        return view
    }

    func updateNSView(_ view: OfficeSceneView, context: Context) {
        context.coordinator.view = view
        context.coordinator.onSelect = onSelect
        context.coordinator.onOpen = onOpen
        context.coordinator.onSelectProject = onSelectProject
        context.coordinator.reduceMotion = reduceMotion
        view.isPlaying = OfficeMotionPolicy.runsContinuousAnimations(reduceMotion: reduceMotion)
        view.scene?.rootNode.isPaused = reduceMotion
        context.coordinator.synchronize(groups, selectedID: selectedSessionID, selectedProjectID: selectedProjectID)
        view.scene?.rootNode.isPaused = reduceMotion
        if context.coordinator.cameraMode != cameraMode { context.coordinator.setCameraMode(cameraMode) }
        context.coordinator.updateCameraFraming()
    }

    final class Coordinator: NSObject {
        weak var view: OfficeSceneView?
        var onSelect: ((CodexSession) -> Void)?
        var onOpen: ((CodexSession) -> Void)?
        var onSelectProject: ((Project) -> Void)?
        private var latestGroups: [String: ProjectGroup] = [:]
        private var latestSessions: [String: CodexSession] = [:]
        private var sessionRoots: [String: SCNNode] = [:]
        private var selectionRings: [String: SCNNode] = [:]
        private var signature = ""
        private var renderedStates: [String: SessionState] = [:]
        private var boardContentSignatures: [String: String] = [:]
        private var roomWidth: Float = 18
        private var roomDepth: Float = 14
        private var departmentCenters: [String: SCNVector3] = [:]
        private var departmentRoots: [String: SCNNode] = [:]
        private var departmentFootprints: [String: DepartmentFootprint] = [:]
        private var currentSelectedID: String?
        private var currentSelectedProjectID: String?
        private var lastCameraAspect: Float?
        private var cameraZoom: CGFloat = 30
        private var firstPersonFieldOfView: CGFloat = 68
        private var cameraYaw: Float = 0
        private var cameraPitch: Float = 0.94
        private var firstPersonYaw: Float = 0
        private var firstPersonPitch: Float = -0.08
        var cameraMode: CameraMode = .overview
        var reduceMotion = false
        private var isFirstPerson: Bool { cameraMode == .firstPerson }
        private var cameraDistance: Float = 26
        private var stationApproaches: [String: SCNVector3] = [:]
        private var playerRoot: SCNNode?
        private var playerAvatar: SCNNode?
        private var playerFacingYaw: Float = 0
        private var playerPosition = SCNVector3(0, 0, 0)
        private var pressedKeys: Set<UInt16> = []
        private var runningKeys: Set<UInt16> = []
        private var movementTimer: Timer?
        private var lastTriggeredSessionID: String?

        func synchronize(_ groups: [ProjectGroup], selectedID: String?, selectedProjectID: String?) {
            latestGroups = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
            let sessions = groups.flatMap(\.sessions)
            latestSessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
            let nextSignature = groups.map { group in
                "\(group.id)|\(group.project.name)|\(group.project.colorHex)|" + group.sessions.map { "\($0.id)|\($0.displayName)|\($0.state.rawValue)" }.joined(separator: ",")
            }.joined(separator: "\n")
            if signature != nextSignature {
                signature = nextSignature
                render(groups)
            } else {
                for session in sessions where renderedStates[session.id] != session.state {
                    transition(session, animated: true)
                }
            }
            updateActivityBoards(sessions)
            setSelected(selectedID)
            setSelectedProject(selectedProjectID)
        }

        private func render(_ groups: [ProjectGroup]) {
            guard let view else { return }
            let sessions = groups.flatMap(\.sessions)
            let previousPlayerPosition = playerRoot == nil ? nil : playerPosition
            let footprints = OfficeSceneBuilder.layout(for: groups)
            departmentFootprints = footprints
            let width = footprints.values.map { abs($0.center.x) + $0.width / 2 }.max() ?? 16
            let depth = footprints.values.map { abs($0.center.z) + $0.depth / 2 }.max() ?? 16
            roomWidth = Float(max(20, width * 2 + 8))
            roomDepth = Float(max(20, depth * 2 + 8))
            let tileSize: Float = 6
            let gridColumns = max(3, Int(ceil(roomWidth / tileSize)))
            let gridRows = max(3, Int(ceil(roomDepth / tileSize)))

            let scene = SCNScene()
            scene.background.contents = NSColor(hex: 0x1C2030)
            view.scene = scene
            sessionRoots.removeAll(keepingCapacity: true)
            selectionRings.removeAll(keepingCapacity: true)
            stationApproaches.removeAll(keepingCapacity: true)
            departmentCenters.removeAll(keepingCapacity: true)
            departmentRoots.removeAll(keepingCapacity: true)
            boardContentSignatures.removeAll(keepingCapacity: true)
            renderedStates = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.state) })

            addLights(to: scene)
            addRoom(to: scene, columns: gridColumns, rows: gridRows, tileSize: tileSize)

            let stableIDs = sessions.map(\.id).sorted()
            let styleIndices = Dictionary(uniqueKeysWithValues: stableIDs.enumerated().map { ($0.element, $0.offset) })
            for group in groups {
                guard let footprint = footprints[group.id] else { continue }
                let department = DepartmentNodeBuilder.build(project: group.project, footprint: footprint)
                scene.rootNode.addChildNode(department)
                departmentRoots[group.id] = department
                let center = SCNVector3(Float(footprint.center.x), 0, Float(footprint.center.z))
                departmentCenters[group.id] = center
                for session in group.sessions {
                    guard let local = StationNodeBuilder.position(sessionID: session.id, in: footprint) else { continue }
                    let x = center.x + CGFloat(local.x)
                    let z = center.z + CGFloat(local.z)
                    let style = AvatarStyle(index: styleIndices[session.id] ?? 0, salt: group.id)
                    let root = makeAgent(for: session, style: style)
                    root.name = "session:\(session.id)"
                    root.position = SCNVector3(x, 0, z)
                    scene.rootNode.addChildNode(root)
                    sessionRoots[session.id] = root
                    stationApproaches[session.id] = SCNVector3(x, 0, z + 3.2)
                    addPlant(at: SCNVector3(x + 2.5, 0, z + 1.7), to: scene)
                }
                if group.sessions.contains(where: AttentionZoneBuilder.contains) {
                    addAttentionMarker(for: group, footprint: footprint, to: department)
                }
            }

            if let previousPlayerPosition {
                playerPosition = SCNVector3(
                    min(max(Float(previousPlayerPosition.x), -roomWidth / 2 + 1), roomWidth / 2 - 1),
                    0,
                    min(max(Float(previousPlayerPosition.z), -roomDepth / 2 + 1), roomDepth / 2 - 1)
                )
            } else {
                playerPosition = SCNVector3(0, 0, Float(depth) + tileSize)
            }
            let player = SCNNode()
            player.name = "local.player"
            player.position = playerPosition
            playerRoot = player
            playerAvatar = addAvatar(to: player, style: AvatarStyle(index: sessions.count, salt: "local-player"))
            playerAvatar?.eulerAngles.y = CGFloat(playerFacingYaw)
            addPlayerNameplate(to: player)
            playerAvatar?.isHidden = isFirstPerson
            player.childNode(withName: "player.nameplate", recursively: false)?.isHidden = isFirstPerson
            if !pressedKeys.isEmpty { setWalkingAnimation(true) }
            scene.rootNode.addChildNode(player)

            let cameraNode = SCNNode()
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            camera.zNear = 0.1
            camera.zFar = 500
            cameraNode.camera = camera
            cameraNode.name = "office.camera"
            scene.rootNode.addChildNode(cameraNode)
            view.pointOfView = cameraNode
            view.isFirstPersonCamera = isFirstPerson
            if cameraMode == .overview {
                let maximumDimension = max(Double(roomWidth), Double(roomDepth))
                cameraZoom = OfficeCameraFraming.overviewScale(forMaximumDimension: maximumDimension)
            }
            lastCameraAspect = nil
            updateCameraFraming()
        }

        func updateCameraFraming() {
            guard let view, let cameraNode = view.pointOfView, let camera = cameraNode.camera else { return }
            let aspect = max(Float(view.bounds.width / max(view.bounds.height, 1)), 0.7)
            guard lastCameraAspect == nil || abs(lastCameraAspect! - aspect) > 0.015 else { return }
            lastCameraAspect = aspect
            camera.usesOrthographicProjection = !isFirstPerson
            if isFirstPerson {
                camera.fieldOfView = firstPersonFieldOfView
            } else {
                camera.orthographicScale = cameraZoom
            }
            positionCamera(cameraNode, focus: playerPosition)
        }

        func toggleCameraMode() {
            setCameraMode(isFirstPerson ? .overview : .firstPerson)
        }

        func setCameraMode(_ mode: CameraMode, animated: Bool = true) {
            guard let cameraNode = view?.pointOfView, let camera = cameraNode.camera else {
                cameraMode = mode
                return
            }
            cameraMode = mode
            switch mode {
            case .overview:
                cameraPitch = 0.94
                cameraDistance = 26
                cameraZoom = OfficeCameraFraming.overviewScale(forMaximumDimension: max(Double(roomWidth), Double(roomDepth)))
            case .orbit:
                cameraPitch = 0.72
                cameraDistance = 17
                cameraZoom = OfficeCameraFraming.clampedScale(16)
            case .firstPerson:
                cameraDistance = 3
            }
            let focus = cameraFocusPosition
            if animated {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = OfficeMotionPolicy.transitionDuration(reduceMotion: reduceMotion)
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            }
            camera.usesOrthographicProjection = !isFirstPerson
            if isFirstPerson {
                camera.fieldOfView = firstPersonFieldOfView
                playerAvatar?.isHidden = true
                view?.scene?.rootNode.childNode(withName: "local.player", recursively: false)?
                    .childNode(withName: "player.nameplate", recursively: false)?.isHidden = true
            } else {
                camera.orthographicScale = cameraZoom
                playerAvatar?.isHidden = false
                view?.scene?.rootNode.childNode(withName: "local.player", recursively: false)?
                    .childNode(withName: "player.nameplate", recursively: false)?.isHidden = false
            }
            view?.isFirstPersonCamera = isFirstPerson
            view?.setPointerCaptured(isFirstPerson || !pressedKeys.isEmpty)
            positionCamera(cameraNode, focus: focus)
            if animated { SCNTransaction.commit() }
        }

        func zoomCamera(by amount: CGFloat) {
            guard let camera = view?.pointOfView?.camera else { return }
            if isFirstPerson {
                firstPersonFieldOfView = min(max(firstPersonFieldOfView - amount * 4, 35), 100)
                camera.fieldOfView = firstPersonFieldOfView
            } else {
                cameraZoom = OfficeCameraFraming.clampedScale(cameraZoom * CGFloat(pow(0.9, Double(amount))))
                camera.orthographicScale = cameraZoom
            }
        }

        func orbitCamera(deltaX: CGFloat, deltaY: CGFloat) {
            if isFirstPerson {
                firstPersonYaw += Float(deltaX) * 0.004
                // Match FPS controls: moving the mouse upward looks upward.
                firstPersonPitch = min(max(firstPersonPitch - Float(deltaY) * 0.004, -1.0), 1.0)
            } else {
                cameraYaw -= Float(deltaX) * 0.004
                cameraPitch = min(max(cameraPitch + Float(deltaY) * 0.004, 0.15), 1.35)
            }
            if let cameraNode = view?.pointOfView { positionCamera(cameraNode, focus: cameraFocusPosition) }
        }

        private var cameraFocusPosition: SCNVector3 {
            if let selectedProjectID = currentSelectedProjectID, let center = departmentCenters[selectedProjectID] { return center }
            if let currentSelectedID, let root = sessionRoots[currentSelectedID] { return root.position }
            return SCNVector3Zero
        }

        private func positionCamera(_ cameraNode: SCNNode, focus: SCNVector3) {
            if isFirstPerson {
                cameraNode.position = SCNVector3(Float(focus.x), 1.68, Float(focus.z) + 0.15)
                // Set a fresh camera rotation from angles instead of looking from the
                // previous transform. This avoids roll accumulating after mode switches.
                cameraNode.eulerAngles = SCNVector3(firstPersonPitch, -firstPersonYaw, 0)
                return
            }
            let horizontalDistance = cameraDistance * cos(cameraPitch)
            let x = Float(focus.x) + sin(cameraYaw) * horizontalDistance
            let z = Float(focus.z) + cos(cameraYaw) * horizontalDistance
            let y = 0.7 + cameraDistance * sin(cameraPitch)
            cameraNode.position = SCNVector3(x, y, z)
            cameraNode.look(
                at: SCNVector3(Float(focus.x), 0.7, Float(focus.z)),
                up: SCNVector3(0, 1, 0),
                localFront: SCNVector3(0, 0, -1)
            )
        }

        private func setSelected(_ id: String?) {
            currentSelectedID = id
            for (sessionID, ring) in selectionRings {
                ring.isHidden = sessionID != id
            }
        }

        private func setSelectedProject(_ id: String?) {
            guard currentSelectedProjectID != id else { return }
            currentSelectedProjectID = id
            for (projectID, node) in departmentRoots {
                node.opacity = projectID == id ? 1 : 0.84
            }
            guard id != nil, let camera = view?.pointOfView else { return }
            if cameraMode == .overview { setCameraMode(.orbit) }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = OfficeMotionPolicy.transitionDuration(reduceMotion: reduceMotion)
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            positionCamera(camera, focus: cameraFocusPosition)
            SCNTransaction.commit()
        }

        func setMovementKey(_ keyCode: UInt16, isPressed: Bool) {
            if keyCode == 56 || keyCode == 60 { // Left / right Shift
                let wasRunning = !runningKeys.isEmpty
                if isPressed { runningKeys.insert(keyCode) } else { runningKeys.remove(keyCode) }
                if wasRunning != !runningKeys.isEmpty, !pressedKeys.isEmpty {
                    setWalkingAnimation(false)
                    setWalkingAnimation(true)
                }
                return
            }
            let movementKeys: Set<UInt16> = [0, 1, 2, 13, 123, 124, 125, 126]
            guard movementKeys.contains(keyCode) else { return }

            if isPressed {
                pressedKeys.insert(keyCode)
                view?.setPointerCaptured(true)
                startMovementTimerIfNeeded()
                setWalkingAnimation(true)
            } else {
                pressedKeys.remove(keyCode)
                if pressedKeys.isEmpty {
                    movementTimer?.invalidate()
                    movementTimer = nil
                    setWalkingAnimation(false)
                    view?.setPointerCaptured(isFirstPerson)
                }
            }
        }

        private func startMovementTimerIfNeeded() {
            guard movementTimer == nil else { return }
            movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.advancePlayer()
            }
        }

        private func advancePlayer() {
            var horizontal: Float = 0
            var forward: Float = 0
            if pressedKeys.contains(0) || pressedKeys.contains(123) { horizontal -= 1 } // A / ←
            if pressedKeys.contains(2) || pressedKeys.contains(124) { horizontal += 1 } // D / →
            if pressedKeys.contains(13) || pressedKeys.contains(126) { forward += 1 } // W / ↑
            if pressedKeys.contains(1) || pressedKeys.contains(125) { forward -= 1 } // S / ↓
            var dx = horizontal
            var dz = -forward
            if isFirstPerson {
                dx = horizontal * cos(firstPersonYaw) + forward * sin(firstPersonYaw)
                dz = horizontal * sin(firstPersonYaw) - forward * cos(firstPersonYaw)
            }
            guard dx != 0 || dz != 0, let playerRoot else { return }

            let length: Float = (dx * dx + dz * dz).squareRoot()
            let speed: Float = runningKeys.isEmpty ? 5.2 : 10.4
            let step = speed / 60.0
            dx = dx / length * step
            dz = dz / length * step

            let oldX = Float(playerPosition.x)
            let oldZ = Float(playerPosition.z)
            let newX = min(max(oldX + dx, -roomWidth / 2 + 1), roomWidth / 2 - 1)
            let newZ = min(max(oldZ + dz, -roomDepth / 2 + 1), roomDepth / 2 - 1)
            playerPosition = SCNVector3(newX, 0, newZ)
            playerRoot.position = playerPosition
            playerFacingYaw = atan2(dx, dz)
            playerAvatar?.eulerAngles.y = CGFloat(playerFacingYaw)

            // Keep the local avatar on screen as it explores the larger office.
            if let camera = view?.pointOfView {
                positionCamera(camera, focus: playerPosition)
            }

            visitNearbySessionIfNeeded()
        }

        private func visitNearbySessionIfNeeded() {
            for (id, target) in stationApproaches {
                let dx = Float(playerPosition.x) - Float(target.x)
                let dz = Float(playerPosition.z) - Float(target.z)
                let distance = sqrt(dx * dx + dz * dz)
                if distance < 1.8, id != lastTriggeredSessionID, let session = latestSessions[id] {
                    lastTriggeredSessionID = id
                    pressedKeys.removeAll()
                    movementTimer?.invalidate()
                    movementTimer = nil
                    setWalkingAnimation(false)
                    view?.setPointerCaptured(isFirstPerson)
                    onSelect?(session)
                    return
                }
            }

            if let lastTriggeredSessionID, let target = stationApproaches[lastTriggeredSessionID] {
                let dx = Float(playerPosition.x) - Float(target.x)
                let dz = Float(playerPosition.z) - Float(target.z)
                if sqrt(dx * dx + dz * dz) > 4.2 { self.lastTriggeredSessionID = nil }
            }
        }

        private func setWalkingAnimation(_ isWalking: Bool) {
            guard let playerAvatar else { return }
            if isWalking {
                let bounceHalfCycle: TimeInterval = runningKeys.isEmpty ? 0.18 : 0.09
                let bounce = SCNAction.sequence([
                    .moveBy(x: 0, y: 0.045, z: 0, duration: bounceHalfCycle),
                    .moveBy(x: 0, y: -0.045, z: 0, duration: bounceHalfCycle)
                ])
                playerAvatar.runAction(.repeatForever(bounce), forKey: "local.walk.bounce")

                for name in ["leg.left", "leg.right"] {
                    guard let leg = playerAvatar.childNode(withName: name, recursively: false) else { continue }
                    let sign: CGFloat = name == "leg.left" ? 1 : -1
                    let strideHalfCycle: TimeInterval = runningKeys.isEmpty ? 0.19 : 0.095
                    let stride = SCNAction.sequence([
                        .rotateTo(x: sign * 0.58, y: 0, z: 0, duration: strideHalfCycle, usesShortestUnitArc: true),
                        .rotateTo(x: sign * -0.58, y: 0, z: 0, duration: strideHalfCycle, usesShortestUnitArc: true)
                    ])
                    leg.runAction(.repeatForever(stride), forKey: "local.walk.legs")
                }

                for name in ["arm.left", "arm.right"] {
                    guard let arm = playerAvatar.childNode(withName: name, recursively: false) else { continue }
                    let sign: CGFloat = name == "arm.left" ? -1 : 1
                    let swingHalfCycle: TimeInterval = runningKeys.isEmpty ? 0.19 : 0.095
                    let swing = SCNAction.sequence([
                        .rotateTo(x: -0.55 + sign * 0.38, y: 0, z: 0, duration: swingHalfCycle, usesShortestUnitArc: true),
                        .rotateTo(x: -0.55 - sign * 0.38, y: 0, z: 0, duration: swingHalfCycle * 2, usesShortestUnitArc: true),
                        .rotateTo(x: -0.55 + sign * 0.38, y: 0, z: 0, duration: swingHalfCycle, usesShortestUnitArc: true)
                    ])
                    arm.runAction(.repeatForever(swing), forKey: "local.walk.arms")
                }
            } else {
                playerAvatar.removeAction(forKey: "local.walk.bounce")
                for name in ["leg.left", "leg.right"] {
                    guard let leg = playerAvatar.childNode(withName: name, recursively: false) else { continue }
                    leg.removeAction(forKey: "local.walk.legs")
                    leg.eulerAngles = SCNVector3Zero
                }
                for name in ["arm.left", "arm.right"] {
                    guard let arm = playerAvatar.childNode(withName: name, recursively: false) else { continue }
                    arm.removeAction(forKey: "local.walk.arms")
                    arm.eulerAngles = SCNVector3(-0.55, 0, 0)
                }
                playerAvatar.position = SCNVector3(0, 0, 0.72)
            }
        }

        @objc func didClick(_ recognizer: NSClickGestureRecognizer) {
            guard let view, recognizer.state == .ended else { return }
            let point = recognizer.location(in: view)
            let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
            var node = hits.first?.node
            while let current = node {
                if let name = current.name, name.hasPrefix("session:") {
                    let id = String(name.dropFirst("session:".count))
                    if let session = latestSessions[id] { onSelect?(session) }
                    return
                }
                if let name = current.name, name.hasPrefix("department:") {
                    let id = String(name.dropFirst("department:".count))
                    if let group = latestGroups[id] { onSelectProject?(group.project) }
                    return
                }
                node = current.parent
            }
        }

        @objc func didDoubleClick(_ recognizer: NSClickGestureRecognizer) {
            guard let view, recognizer.state == .ended else { return }
            let point = recognizer.location(in: view)
            let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
            var node = hits.first?.node
            while let current = node {
                if let name = current.name, name.hasPrefix("session:") {
                    let id = String(name.dropFirst("session:".count))
                    if let session = latestSessions[id] { onOpen?(session) }
                    return
                }
                node = current.parent
            }
        }

        private func addAttentionMarker(for group: ProjectGroup, footprint: DepartmentFootprint, to department: SCNNode) {
            let plate = SCNText(string: "ATENÇÃO · \(group.attentionCount)", extrusionDepth: 0.015)
            plate.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            plate.firstMaterial = material(0xFF7A68, emission: 0xFF7A68)
            let node = SCNNode(geometry: plate)
            node.name = "department.attention"
            node.scale = SCNVector3(0.035, 0.035, 0.035)
            node.position = SCNVector3(0, 1.2, Float(footprint.depth / 2) - 0.55)
            node.constraints = [SCNBillboardConstraint()]
            node.renderingOrder = 130
            department.addChildNode(node)
        }

        private func addLights(to scene: SCNScene) {
            let ambient = SCNNode()
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.color = NSColor(hex: 0xAAB7E8)
            ambientLight.intensity = 520
            ambient.light = ambientLight
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            let keyLight = SCNLight()
            keyLight.type = .omni
            keyLight.color = NSColor(hex: 0xFFF0D5)
            keyLight.intensity = 1050
            keyLight.attenuationStartDistance = 8
            keyLight.attenuationEndDistance = 48
            key.position = SCNVector3(-3, 17, 9)
            key.light = keyLight
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            let fillLight = SCNLight()
            fillLight.type = .omni
            fillLight.color = NSColor(hex: 0x8777F2)
            fillLight.intensity = 520
            fillLight.attenuationStartDistance = 8
            fillLight.attenuationEndDistance = 42
            fill.position = SCNVector3(5, 10, -8)
            fill.light = fillLight
            scene.rootNode.addChildNode(fill)
        }

        private func addRoom(to scene: SCNScene, columns: Int, rows: Int, tileSize: Float) {
            let floorRoot = SCNNode()
            floorRoot.name = "office.floor"
            scene.rootNode.addChildNode(floorRoot)
            for row in 0..<rows {
                for column in 0..<columns {
                    let tile = box(
                        width: CGFloat(tileSize - 0.05), height: 0.18, length: CGFloat(tileSize - 0.05),
                        color: (row + column).isMultiple(of: 2) ? 0x34394E : 0x2D3247,
                        chamfer: 0.045
                    )
                    tile.position = SCNVector3(
                        (Float(column) - Float(columns - 1) / 2) * tileSize,
                        -0.12,
                        (Float(row) - Float(rows - 1) / 2) * tileSize
                    )
                    floorRoot.addChildNode(tile)
                }
            }

            // The back and side walls frame the room without closing its front.
            let backWall = box(width: CGFloat(roomWidth), height: 3.7, length: 0.35, color: 0x514463, chamfer: 0.08)
            backWall.position = SCNVector3(0, 1.72, -roomDepth / 2 + 0.1)
            scene.rootNode.addChildNode(backWall)
            let leftWall = box(width: 0.35, height: 2.5, length: CGFloat(roomDepth), color: 0x443D59, chamfer: 0.08)
            leftWall.position = SCNVector3(-roomWidth / 2 + 0.1, 1.15, 0)
            scene.rootNode.addChildNode(leftWall)
            let rightWall = box(width: 0.35, height: 2.5, length: CGFloat(roomDepth), color: 0x443D59, chamfer: 0.08)
            rightWall.position = SCNVector3(roomWidth / 2 - 0.1, 1.15, 0)
            scene.rootNode.addChildNode(rightWall)

            for index in 0..<columns {
                let x = (Float(index) - Float(columns - 1) / 2) * tileSize
                let frame = box(width: 1.55, height: 1.45, length: 0.13, color: 0x9B7C58, chamfer: 0.055)
                frame.position = SCNVector3(x, 2.15, -roomDepth / 2 + 0.31)
                scene.rootNode.addChildNode(frame)
                let glass = box(width: 1.28, height: 1.17, length: 0.055, color: index.isMultiple(of: 2) ? 0x78AEB8 : 0x817FB5)
                glass.position = SCNVector3(x, 2.18, -roomDepth / 2 + 0.405)
                scene.rootNode.addChildNode(glass)
                let mullion = box(width: 0.055, height: 1.15, length: 0.075, color: 0xE1C99E, chamfer: 0.01)
                mullion.position = SCNVector3(x, 2.18, -roomDepth / 2 + 0.45)
                scene.rootNode.addChildNode(mullion)
                let transom = box(width: 1.28, height: 0.055, length: 0.075, color: 0xE1C99E, chamfer: 0.01)
                transom.position = SCNVector3(x, 2.18, -roomDepth / 2 + 0.45)
                scene.rootNode.addChildNode(transom)
                let sill = box(width: 1.65, height: 0.13, length: 0.35, color: 0x9A704B, chamfer: 0.035)
                sill.position = SCNVector3(x, 1.45, -roomDepth / 2 + 0.5)
                scene.rootNode.addChildNode(sill)
            }

            addPlant(at: SCNVector3(-roomWidth / 2 + 0.9, 0, roomDepth / 2 - 1.0), to: scene)
            addPlant(at: SCNVector3(roomWidth / 2 - 0.9, 0, roomDepth / 2 - 1.0), to: scene)
            addPlant(at: SCNVector3(-roomWidth / 2 + 1.2, 0, 0), to: scene)
            addPlant(at: SCNVector3(roomWidth / 2 - 1.2, 0, 0), to: scene)

            for z in [-roomDepth / 2 + 5.5, roomDepth / 2 - 5.5] {
                addFramedArt(at: SCNVector3(-roomWidth / 2 + 0.3, 1.85, z), facing: .pi / 2, to: scene)
                addFramedArt(at: SCNVector3(roomWidth / 2 - 0.3, 1.85, z), facing: -.pi / 2, to: scene)
            }
        }

        private func makeAgent(for session: CodexSession, style: AvatarStyle) -> SCNNode {
            let root = SCNNode()
            let rug = cylinder(radius: 1.72, height: 0.025, color: 0x3B3B55, opacity: 0.82)
            rug.position = SCNVector3(0, -0.005, 0)
            root.addChildNode(rug)
            addDesk(to: root, accent: session.state.colorHex, state: session.state)
            addActivityBoard(for: session, to: root)
            let avatar = addAvatar(to: root, style: style)
            setPose(session.state, avatar: avatar, animated: false)
            applyStateAnimation(session.state, to: avatar, root: root)
            addNameplate(session.displayName, state: session.state, to: root)

            let ring = cylinder(radius: 1.74, height: 0.035, color: 0xB2A3FF, opacity: 0.7)
            ring.position = SCNVector3(0, 0.035, 0)
            ring.isHidden = session.id != currentSelectedID
            root.addChildNode(ring)
            selectionRings[session.id] = ring
            return root
        }

        private func transition(_ session: CodexSession, animated: Bool) {
            guard let root = sessionRoots[session.id],
                  let avatar = root.childNode(withName: "avatar", recursively: false) else { return }
            let wasWorking = renderedStates[session.id] == .working
            renderedStates[session.id] = session.state
            root.childNode(withName: "nameplate", recursively: false)?.removeFromParentNode()
            root.childNode(withName: "stateplate", recursively: false)?.removeFromParentNode()
            for name in ["attention.badge", "quiet.zzz", "complete.check", "unknown.question"] {
                root.childNode(withName: name, recursively: false)?.removeFromParentNode()
            }
            avatar.removeAction(forKey: "working.bounce")
            avatar.removeAction(forKey: "quiet.sleep")
            for armName in ["arm.left", "arm.right"] {
                avatar.childNode(withName: armName, recursively: false)?.removeAction(forKey: "working.typing")
            }
            root.childNode(withName: "screen", recursively: false)?.removeAction(forKey: "working.screen")
            root.childNode(withName: "screen", recursively: false)?.geometry?.firstMaterial?.diffuse.contents =
                NSColor(hex: session.state == .attention ? 0x523441 : 0x313B59)
            root.childNode(withName: "screen", recursively: false)?.geometry?.firstMaterial?.emission.contents =
                NSColor(hex: session.state == .attention ? 0x523441 : 0x313B59, opacity: 0.08)
            setPose(session.state, avatar: avatar, animated: animated, wasWorking: wasWorking)
            applyStateAnimation(session.state, to: avatar, root: root)
            addNameplate(session.displayName, state: session.state, to: root)
        }

        private func setPose(_ state: SessionState, avatar: SCNNode, animated: Bool, wasWorking: Bool? = nil) {
            let working = state == .working
            let targetPosition = SCNVector3(0, working ? 0.05 : 0, working ? -1.2 : 0.72)
            let targetYaw: CGFloat = working ? 0 : .pi
            let duration: TimeInterval = animated ? 0.85 : 0
            if animated {
                let travel: SCNAction
                if let wasWorking, wasWorking != working {
                    let sidePosition = SCNVector3(1.9, working ? 0 : 0, Float(avatar.position.z))
                    let farSidePosition = SCNVector3(1.9, working ? 0 : 0, targetPosition.z)
                    travel = .sequence([
                        .move(to: sidePosition, duration: 0.25),
                        .move(to: farSidePosition, duration: 0.3),
                        .move(to: targetPosition, duration: 0.3)
                    ])
                } else {
                    travel = .move(to: targetPosition, duration: duration)
                }
                avatar.runAction(.group([
                    travel,
                    .rotateTo(x: 0, y: targetYaw, z: 0, duration: duration, usesShortestUnitArc: true)
                ]), forKey: "session.pose")
            } else {
                avatar.position = targetPosition
                avatar.eulerAngles.y = targetYaw
            }

            for side in ["left", "right"] {
                guard let leg = avatar.childNode(withName: "leg.\(side)", recursively: false) else { continue }
                leg.removeAction(forKey: "session.leg")
                let target = working ? SCNVector3(-Float.pi / 2, 0, 0) : SCNVector3Zero
                if animated {
                    leg.runAction(.rotateTo(x: target.x, y: target.y, z: target.z, duration: duration, usesShortestUnitArc: true), forKey: "session.leg")
                } else { leg.eulerAngles = target }
                if let knee = avatar.childNode(withName: "knee.\(side)", recursively: false) {
                    knee.removeAction(forKey: "session.knee")
                    let kneeX: CGFloat = working ? .pi / 2 : 0
                    if animated {
                        knee.runAction(.rotateTo(x: kneeX, y: 0, z: 0, duration: duration, usesShortestUnitArc: true), forKey: "session.knee")
                    } else { knee.eulerAngles.x = kneeX }
                }
            }
            for side in ["left", "right"] {
                guard let arm = avatar.childNode(withName: "arm.\(side)", recursively: false) else { continue }
                arm.removeAction(forKey: "session.arm")
                arm.position.z = working ? -0.08 : 0.04
                let raised = !working && side == "right"
                let targetZ: CGFloat = raised ? -2.25 : 0
                let targetX: CGFloat = working ? -0.7 : 0
                if animated {
                    arm.runAction(.rotateTo(x: targetX, y: 0, z: targetZ, duration: duration, usesShortestUnitArc: true), forKey: "session.arm")
                } else {
                    arm.eulerAngles = SCNVector3(targetX, 0, targetZ)
                }
            }
        }

        private func addDesk(to root: SCNNode, accent: UInt32, state: SessionState) {
            let deskZ: Float = -0.15
            let top = box(width: 2.8, height: 0.16, length: 1.2, color: 0xA77A50, chamfer: 0.07)
            top.position = SCNVector3(0, 1.13, deskZ)
            root.addChildNode(top)
            for x: Float in [-1.1, 1.1] {
                for z: Float in [-0.48, 0.48] {
                    let leg = box(width: 0.13, height: 1.05, length: 0.13, color: 0x644B42, chamfer: 0.025)
                    leg.position = SCNVector3(x, 0.53, deskZ + z)
                    root.addChildNode(leg)
                }
            }

            let screenCase = box(width: 1.18, height: 0.78, length: 0.11, color: 0x252A3D, chamfer: 0.09)
            screenCase.position = SCNVector3(0, 1.65, deskZ - 0.31)
            root.addChildNode(screenCase)
            let screen = box(width: 0.98, height: 0.57, length: 0.045, color: state == .attention ? 0x523441 : 0x313B59, chamfer: 0.035)
            // Put the display face on the chair side of the monitor casing.
            screen.position = SCNVector3(0, 1.67, deskZ - 0.385)
            screen.name = "screen"
            root.addChildNode(screen)
            for bar in 0..<3 {
                let line = box(width: CGFloat(0.33 + Double(bar % 2) * 0.22), height: 0.035, length: 0.015, color: accent)
                line.position = SCNVector3(-0.2 + Float(bar % 2) * 0.1, 1.8 - Float(bar) * 0.12, deskZ - 0.41)
                root.addChildNode(line)
            }
            let stand = box(width: 0.18, height: 0.2, length: 0.14, color: 0x525973)
            stand.position = SCNVector3(0, 1.29, deskZ - 0.3)
            root.addChildNode(stand)
            let keyboard = box(width: 0.78, height: 0.07, length: 0.29, color: 0xC0A8D8, chamfer: 0.025)
            keyboard.position = SCNVector3(0, 1.25, deskZ - 0.43)
            root.addChildNode(keyboard)
            let mug = cylinder(radius: 0.12, height: 0.22, color: 0x76CBB1)
            mug.position = SCNVector3(0.96, 1.32, deskZ + 0.31)
            root.addChildNode(mug)

            let chairSeat = box(width: 1.05, height: 0.26, length: 0.9, color: 0x535C7A, chamfer: 0.11)
            chairSeat.position = SCNVector3(0, 0.6, -1.35)
            root.addChildNode(chairSeat)
            let chairBack = box(width: 1.0, height: 0.78, length: 0.18, color: 0x414A67, chamfer: 0.1)
            chairBack.position = SCNVector3(0, 1.0, -1.81)
            root.addChildNode(chairBack)
        }

        private func addAvatar(to root: SCNNode, style: AvatarStyle) -> SCNNode {
            let avatar = SCNNode()
            avatar.name = "avatar"
            avatar.position = SCNVector3(0, 0, 0.72)
            root.addChildNode(avatar)

            let body = capsule(radius: 0.42, height: 1.05, color: style.shirt)
            body.position = SCNVector3(0, 1.02, 0)
            body.name = "body"
            avatar.addChildNode(body)

            let head = sphere(radius: 0.43, color: style.skin)
            head.scale = SCNVector3(1 + style.faceShape * 0.035, 1 - style.faceShape * 0.025, 0.95)
            head.position = SCNVector3(0, 1.85, 0.03)
            avatar.addChildNode(head)
            let hair = sphere(radius: 0.44, color: style.hair)
            hair.scale = SCNVector3(1.02, 0.55, 1.03)
            hair.position = SCNVector3(0, 2.15, -0.015)
            avatar.addChildNode(hair)
            addHairStyle(style, to: avatar)

            let eyeSpacing = 0.13 + style.faceShape * 0.012
            for eyeX: Float in [-eyeSpacing, eyeSpacing] {
                let eye = sphere(radius: style.hasGlasses ? 0.037 : 0.045, color: style.eye)
                eye.position = SCNVector3(eyeX, 1.91 + style.faceShape * 0.012, 0.423)
                avatar.addChildNode(eye)
            }
            if style.hasGlasses {
                for eyeX: Float in [-eyeSpacing, eyeSpacing] {
                    let lens = torus(radius: 0.09, ring: 0.014, color: style.accessory)
                    lens.position = SCNVector3(eyeX, 1.91 + style.faceShape * 0.012, 0.438)
                    avatar.addChildNode(lens)
                }
                let bridge = box(width: CGFloat(eyeSpacing * 0.65), height: 0.018, length: 0.018, color: style.accessory)
                bridge.position = SCNVector3(0, 1.91, 0.44)
                avatar.addChildNode(bridge)
            }
            let smile = box(width: CGFloat(0.12 + Float(style.faceShape) * 0.025), height: 0.025, length: 0.018, color: style.mouth)
            smile.position = SCNVector3(0, 1.73, 0.44)
            avatar.addChildNode(smile)
            if style.hasBeard {
                let beard = sphere(radius: 0.23, color: style.hair)
                beard.scale = SCNVector3(1.05, 0.48, 0.45)
                beard.position = SCNVector3(0, 1.61, 0.32)
                avatar.addChildNode(beard)
            }

            for legX: Float in [-0.22, 0.22] {
                let legPivot = SCNNode()
                legPivot.name = legX < 0 ? "leg.left" : "leg.right"
                legPivot.position = SCNVector3(legX, 0.61, 0)
                avatar.addChildNode(legPivot)
                let thigh = capsule(radius: 0.15, height: 0.4, color: style.trousers)
                thigh.position = SCNVector3(0, -0.18, 0)
                legPivot.addChildNode(thigh)
                let knee = SCNNode()
                knee.name = legX < 0 ? "knee.left" : "knee.right"
                knee.position = SCNVector3(0, -0.36, 0)
                legPivot.addChildNode(knee)
                let shin = capsule(radius: 0.135, height: 0.4, color: style.trousers)
                shin.position = SCNVector3(0, -0.18, 0)
                knee.addChildNode(shin)
                let shoe = box(width: 0.31, height: 0.14, length: 0.42, color: style.shoes, chamfer: 0.055)
                shoe.position = SCNVector3(0, -0.12, 0.09)
                knee.addChildNode(shoe)
            }

            for side: Float in [-1, 1] {
                let armPivot = SCNNode()
                armPivot.name = side < 0 ? "arm.left" : "arm.right"
                armPivot.position = SCNVector3(side * 0.43, 1.35, 0.04)
                avatar.addChildNode(armPivot)
                let arm = capsule(radius: 0.14, height: 0.76, color: style.shirt)
                arm.position = SCNVector3(0, -0.3, 0.16)
                arm.eulerAngles.x = -0.55
                armPivot.addChildNode(arm)
                let hand = sphere(radius: 0.13, color: style.skin)
                hand.position = SCNVector3(0, -0.62, 0.39)
                hand.name = "hand"
                armPivot.addChildNode(hand)
            }
            return avatar
        }

        private func addHairStyle(_ style: AvatarStyle, to avatar: SCNNode) {
            func tuft(_ x: Float, _ y: Float, _ z: Float, _ sx: Float, _ sy: Float, _ sz: Float) {
                let piece = sphere(radius: 0.23, color: style.hair)
                piece.scale = SCNVector3(sx, sy, sz)
                piece.position = SCNVector3(x, y, z)
                avatar.addChildNode(piece)
            }
            switch style.hairStyle {
            case 0: // side swept fringe
                tuft(-0.2, 2.04, 0.31, 1.2, 0.4, 0.55)
            case 1: // two curls
                tuft(-0.28, 2.13, 0.05, 0.75, 0.78, 0.8); tuft(0.28, 2.13, 0.05, 0.75, 0.78, 0.8)
            case 2: // bun
                tuft(0, 2.42, -0.13, 0.72, 0.72, 0.72)
            case 3: // bob
                tuft(-0.34, 1.91, -0.02, 0.48, 1.35, 0.72); tuft(0.34, 1.91, -0.02, 0.48, 1.35, 0.72)
            case 4: // mohawk
                for index in 0..<4 { tuft(0, 2.25 + Float(index) * 0.08, -0.08, 0.48, 0.72, 0.48) }
            case 5: // long side locks
                tuft(-0.34, 1.78, 0.05, 0.42, 1.35, 0.52); tuft(0.34, 1.78, 0.05, 0.42, 1.35, 0.52)
            case 6: // cropped with a head band
                let band = torus(radius: 0.37, ring: 0.055, color: style.accessory)
                band.position = SCNVector3(0, 2.18, 0)
                band.eulerAngles.x = .pi / 2
                avatar.addChildNode(band)
            default: // textured curls
                for index in 0..<5 {
                    tuft(Float(index - 2) * 0.15, 2.22 + Float(index % 2) * 0.04, 0.02, 0.52, 0.5, 0.55)
                }
            }
        }

        private func addPlayerNameplate(to root: SCNNode) {
            let text = SCNText(string: "VOCÊ", extrusionDepth: 0.02)
            text.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .heavy)
            text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
            text.firstMaterial = material(0x8FE3CE, emission: 0x8FE3CE)
            let node = SCNNode(geometry: text)
            node.name = "player.nameplate"
            node.scale = SCNVector3(0.022, 0.022, 0.022)
            node.position = SCNVector3(0, 3.45, 0)
            node.constraints = [SCNBillboardConstraint()]
            node.renderingOrder = 100
            root.addChildNode(node)
        }

        private func applyStateAnimation(_ state: SessionState, to avatar: SCNNode, root: SCNNode) {
            if state == .working {
                let bounce = SCNAction.sequence([
                    .moveBy(x: 0, y: 0.045, z: 0, duration: 0.42),
                    .moveBy(x: 0, y: -0.045, z: 0, duration: 0.42)
                ])
                avatar.runAction(.repeatForever(bounce), forKey: "working.bounce")
                for name in ["arm.left", "arm.right"] {
                    guard let arm = avatar.childNode(withName: name, recursively: false) else { continue }
                    let typing = SCNAction.sequence([
                        .rotateBy(x: 0.16, y: 0, z: 0, duration: 0.16),
                        .rotateBy(x: -0.32, y: 0, z: 0, duration: 0.16),
                        .rotateBy(x: 0.16, y: 0, z: 0, duration: 0.16)
                    ])
                    arm.runAction(.repeatForever(typing), forKey: "working.typing")
                }
                if let screen = root.childNode(withName: "screen", recursively: false) {
                    let pulse = SCNAction.sequence([.fadeOpacity(to: 0.72, duration: 0.55), .fadeOpacity(to: 1, duration: 0.55)])
                    screen.runAction(.repeatForever(pulse), forKey: "working.screen")
                }
            } else if state == .attention {
                if let arm = avatar.childNode(withName: "arm.right", recursively: false) {
                    arm.eulerAngles.z = -2.25
                    arm.eulerAngles.x = 0.2
                }
                addFloatingBadge("!", color: 0xFF786F, to: root, y: 3.0, name: "attention.badge", pulse: true)
            } else if state == .quiet {
                addFloatingBadge("Z z", color: 0xF4C86A, to: root, y: 2.95, name: "quiet.zzz", pulse: false)
                let sleep = SCNAction.sequence([.rotateTo(x: 0, y: .pi, z: -0.06, duration: 0.55), .rotateTo(x: 0, y: .pi, z: 0.06, duration: 0.55)])
                avatar.runAction(.repeatForever(sleep), forKey: "quiet.sleep")
            } else if state == .complete {
                addFloatingBadge("✓", color: 0x79D5AE, to: root, y: 3.0, name: "complete.check", pulse: true)
                for index in 0..<5 {
                    let sparkle = box(width: 0.09, height: 0.09, length: 0.09, color: index.isMultiple(of: 2) ? 0x79D5AE : 0xF4C86A)
                    sparkle.position = SCNVector3(Float(index - 2) * 0.32, 2.75 + Float(index % 2) * 0.25, 0.45)
                    root.addChildNode(sparkle)
                    let shimmer = SCNAction.sequence([.fadeOpacity(to: 0.2, duration: 0.55), .fadeOpacity(to: 1, duration: 0.55)])
                    sparkle.runAction(.repeatForever(shimmer), forKey: "complete.sparkle")
                }
            } else {
                addFloatingBadge("?", color: 0xA9A0C9, to: root, y: 3.0, name: "unknown.question", pulse: false)
            }
        }

        private func addNameplate(_ name: String, state: SessionState, to root: SCNNode) {
            let text = SCNText(string: String(name.prefix(24)), extrusionDepth: 0.015)
            text.font = NSFont.systemFont(ofSize: 15, weight: .bold)
            text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
            text.truncationMode = CATextLayerTruncationMode.end.rawValue
            text.firstMaterial = material(0xF5F2FF)
            let node = SCNNode(geometry: text)
            node.name = "nameplate"
            node.scale = SCNVector3(0.019, 0.019, 0.019)
            node.position = SCNVector3(0, 3.45, 0)
            node.constraints = [SCNBillboardConstraint()]
            node.renderingOrder = 100
            root.addChildNode(node)

            let stateText = SCNText(string: state.label.uppercased(), extrusionDepth: 0.008)
            stateText.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .bold)
            stateText.alignmentMode = CATextLayerAlignmentMode.center.rawValue
            stateText.firstMaterial = material(state.colorHex)
            let stateNode = SCNNode(geometry: stateText)
            stateNode.name = "stateplate"
            stateNode.scale = SCNVector3(0.014, 0.014, 0.014)
            stateNode.position = SCNVector3(0, 3.2, 0)
            stateNode.constraints = [SCNBillboardConstraint()]
            stateNode.renderingOrder = 100
            root.addChildNode(stateNode)
        }

        private func addActivityBoard(for session: CodexSession, to station: SCNNode) {
            let board = SCNNode()
            board.name = "activity-board"
            board.position = SCNVector3(2.8, 1.72, -0.15)
            board.renderingOrder = 150

            let frame = box(width: 2.65, height: 2.25, length: 0.12, color: 0x795B40, chamfer: 0.075)
            frame.name = "activity-board.frame"
            frame.renderingOrder = 150
            board.addChildNode(frame)
            let face = box(width: 2.46, height: 2.06, length: 0.035, color: 0xF4F1E8, chamfer: 0.025)
            face.position.z = 0.08
            face.name = "activity-board.face"
            face.renderingOrder = 151
            board.addChildNode(face)

            // Wooden feet make the whiteboard read as a real object beside the desk.
            for x: Float in [-0.92, 0.92] {
                let foot = box(width: 0.085, height: 1.4, length: 0.085, color: 0x795B40, chamfer: 0.018)
                foot.position = SCNVector3(x, -1.0, -0.035)
                board.addChildNode(foot)
            }
            let content = SCNNode()
            content.name = "activity-board.content"
            content.position = SCNVector3(-1.13, 0.83, 0.11)
            content.renderingOrder = 155
            board.addChildNode(content)
            station.addChildNode(board)
            updateActivityBoard(session, node: board)
        }

        private func updateActivityBoards(_ sessions: [CodexSession]) {
            for session in sessions {
                guard let board = sessionRoots[session.id]?.childNode(withName: "activity-board", recursively: false) else { continue }
                updateActivityBoard(session, node: board)
            }
        }

        private func updateActivityBoard(_ session: CodexSession, node board: SCNNode) {
            let prompt = session.promptSummary ?? "Nenhum prompt recente disponível"
            let signature = [session.state.rawValue, session.reason ?? "", session.project, prompt].joined(separator: "|")
            guard boardContentSignatures[session.id] != signature else { return }
            boardContentSignatures[session.id] = signature
            guard let content = board.childNode(withName: "activity-board.content", recursively: false) else { return }
            content.childNodes.forEach { $0.removeFromParentNode() }

            addBoardText("ATIVIDADE", color: 0x34404A, size: 10, at: SCNVector3(0, 0.06, 0), to: content)
            let activity = session.reason.map { "\(session.state.label.uppercased()): \($0)" } ?? session.state.label.uppercased()
            addBoardText(String(activity.prefix(31)), color: session.state.colorHex, size: 9, at: SCNVector3(0, -0.2, 0), to: content)
            let project = session.project.isEmpty ? "Não identificado" : session.project
            addBoardText("PROJETO: \(String(project.prefix(23)))", color: 0x364149, size: 9, at: SCNVector3(0, -0.45, 0), to: content)
            addBoardText("ÚLTIMO PROMPT", color: 0x59646B, size: 8, at: SCNVector3(0, -0.72, 0), to: content)
            let promptLines = wrapped(prompt, maxCharacters: 30).prefix(4)
            for (index, line) in promptLines.enumerated() {
                addBoardText(line, color: 0x59646B, size: 8, at: SCNVector3(0, -0.94 - Float(index) * 0.21, 0), to: content)
            }
        }

        private func wrapped(_ value: String, maxCharacters: Int) -> [String] {
            let words = value.split(whereSeparator: \.isWhitespace).map(String.init)
            var lines: [String] = []
            var line = ""
            for word in words {
                if line.isEmpty {
                    line = String(word.prefix(maxCharacters))
                } else if line.count + word.count + 1 <= maxCharacters {
                    line += " \(word)"
                } else {
                    lines.append(line)
                    line = String(word.prefix(maxCharacters))
                }
            }
            if !line.isEmpty { lines.append(line) }
            return lines.isEmpty ? ["Sem prompt recente"] : lines
        }

        private func addBoardText(_ string: String, color: UInt32, size: CGFloat, at position: SCNVector3, to parent: SCNNode) {
            let text = SCNText(string: string, extrusionDepth: 0.002)
            text.font = NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
            text.firstMaterial = material(color, emission: color)
            let node = SCNNode(geometry: text)
            node.position = position
            node.scale = SCNVector3(0.012, 0.012, 0.012)
            node.renderingOrder = 156
            parent.addChildNode(node)
        }

        private func addFloatingBadge(_ string: String, color: UInt32, to root: SCNNode, y: Float, name: String, pulse: Bool) {
            let badge = SCNSphere(radius: 0.27)
            badge.firstMaterial = material(color, emission: color)
            let node = SCNNode(geometry: badge)
            node.name = name
            node.position = SCNVector3(0.85, y, 0.26)
            node.constraints = [SCNBillboardConstraint()]
            node.renderingOrder = 110

            let text = SCNText(string: string, extrusionDepth: 0.01)
            text.font = NSFont.systemFont(ofSize: 22, weight: .heavy)
            text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
            text.firstMaterial = material(0xFFF8F1)
            let glyph = SCNNode(geometry: text)
            glyph.scale = SCNVector3(0.012, 0.012, 0.012)
            glyph.position = SCNVector3(-0.09, -0.13, 0.22)
            node.addChildNode(glyph)
            root.addChildNode(node)

            let float = SCNAction.sequence([.moveBy(x: 0, y: 0.12, z: 0, duration: 0.48), .moveBy(x: 0, y: -0.12, z: 0, duration: 0.48)])
            let animation = SCNAction.group([.repeatForever(float), .repeatForever(.sequence([.scale(to: 1.12, duration: 0.45), .scale(to: 1, duration: 0.45)]))])
            if pulse { node.runAction(animation, forKey: "badge.float") }
            else { node.runAction(.repeatForever(float), forKey: "badge.float") }
        }

        private func addPlant(at position: SCNVector3, to scene: SCNScene) {
            let pot = cylinder(radius: 0.28, height: 0.42, color: 0x9A5B55)
            pot.position = SCNVector3(position.x, 0.22, position.z)
            scene.rootNode.addChildNode(pot)
            let soil = cylinder(radius: 0.22, height: 0.04, color: 0x44352F)
            soil.position = SCNVector3(position.x, 0.44, position.z)
            scene.rootNode.addChildNode(soil)
            let stem = cylinder(radius: 0.045, height: 0.72, color: 0x4F9265)
            stem.position = SCNVector3(position.x, 0.78, position.z)
            scene.rootNode.addChildNode(stem)
            for index in 0..<7 {
                let angle = Float(index) * (.pi * 2 / 7)
                let leaf = sphere(radius: 0.2, color: index.isMultiple(of: 2) ? 0x65B786 : 0x79C795)
                leaf.scale = SCNVector3(0.55, 1.65, 0.48)
                leaf.eulerAngles = SCNVector3(index.isMultiple(of: 2) ? -0.28 : 0.28, angle, 0)
                leaf.position = SCNVector3(
                    Float(position.x) + sin(angle) * 0.16,
                    0.82 + Float(index % 3) * 0.12,
                    Float(position.z) + cos(angle) * 0.16
                )
                scene.rootNode.addChildNode(leaf)
            }
        }

        private func addFramedArt(at position: SCNVector3, facing: CGFloat, to scene: SCNScene) {
            let artwork = SCNNode()
            artwork.position = position
            artwork.eulerAngles.y = facing
            scene.rootNode.addChildNode(artwork)

            let frame = box(width: 1.65, height: 1.18, length: 0.14, color: 0x8B684E, chamfer: 0.055)
            artwork.addChildNode(frame)
            let mat = box(width: 1.42, height: 0.95, length: 0.035, color: 0xF0DFC0, chamfer: 0.015)
            mat.position.z = 0.085
            artwork.addChildNode(mat)
            let canvas = box(width: 1.25, height: 0.78, length: 0.025, color: 0x80B7AE)
            canvas.position.z = 0.11
            artwork.addChildNode(canvas)

            let sun = sphere(radius: 0.14, color: 0xF6C875)
            sun.scale = SCNVector3(1, 1, 0.2)
            sun.position = SCNVector3(0.34, 0.2, 0.14)
            artwork.addChildNode(sun)
            let mountain = SCNPyramid(width: 0.55, height: 0.38, length: 0.12)
            mountain.firstMaterial = material(0x526F82)
            let mountainNode = SCNNode(geometry: mountain)
            mountainNode.position = SCNVector3(-0.19, -0.18, 0.15)
            artwork.addChildNode(mountainNode)
            let smallerMountain = SCNPyramid(width: 0.43, height: 0.29, length: 0.1)
            smallerMountain.firstMaterial = material(0x527F76)
            let smallerMountainNode = SCNNode(geometry: smallerMountain)
            smallerMountainNode.position = SCNVector3(0.29, -0.22, 0.16)
            artwork.addChildNode(smallerMountainNode)
        }

        private func box(width: CGFloat, height: CGFloat, length: CGFloat, color: UInt32, chamfer: CGFloat = 0) -> SCNNode {
            let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: chamfer)
            geometry.firstMaterial = material(color)
            return SCNNode(geometry: geometry)
        }

        private func cylinder(radius: CGFloat, height: CGFloat, color: UInt32, opacity: CGFloat = 1) -> SCNNode {
            let geometry = SCNCylinder(radius: radius, height: height)
            geometry.firstMaterial = material(color, opacity: opacity)
            return SCNNode(geometry: geometry)
        }

        private func torus(radius: CGFloat, ring: CGFloat, color: UInt32) -> SCNNode {
            let geometry = SCNTorus(ringRadius: radius, pipeRadius: ring)
            geometry.firstMaterial = material(color)
            return SCNNode(geometry: geometry)
        }

        private func sphere(radius: CGFloat, color: UInt32) -> SCNNode {
            let geometry = SCNSphere(radius: radius)
            geometry.segmentCount = 14
            geometry.firstMaterial = material(color)
            return SCNNode(geometry: geometry)
        }

        private func capsule(radius: CGFloat, height: CGFloat, color: UInt32) -> SCNNode {
            let geometry = SCNCapsule(capRadius: radius, height: height)
            geometry.radialSegmentCount = 10
            geometry.firstMaterial = material(color)
            return SCNNode(geometry: geometry)
        }

        private func material(_ hex: UInt32, emission: UInt32? = nil, opacity: CGFloat = 1) -> SCNMaterial {
            let result = SCNMaterial()
            result.diffuse.contents = NSColor(hex: hex, opacity: opacity)
            result.emission.contents = NSColor(hex: emission ?? 0x000000, opacity: emission == nil ? 0 : opacity)
            result.roughness.contents = 0.72
            result.metalness.contents = 0.02
            result.lightingModel = .physicallyBased
            return result
        }
    }
}

final class OfficeSceneView: SCNView {
    var onLayout: (() -> Void)?
    var onMovementKey: ((UInt16, Bool) -> Void)?
    var onZoom: ((CGFloat) -> Void)?
    var onOrbit: ((CGFloat, CGFloat) -> Void)?
    var onToggleCamera: (() -> Void)?
    var onCameraMode: ((CameraMode) -> Void)?
    var isFirstPersonCamera = false {
        didSet {
            previousLookPoint = window.map { convert($0.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil) }
        }
    }

    private let movementKeyCodes: Set<UInt16> = [0, 1, 2, 13, 56, 60, 123, 124, 125, 126]
    private var previousDragPoint: NSPoint?
    private var previousLookPoint: NSPoint?
    private var mouseTrackingArea: NSTrackingArea?
    private var keyWindowObserver: NSObjectProtocol?
    private var isPointerCaptured = false

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let keyWindowObserver {
            NotificationCenter.default.removeObserver(keyWindowObserver)
            self.keyWindowObserver = nil
        }
        guard let window else {
            releaseMovementInput()
            return
        }
        window.acceptsMouseMovedEvents = true
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.releaseMovementInput()
        }
    }

    func setPointerCaptured(_ captured: Bool) {
        guard captured != isPointerCaptured else { return }
        if captured {
            guard CGAssociateMouseAndMouseCursorPosition(0) == .success else { return }
            isPointerCaptured = true
            NSCursor.hide()
            previousLookPoint = nil
        } else {
            _ = CGAssociateMouseAndMouseCursorPosition(1)
            isPointerCaptured = false
            NSCursor.unhide()
            previousLookPoint = window.map { convert($0.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil) }
        }
    }

    private func releaseMovementInput() {
        for keyCode in movementKeyCodes { onMovementKey?(keyCode, false) }
        setPointerCaptured(false)
    }

    override func updateTrackingAreas() {
        if let mouseTrackingArea { removeTrackingArea(mouseTrackingArea) }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        mouseTrackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        previousDragPoint = event.locationInWindow
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = event.locationInWindow
        if isFirstPersonCamera, isPointerCaptured {
            onOrbit?(event.deltaX, event.deltaY)
        } else if isFirstPersonCamera, let previousLookPoint {
            onOrbit?(point.x - previousLookPoint.x, point.y - previousLookPoint.y)
        } else if !isFirstPersonCamera, let previousDragPoint {
            onOrbit?(point.x - previousDragPoint.x, point.y - previousDragPoint.y)
        }
        previousDragPoint = point
        previousLookPoint = point
        super.mouseDragged(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        previousLookPoint = event.locationInWindow
        super.mouseEntered(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = event.locationInWindow
        if isFirstPersonCamera, isPointerCaptured {
            onOrbit?(event.deltaX, event.deltaY)
        } else if isFirstPersonCamera, let previousLookPoint {
            onOrbit?(point.x - previousLookPoint.x, point.y - previousLookPoint.y)
        }
        previousLookPoint = point
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        previousLookPoint = nil
        super.mouseExited(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        previousDragPoint = nil
        previousLookPoint = event.locationInWindow
        super.mouseUp(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 9 { // V
            if !event.isARepeat { onToggleCamera?() }
            return
        }
        if movementKeyCodes.contains(event.keyCode) {
            onMovementKey?(event.keyCode, true)
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if movementKeyCodes.contains(event.keyCode) {
            onMovementKey?(event.keyCode, false)
            return
        }
        super.keyUp(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        if event.keyCode == 56 || event.keyCode == 60 {
            // Modifier keys are delivered as flagsChanged on macOS rather than keyDown/up.
            onMovementKey?(56, event.modifierFlags.contains(.shift))
            return
        }
        super.flagsChanged(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        let verticalDelta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 8 : event.scrollingDeltaY
        if verticalDelta != 0 {
            onZoom?(verticalDelta)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func resignFirstResponder() -> Bool {
        releaseMovementInput()
        return super.resignFirstResponder()
    }

    override func layout() {
        super.layout()
        onLayout?()
    }
}

private extension NSColor {
    convenience init(hex: UInt32, opacity: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}
