import CustomDump
import Foundation
import Testing
@testable import AnalyticsKit

@Suite(.timeLimit(.minutes(1)))
struct ExceptionReportTests {
    /// MetricKit's shape: the crashed thread's frames innermost first, each frame's caller in `subFrames`.
    private static let callStackTree = Data(#"""
        {
          "callStackPerThread": true,
          "callStacks": [
            {
              "threadAttributed": false,
              "callStackRootFrames": [
                { "binaryUUID": "B", "binaryName": "libsystem_kernel.dylib", "offsetIntoBinaryTextSegment": 16, "address": 4112 }
              ]
            },
            {
              "threadAttributed": true,
              "callStackRootFrames": [
                {
                  "binaryUUID": "A1", "binaryName": "OpenSkateMap", "offsetIntoBinaryTextSegment": 256, "address": 4352,
                  "sampleCount": 1,
                  "subFrames": [
                    {
                      "binaryUUID": "C3", "binaryName": "UIKitCore", "offsetIntoBinaryTextSegment": 32, "address": 8224,
                      "sampleCount": 1,
                      "subFrames": [
                        {
                          "binaryUUID": "A1", "binaryName": "OpenSkateMap", "offsetIntoBinaryTextSegment": 512,
                          "address": 4608, "sampleCount": 1
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """#.utf8)

    @Test
    func `the attributed thread's frames go outermost first, with the binaries symbolication needs`() throws {
        let stack = try ExceptionReport.Stack(callStackTree: Self.callStackTree, appBinary: "OpenSkateMap")

        expectNoDifference(stack.frames, [
            ExceptionReport.Frame(instructionAddress: 4608, imageAddress: 4096, module: "OpenSkateMap", inApp: true),
            ExceptionReport.Frame(instructionAddress: 8224, imageAddress: 8192, module: "UIKitCore", inApp: false),
            ExceptionReport.Frame(instructionAddress: 4352, imageAddress: 4096, module: "OpenSkateMap", inApp: true),
        ])
        expectNoDifference(stack.images, [
            ExceptionReport.Image(name: "OpenSkateMap", uuid: "A1", address: 4096),
            ExceptionReport.Image(name: "UIKitCore", uuid: "C3", address: 8192),
        ])
    }

    @Test
    func `a hang's tree follows its most-sampled branch`() throws {
        let tree = Data(#"""
            {
              "callStacks": [
                {
                  "threadAttributed": true,
                  "callStackRootFrames": [
                    { "binaryName": "OpenSkateMap", "address": 1, "sampleCount": 2 },
                    { "binaryName": "OpenSkateMap", "address": 2, "sampleCount": 9 }
                  ]
                }
              ]
            }
            """#.utf8)

        let stack = try ExceptionReport.Stack(callStackTree: tree, appBinary: "OpenSkateMap")

        expectNoDifference(stack.frames.map(\.instructionAddress), [2])
        expectNoDifference(stack.images, [])
    }

    @Test
    func `the event carries PostHog's exception fields`() throws {
        let report = try ExceptionReport(
            level: .fatal,
            type: "NSRangeException",
            value: "*** -[__NSArrayM objectAtIndex:]: index %lu beyond bounds [0 .. %lu]",
            mechanism: "metrickit_crash",
            stack: ExceptionReport.Stack(callStackTree: Self.callStackTree, appBinary: "OpenSkateMap"),
            details: ["diagnostic_build": "20261019.0100"],
        )

        let properties = report.properties
        let exception = try #require((properties["$exception_list"] as? [[String: Any]])?.first)
        let frames = try #require((exception["stacktrace"] as? [String: Any])?["frames"] as? [[String: Any]])
        expectNoDifference(properties["$exception_level"] as? String, "fatal")
        expectNoDifference(properties["$exception_source"] as? String, "ios.metrickit")
        expectNoDifference(properties["diagnostic_build"] as? String, "20261019.0100")
        expectNoDifference(exception["type"] as? String, "NSRangeException")
        expectNoDifference(frames.first?["instruction_addr"] as? String, "0x0000000000001200")
        expectNoDifference(frames.first?["image_addr"] as? String, "0x0000000000001000")
        expectNoDifference(frames.first?["in_app"] as? Bool, true)
        expectNoDifference(
            (properties["$debug_images"] as? [[String: Any]])?.compactMap { $0["debug_id"] as? String },
            ["A1", "C3"],
        )
    }
}
