import Foundation
import MapKit
import ObjectiveC
import os
import SwiftMacros

/// MapKit's public configurations stay flat; the globe is the projection in its private cartographic configuration.
@MainActor
enum MapGlobeProjection {

    // MARK: Types

    /// `{int64 style, emphasis, projection, terrainMode, mapkitUsage, mapkitClientMode; bool gridOnly}`, 56 bytes on arm64.
    private enum Layout {
        static let size = 56
        static let projectionOffset = 16
        static let terrainModeOffset = 24
        static let fieldEncoding = "qqqqqqB}"
    }

    private struct Configuration {
        var projection: Int64 {
            get { field(at: Layout.projectionOffset) }
            set { setField(newValue, at: Layout.projectionOffset) }
        }

        var terrainMode: Int64 {
            get { field(at: Layout.terrainModeOffset) }
            set { setField(newValue, at: Layout.terrainModeOffset) }
        }

        var value: NSValue? {
            bytes.withUnsafeBytes { buffer in
                guard let base = buffer.baseAddress else {
                    return nil
                }
                return objCType.withCString { NSValue(bytes: base, objCType: $0) }
            }
        }

        var bytes = [UInt8](repeating: 0, count: Layout.size)
        let objCType: String

        init?(value: NSValue) {
            objCType = String(cString: value.objCType)
            let copied = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard let base = buffer.baseAddress else {
                    return false
                }
                value.getValue(base, size: Layout.size)
                return true
            }
            guard copied else {
                return nil
            }
        }

        private func field(at offset: Int) -> Int64 {
            bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int64.self) }
        }

        private mutating func setField(_ value: Int64, at offset: Int) {
            bytes.withUnsafeMutableBytes { $0.storeBytes(of: value, toByteOffset: offset, as: Int64.self) }
        }
    }

    // MARK: Static Properties

    private static let key = #Obfuscate("cartographicConfiguration")
    private static let getterName = #Obfuscate("_cartographicConfiguration")
    private static let setterName = #Obfuscate("_setCartographicConfiguration:")

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "globe")
    private static var hasLoggedFailure = false

    // MARK: Static Functions

    @discardableResult
    static func apply(to mapView: MKMapView) -> Bool {
        guard var configuration = read(from: mapView) else {
            return fail("the cartographic configuration is unavailable or has changed shape")
        }
        guard configuration.projection != 1 || configuration.terrainMode != 1 else {
            return true
        }
        configuration.projection = 1
        configuration.terrainMode = 1
        guard let value = configuration.value else {
            return fail("the configuration couldn't be written back")
        }
        mapView.setValue(value, forKey: key)
        guard read(from: mapView)?.projection == 1 else {
            return fail("MapKit didn't keep the globe projection")
        }
        return true
    }

    private static func read(from mapView: MKMapView) -> Configuration? {
        guard let getter = class_getInstanceMethod(MKMapView.self, NSSelectorFromString(getterName)),
              let setter = class_getInstanceMethod(MKMapView.self, NSSelectorFromString(setterName)),
              let getterEncoding = method_getTypeEncoding(getter).map({ String(cString: $0) }),
              let setterEncoding = method_getTypeEncoding(setter).map({ String(cString: $0) }),
              getterEncoding.hasPrefix("{"),
              getterEncoding.contains(Layout.fieldEncoding),
              setterEncoding.contains(Layout.fieldEncoding),
              let value = mapView.value(forKey: key) as? NSValue else {
            return nil
        }
        var size = 0
        var alignment = 0
        NSGetSizeAndAlignment(value.objCType, &size, &alignment)
        guard size == Layout.size, String(cString: value.objCType).contains(Layout.fieldEncoding) else {
            return nil
        }
        return Configuration(value: value)
    }

    private static func fail(_ reason: String) -> Bool {
        if !hasLoggedFailure {
            hasLoggedFailure = true
            logger.error("The map stays flat: \(reason, privacy: .public)")
        }
        return false
    }
}
