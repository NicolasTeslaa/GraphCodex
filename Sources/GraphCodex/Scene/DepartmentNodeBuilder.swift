import AppKit
import SceneKit

enum DepartmentNodeBuilder {
    static func build(project: Project, footprint: DepartmentFootprint) -> SCNNode {
        let root = SCNNode()
        root.name = "department:\(project.id)"
        root.position = SCNVector3(Float(footprint.center.x), 0, Float(footprint.center.z))

        let floor = SCNBox(width: CGFloat(footprint.width), height: 0.22, length: CGFloat(footprint.depth), chamferRadius: 0.12)
        floor.firstMaterial = material(0x20263A)
        let floorNode = SCNNode(geometry: floor)
        floorNode.name = "department.floor"
        floorNode.position.y = -0.1
        root.addChildNode(floorNode)

        for (x, width) in [(-footprint.width / 2, 0.16), (footprint.width / 2, 0.16)] {
            let divider = SCNBox(width: CGFloat(width), height: 1.15, length: CGFloat(footprint.depth), chamferRadius: 0.035)
            divider.firstMaterial = material(project.colorHex, opacity: 0.45)
            let wall = SCNNode(geometry: divider)
            wall.position = SCNVector3(Float(x), 0.5, 0)
            root.addChildNode(wall)
        }

        let sign = SCNText(string: String(project.name.prefix(34)), extrusionDepth: 0.04)
        sign.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        sign.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        sign.firstMaterial = material(0xF2F4FA, emission: project.colorHex)
        let signNode = SCNNode(geometry: sign)
        signNode.name = "department.sign"
        signNode.scale = SCNVector3(0.045, 0.045, 0.045)
        signNode.position = SCNVector3(0, 2.25, -Float(footprint.depth / 2) + 0.25)
        signNode.constraints = [SCNBillboardConstraint()]
        signNode.renderingOrder = 120
        root.addChildNode(signNode)

        let metrics = SCNText(string: "\(footprint.stationPositions.count) AGENTS   ·   \(project.kind.title.uppercased())", extrusionDepth: 0.01)
        metrics.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
        metrics.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        metrics.firstMaterial = material(project.colorHex)
        let metricsNode = SCNNode(geometry: metrics)
        metricsNode.name = "department.metrics"
        metricsNode.scale = SCNVector3(0.032, 0.032, 0.032)
        metricsNode.position = SCNVector3(0, 1.65, -Float(footprint.depth / 2) + 0.25)
        metricsNode.constraints = [SCNBillboardConstraint()]
        metricsNode.renderingOrder = 120
        root.addChildNode(metricsNode)
        return root
    }

    private static func material(_ hex: UInt32, emission: UInt32? = nil, opacity: CGFloat = 1) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: hex, opacity: opacity)
        material.emission.contents = NSColor(hex: emission ?? 0x000000, opacity: emission == nil ? 0 : opacity)
        material.roughness.contents = 0.74
        return material
    }
}

enum StationNodeBuilder {
    static func position(sessionID: String, in footprint: DepartmentFootprint) -> OfficePoint? {
        footprint.stationPositions[sessionID]
    }
}

enum AttentionZoneBuilder {
    static func contains(_ session: CodexSession) -> Bool {
        session.state == .attention
    }
}

private extension NSColor {
    convenience init(hex: UInt32, opacity: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: opacity)
    }
}
