import Foundation

// MARK: - ExceptionReport

/// A crash, hang or CPU exception in PostHog's `$exception` format, frames outermost first.
struct ExceptionReport: Equatable, Sendable {

    // MARK: Types

    enum Level: String, Sendable {
        case fatal
        case error
    }

    struct Frame: Equatable, Sendable {
        var instructionAddress: UInt64
        var imageAddress: UInt64?
        var module: String?
        var inApp: Bool
    }

    struct Image: Equatable, Sendable {
        var name: String
        var uuid: String
        var address: UInt64
    }

    struct Stack: Equatable, Sendable {
        var frames = [Frame]()
        var images = [Image]()
    }

    // MARK: Computed Properties

    var properties: [String: Any] {
        var exception: [String: Any] = [
            "type": type,
            "value": value,
            "mechanism": ["type": mechanism, "handled": false, "synthetic": false],
        ]
        if !stack.frames.isEmpty {
            exception["stacktrace"] = ["type": "raw", "frames": stack.frames.map(\.properties)]
        }
        var properties: [String: Any] = details
        properties["$exception_level"] = level.rawValue
        properties["$exception_source"] = "ios.metrickit"
        properties["$exception_list"] = [exception]
        if !stack.images.isEmpty {
            properties["$debug_images"] = stack.images.map(\.properties)
        }
        return properties
    }

    // MARK: Properties

    var level: Level
    var type: String
    var value: String
    var mechanism: String
    var stack: Stack
    /// Versions and measurements; never free text.
    var details: [String: String]
}

// MARK: - MetricKit's call stack tree

extension ExceptionReport.Stack {
    private struct Tree: Decodable {
        struct CallStack: Decodable {
            var threadAttributed: Bool?
            var callStackRootFrames: [Node]
        }

        struct Node: Decodable {
            var binaryUUID: String?
            var binaryName: String?
            var offsetIntoBinaryTextSegment: UInt64?
            var address: UInt64
            var sampleCount: Int?
            var subFrames: [Node]?
        }

        var callStacks: [CallStack]
    }

    /// The thread MetricKit attributes the diagnostic to (else the first), following the most-sampled branch; frames
    /// in `appBinary` are the app's.
    init(callStackTree json: Data, appBinary: String) throws {
        let tree = try JSONDecoder().decode(Tree.self, from: json)
        let callStack = tree.callStacks.first { $0.threadAttributed == true } ?? tree.callStacks.first
        var innermostFirst = [Tree.Node]()
        var level = callStack?.callStackRootFrames ?? []
        while let node = level.max(by: { ($0.sampleCount ?? 0) < ($1.sampleCount ?? 0) }) {
            innermostFirst.append(node)
            level = node.subFrames ?? []
        }
        var images = [ExceptionReport.Image]()
        frames = innermostFirst.reversed().map { node in
            let imageAddress = node.offsetIntoBinaryTextSegment.flatMap { node.address >= $0 ? node.address - $0 : nil }
            if let uuid = node.binaryUUID, let name = node.binaryName, let imageAddress,
               !images.contains(where: { $0.uuid == uuid }) {
                images.append(ExceptionReport.Image(name: name, uuid: uuid, address: imageAddress))
            }
            return ExceptionReport.Frame(
                instructionAddress: node.address,
                imageAddress: imageAddress,
                module: node.binaryName,
                inApp: node.binaryName == appBinary,
            )
        }
        self.images = images
    }
}

// MARK: - Dictionaries

extension ExceptionReport.Frame {
    fileprivate var properties: [String: Any] {
        var properties: [String: Any] = [
            "instruction_addr": hex(instructionAddress),
            "platform": "apple",
            "in_app": inApp,
        ]
        properties["image_addr"] = imageAddress.map(hex)
        properties["module"] = module
        return properties
    }
}

extension ExceptionReport.Image {
    fileprivate var properties: [String: Any] {
        ["type": "macho", "code_file": name, "debug_id": uuid, "image_addr": hex(address)]
    }
}

private func hex(_ address: UInt64) -> String {
    String(format: "0x%016llx", address)
}
