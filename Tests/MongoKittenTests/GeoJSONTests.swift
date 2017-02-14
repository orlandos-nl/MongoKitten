//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//


import XCTest
@testable import MongoKitten
@testable import GeoJSON


class GeoJSONTests: XCTestCase {
    static var allTests: [(String, (GeoJSONTests) -> () throws -> Void)] {
        return [
            ("testPositionHashable", testPositionHashable),
            ("testPositionInit", testPositionInit),
            ("testPolygonInit", testPolygonInit),
            ("testPolygonDocument", testPolygonDocument),
            ("testPolygonHashable", testPolygonHashable),
            ("testPointHashable", testPointHashable),
            ("testCRS", testCRS)
        ]
    }


    func testPositionHashable() throws {
        let position1 = try Position(values: [1.54545, 2.87876, 3.5454646])
        let position2 = try Position(values: [1.54545, 2.87876, 3.5454647])
        let position3 = try Position(values: [1.54545, 2.87876, 3.5454646])
        let position4 = try Position(values: [1.0, 2.0, 3.0])
        let position5 = try Position(values: [1.0, 3.0, 2.0])

        XCTAssertNotEqual(position1, position2)
        XCTAssertNotEqual(position1.hashValue, position2.hashValue)


        XCTAssertNotEqual(position1, position4)
        XCTAssertNotEqual(position1.hashValue, position4.hashValue)

        XCTAssertNotEqual(position5, position4)
        XCTAssertNotEqual(position5.hashValue, position4.hashValue)

        XCTAssertEqual(position1, position3)
        XCTAssertEqual(position1.hashValue, position3.hashValue)
    }

    func testPositionInit()  {

        XCTAssertThrowsError(try Position(values: [1.0]))

        do {
            let position = try Position(values: [1.0,2.0])
            XCTAssertNotNil(position)
        } catch {
            XCTFail()
        }

        let position2 = Position(first: 1.0, second: 1.0)
        XCTAssertNotNil(position2)
        XCTAssertEqual(position2.values.count, 2)

        let position3 = Position(first: 1.0, second: 1.0, remaining: 3.0, 4.0)
        XCTAssertNotNil(position3)
        XCTAssertEqual(position3.values.count, 4)
    }


    func testPointHashable() throws {

        let point1 = try Point(coordinate: Position(values: [1.0,1.0]))
        let point2 = try Point(coordinate: Position(values: [1.0,1.0]))
        let point3 = try Point(coordinate: Position(values: [1.0,1.1]))

        XCTAssertEqual(point1, point2)
        XCTAssertEqual(point1.hashValue, point2.hashValue)
        XCTAssertNotEqual(point1, point3)
        XCTAssertNotEqual(point1.hashValue, point3.hashValue)
    }

    func testPolygonInit() throws  {

        XCTAssertThrowsError(try Polygon(exterior: [Position(values: [1.0,1.0])]))
        XCTAssertThrowsError(try Polygon(exterior: [Position(values: [1.0,1.0]), Position(values: [1.0,2.0]),Position(values: [2.0,2.0]), Position(values: [2.0,1.0])]))

        let polygon = try Polygon(exterior: [Position(values: [1.0,1.0]), Position(values: [1.0,2.0]),Position(values: [2.0,2.0]), Position(values: [1.0,1.0])])
        XCTAssertNotNil(polygon)
    }

    func testPolygonDocument() throws {
        let polygon = try Polygon(exterior: [Position(values: [0.0, 0.0]), Position(values: [0.0,4.0]),Position(values: [4.0,4.0]), Position(values: [4.0,0.0]), Position(values: [0.0,0.0])])
        XCTAssertNotNil(polygon)

        let polyDoc = polygon.makeBSONPrimitive()
        guard let polyDico = polyDoc.documentValue?.dictionaryValue else { XCTFail(); return }
        guard let exter = polyDico["coordinates"]?.documentValue?.arrayValue else { XCTFail(); return }
        XCTAssertEqual(exter.count, 1) // One Exterior ring 

        let exterior  = try [Position(values: [100.0, 0.0]), Position(values: [101.0, 0.0]),Position(values: [101.0, 1.0]), Position(values: [100.0, 1.0]), Position(values: [100.0, 0.0])]
        let hole =  try [Position(values: [100.2, 0.2]),Position(values: [100.8, 0.2]), Position(values: [100.8, 0.8]),Position(values: [100.2, 0.8]),Position(values: [100.2, 0.2])]

        let polygonWithHole = try Polygon(exterior:exterior, holes:hole)
        XCTAssertNotNil(polygonWithHole)
  
        let polygonHoleDoc = polygonWithHole.makeBSONPrimitive()
        guard let dic = polygonHoleDoc.documentValue?.dictionaryValue else { XCTFail(); return }
        guard let coordinates = dic["coordinates"]?.documentValue?.arrayValue else { XCTFail(); return }
        XCTAssertEqual(coordinates.count, 2) // One Exterior ring and One Hole ring
    }

