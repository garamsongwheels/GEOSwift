//
//  Humboldt.swift
//
//  Created by Andrea Cremaschi on 26/04/15.
//  Copyright (c) 2015 andreacremaschi. All rights reserved.
//

import Foundation
import geos

var GEOS_HANDLE: COpaquePointer = {
    return initGEOSWrapper_r();
}()

@objc public class Geometry {

    let geometry: COpaquePointer
    let destroyOnDeinit: Bool
    
    required public init(GEOSGeom: COpaquePointer, destroyOnDeinit: Bool) {
        self.geometry = GEOSGeom
        self.destroyOnDeinit = destroyOnDeinit
    }

    deinit {
//        println("Destroying \(self)")
        if (self.destroyOnDeinit) {
            GEOSGeom_destroy_r(GEOS_HANDLE, geometry);
        }
    }
    
    private convenience init(GEOSGeom: COpaquePointer) {
        self.init(GEOSGeom: GEOSGeom, destroyOnDeinit: true)
    }

    internal class func create(GEOSGeom: COpaquePointer, destroyOnDeinit: Bool) -> Geometry? {
        if GEOSGeom == nil {
            return nil
        }
        if let subclass = Geometry.classForGEOSGeom(GEOSGeom) {
            return subclass(GEOSGeom: GEOSGeom, destroyOnDeinit: destroyOnDeinit)
        }
        return nil
    }
    
    public class func geometryTypeId() -> Int32 {
        return -1 // Abstract
    }
    
    private class func classForGEOSGeom(GEOSGeom: COpaquePointer) -> Geometry.Type? {
        if (GEOSGeom == nil) {
            return nil
        }
        let geometryTypeId = GEOSGeomTypeId_r(GEOS_HANDLE, GEOSGeom)
        var subclass: Geometry.Type

        switch geometryTypeId {
        case 0: // GEOS_POINT
            subclass = Waypoint.self
            
        case 1: // GEOS_LINESTRING:
            subclass = LineString.self
            
        case 2: // GEOS_LINEARRING:
            subclass = LinearRing.self
            
        case 3: // GEOS_POLYGON:
            subclass = Polygon.self
            
        case 4: // GEOS_MULTIPOINT:
            subclass = MultiPoint.self
            
        case 5: // GEOS_MULTILINESTRING:
            subclass = MultiLineString.self
            
        case 6: // GEOS_MULTIPOLYGON:
            subclass = MultiPolygon.self
            
        case 7: // GEOS_GEOMETRYCOLLECTION:
            subclass = GeometryCollection<Geometry>.self
            
        default:
            return nil
        }
        return subclass
    }
    
    private class func create(GEOSGeom: COpaquePointer) -> Geometry? {
        return self.create(GEOSGeom, destroyOnDeinit: true)
    }

    public class func create(WKT: String) -> Geometry? {
        let WKTReader = GEOSWKTReader_create_r(GEOS_HANDLE)
        let GEOSGeom = GEOSWKTReader_read_r(GEOS_HANDLE, WKTReader, (WKT as NSString).UTF8String)
        GEOSWKTReader_destroy_r(GEOS_HANDLE, WKTReader)
        return self.create(GEOSGeom)
    }

    public class func create(WKB: UnsafePointer<UInt8>, size: Int)  -> AnyObject? {
        let WKBReader = GEOSWKBReader_create_r(GEOS_HANDLE)
        let GEOSGeom = GEOSWKBReader_read_r(GEOS_HANDLE, WKBReader, WKB, size)
        GEOSWKBReader_destroy_r(GEOS_HANDLE, WKBReader)
        return self.create(GEOSGeom)
    }
}

public struct CoordinatesCollection: SequenceType {
    let geometry: COpaquePointer
    public let count: UInt32
    
    init(geometry: COpaquePointer) {
        self.geometry = geometry

        let sequence = GEOSGeom_getCoordSeq_r(GEOS_HANDLE, self.geometry)
        var numCoordinates: UInt32 = 0
        GEOSCoordSeq_getSize_r(GEOS_HANDLE, sequence, &numCoordinates);
        self.count = numCoordinates
    }
    
    public subscript(index: UInt32) -> Coordinate {
        var x: Double = 0
        var y: Double = 0
        let sequence = GEOSGeom_getCoordSeq_r(GEOS_HANDLE, self.geometry)
        GEOSCoordSeq_getX_r(GEOS_HANDLE, sequence, index, &x);
        GEOSCoordSeq_getY_r(GEOS_HANDLE, sequence, index, &y);

        return Coordinate(x: x, y: y)
    }
    
    public func generate() -> GeneratorOf<Coordinate> {
        var index: UInt32 = 0
        return GeneratorOf {
            if index < self.count {
                return self[index++]
            }
            return nil
        }
    }
}

public struct GeometriesCollection<T: Geometry>: SequenceType {
    let geometry: COpaquePointer
    public let count: Int32
    
    init(geometry: COpaquePointer) {
        self.geometry = geometry
        self.count = GEOSGetNumGeometries_r (GEOS_HANDLE, geometry)
    }

    public subscript(index: Int32) -> T {
        let GEOSGeom = GEOSGetGeometryN_r(GEOS_HANDLE, self.geometry, index)
        let geom = Geometry.create(GEOSGeom, destroyOnDeinit: false) as! T
        return geom
    }
    
