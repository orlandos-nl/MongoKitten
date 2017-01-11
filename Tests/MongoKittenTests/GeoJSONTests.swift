//
//  GeoJSONTests.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 10/01/2017.
//
//


import XCTest
@testable import MongoKitten
import CryptoKitten
import Dispatch

class GeoJSONTests: XCTestCase {
    static var allTests: [(String, (GeoJSONTests) -> () throws -> Void)] {
        return [
            ("testPositionHashable", testPositionHashable),
            ("testPositionInit", testPositionInit),
            ("testPolygonInit", testPolygonInit),
            ("testPolygonDocument", testPolygonDocument)
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


    func testPolygonInit() throws  {

        XCTAssertThrowsError(try Polygon(exterior: [Position(values: [1.0,1.0])]))
        XCTAssertThrowsError(try Polygon(exterior: [Position(values: [1.0,1.0]), Position(values: [1.0,2.0]),Position(values: [2.0,2.0]), Position(values: [2.0,1.0])]))

        let polygon = try Polygon(exterior: [Position(values: [1.0,1.0]), Position(values: [1.0,2.0]),Position(values: [2.0,2.0]), Position(values: [1.0,1.0])])
        XCTAssertNotNil(polygon)
    }

    func testPolygonDocument() throws {
        let polygon = try Polygon(exterior: [Position(values: [1.0,1.0]), Position(values: [1.0,2.0]),Position(values: [2.0,2.0]), Position(values: [1.0,1.0])])
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
}