    func testPolygonHashable() throws {
        let polygon1 = try Polygon(exterior: [Position(values: [1.0,1.0]), Position(values: [1.0,2.0]),Position(values: [2.0,2.0]), Position(values: [1.0,1.0])])
        let polygon2 = try Polygon(exterior: [Position(values: [1.0,1.0]), Position(values: [1.0,2.0]),Position(values: [2.0,2.0]), Position(values: [1.0,1.0])])

        XCTAssertEqual(polygon1, polygon2)
        XCTAssertEqual(polygon1.hashValue, polygon2.hashValue)

        let exterior  = try [Position(values: [100.0, 0.0]), Position(values: [101.0, 0.0]),Position(values: [101.0, 1.0]), Position(values: [100.0, 1.0]), Position(values: [100.0, 0.0])]
        let hole =  try [Position(values: [100.2, 0.2]),Position(values: [100.8, 0.2]), Position(values: [100.8, 0.8]),Position(values: [100.2, 0.8]),Position(values: [100.2, 0.2])]

        let hole2 =  try [Position(values: [100.0, 0.2]),Position(values: [100.8, 0.2]), Position(values: [100.8, 0.8]),Position(values: [100.2, 0.8]),Position(values: [100.0, 0.2])]

        let polygonWithHole1 = try Polygon(exterior:exterior, holes:hole)
        let polygonWithHole2 = try Polygon(exterior:exterior, holes:hole)
        let polygonWithHole3 = try Polygon(exterior:exterior, holes:hole2)

        XCTAssertEqual(polygonWithHole1, polygonWithHole2)
        XCTAssertEqual(polygonWithHole1.hashValue, polygonWithHole2.hashValue)

        XCTAssertNotEqual(polygon1, polygonWithHole1)
        XCTAssertNotEqual(polygon1.hashValue, polygonWithHole1.hashValue)

        XCTAssertNotEqual(polygonWithHole1, polygonWithHole3)
        XCTAssertNotEqual(polygonWithHole1.hashValue, polygonWithHole3.hashValue)
    }

    func testCRS() {
        let crsTest = CoordinateReferenceSystem(typeName: "urn:x-mongodb:crs:strictwinding:EPSG:4326")
        XCTAssertEqual(crsTest.typeName, "urn:x-mongodb:crs:strictwinding:EPSG:4326")

        let crsLiteral = CoordinateReferenceSystem(stringLiteral: "CRS84_TEST")
        XCTAssertEqual(crsLiteral.typeName, "CRS84_TEST")

        let crsGLiteral = CoordinateReferenceSystem(extendedGraphemeClusterLiteral: "CRS84_TEST_GRAPHEME")
        XCTAssertEqual(crsGLiteral.typeName, "CRS84_TEST_GRAPHEME")

        let crsUni = CoordinateReferenceSystem(unicodeScalarLiteral: "CRS84_TEST_UNI")
        XCTAssertEqual(crsUni.typeName, "CRS84_TEST_UNI")

        let strict = MongoCRS.strictCRS
        let crs84 = MongoCRS.crs84CRS
        let epsg = MongoCRS.epsg4326CRS

        XCTAssertEqual(strict.rawValue.typeName, "urn:x-mongodb:crs:strictwinding:EPSG:4326")
        XCTAssertEqual(crs84.rawValue.typeName, "urn:ogc:def:crs:OGC:1.3:CRS84")
        XCTAssertEqual(epsg.rawValue.typeName, "EPSG:4326")

        XCTAssertEqual(crsTest, strict.rawValue)
        XCTAssertEqual(crsTest.hashValue, strict.rawValue.hashValue)

        XCTAssertNotEqual(strict.rawValue, crs84.rawValue)
        XCTAssertNotEqual(strict.rawValue.hashValue, crs84.rawValue.hashValue)

        let crsDocument = strict.rawValue.makeBSONPrimitive()
        guard let dic = crsDocument.documentValue?.dictionaryValue else { XCTFail(); return }
        guard let properties = dic["properties"]?.documentValue?.dictionaryValue else { XCTFail(); return }
        guard let typeName = properties["name"] as? String else { XCTFail(); return }
        XCTAssertEqual(typeName, "urn:x-mongodb:crs:strictwinding:EPSG:4326")


    }
}