    public func generate() -> GeneratorOf<T> {
        var index: Int32 = 0
        return GeneratorOf {
            if index < self.count {
                return self[index++]
            }
            return nil
        }
    }
}

public struct Coordinate {
    public let x: Double
    public let y: Double
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public class Waypoint : Geometry {
    public let coordinate: Coordinate
    
    public override class func geometryTypeId() -> Int32 {
        return 0 // GEOS_POINT
    }
    
    public required init(GEOSGeom: COpaquePointer, destroyOnDeinit: Bool) {
        let isValid = GEOSGeom != nil && GEOSGeomTypeId_r(GEOS_HANDLE, GEOSGeom) == Waypoint.geometryTypeId() // GEOS_POINT
        
        if (!isValid) {
            coordinate = Coordinate(x: 0, y: 0)
        } else {
            let points = CoordinatesCollection(geometry: GEOSGeom)
            self.coordinate = points[0]
        }
        super.init(GEOSGeom: GEOSGeom, destroyOnDeinit: destroyOnDeinit)
    }
    
    public convenience init?(WKT: String) {
        let WKTReader = GEOSWKTReader_create_r(GEOS_HANDLE)
        let GEOSGeom = GEOSWKTReader_read_r(GEOS_HANDLE, WKTReader, (WKT as NSString).UTF8String)
        GEOSWKTReader_destroy_r(GEOS_HANDLE, WKTReader)
        
        if Geometry.classForGEOSGeom(GEOSGeom) !== Waypoint.self {
            self.init(GEOSGeom: nil)
            return nil
        }
        self.init(GEOSGeom: GEOSGeom, destroyOnDeinit: true)
    }
}

public class Polygon : Geometry {
    
    public override class func geometryTypeId() -> Int32 {
        return 3 // GEOS_POLYGON
    }

    public required init(GEOSGeom: COpaquePointer, destroyOnDeinit: Bool) {
        super.init(GEOSGeom: GEOSGeom, destroyOnDeinit: destroyOnDeinit)
    }
    
    lazy public var exteriorRing: LineString = {
        let exteriorRing = GEOSGetExteriorRing_r(GEOS_HANDLE, self.geometry)
        let linestring = Geometry.create(exteriorRing, destroyOnDeinit: false) as! LineString
        return linestring
    }()

    lazy public var interiorRings: GeometriesCollection<Polygon> = {
        return GeometriesCollection<Polygon>(geometry: self.geometry)
        }()
}

public class LineString : Geometry {
    
    public override class func geometryTypeId() -> Int32 {
        return 1 // GEOS_LINESTRING
    }
    
    lazy public var points: CoordinatesCollection = {
        return CoordinatesCollection(geometry: self.geometry)
        }()
}

public class LinearRing : LineString {
    
}

public class GeometryCollection<T: Geometry> : Geometry {
    
    public override class func geometryTypeId() -> Int32 {
        return 7 // GEOS_LINESTRING
    }

    lazy public var geometries: GeometriesCollection<T> = {
        return GeometriesCollection<T>(geometry: self.geometry)
        }()
    public required init(GEOSGeom: COpaquePointer, destroyOnDeinit: Bool) {
        super.init(GEOSGeom: GEOSGeom, destroyOnDeinit: destroyOnDeinit)
    }
    private convenience init(GEOSGeom: COpaquePointer) {
        self.init(GEOSGeom: GEOSGeom, destroyOnDeinit: true)
    }
}

public class MultiLineString<T: LineString> : GeometryCollection<LineString> {
    
    public override class func geometryTypeId() -> Int32 {
        return 5 // GEOS_MULTILINESTRING
    }

    public required init(GEOSGeom: COpaquePointer, destroyOnDeinit: Bool) {
        super.init(GEOSGeom: GEOSGeom, destroyOnDeinit: destroyOnDeinit)
    }
    private convenience init(GEOSGeom: COpaquePointer) {
        self.init(GEOSGeom: GEOSGeom, destroyOnDeinit: true)
    }
}

public class MultiPoint<T: Waypoint> : GeometryCollection<Waypoint> {
    public override class func geometryTypeId() -> Int32 {
        return 4 // GEOS_MULTIPOINT
    }
    public required init(GEOSGeom: COpaquePointer, destroyOnDeinit: Bool) {
        super.init(GEOSGeom: GEOSGeom, destroyOnDeinit: destroyOnDeinit)
    }
    private convenience init(GEOSGeom: COpaquePointer) {
        self.init(GEOSGeom: GEOSGeom, destroyOnDeinit: true)
    }
}

public class MultiPolygon<T: Polygon> : GeometryCollection<Polygon> {
    public override class func geometryTypeId() -> Int32 {
        return 6 // GEOS_MULTIPOLYGON
    }
    public required init(GEOSGeom: COpaquePointer, destroyOnDeinit: Bool) {
        super.init(GEOSGeom: GEOSGeom, destroyOnDeinit: destroyOnDeinit)
    }
    private convenience init(GEOSGeom: COpaquePointer) {
        self.init(GEOSGeom: GEOSGeom, destroyOnDeinit: true)
    }
}