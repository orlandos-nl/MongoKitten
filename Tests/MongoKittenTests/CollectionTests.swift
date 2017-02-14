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
import MongoKitten
import Dispatch

class CollectionTests: XCTestCase {
    static var allTests: [(String, (CollectionTests) -> () throws -> Void)] {
        return [
            ("testUniqueIndex", testUniqueIndex),
            ("testQuery", testQuery),
            ("testRename", testRename),
            ("testDistinct", testDistinct),
            ("testFind", testFind),
            ("testDBRef", testDBRef),
            ("testProjection", testProjection),
            ("testIndexes", testIndexes),
            ("testDropIndex", testDropIndex),
            ("testTextOperator", testTextOperator),
            ("testUpdate", testUpdate),
            ("testRemovingAll", testRemovingAll),
            ("testRemovingOne", testRemovingOne),
            ("testHelperObjects", testHelperObjects),
            ("testFindAndModify", testFindAndModify),
            ("testDocumentValidation", testDocumentValidation),
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        do {
            try TestManager.clean()
        } catch {
            fatalError("\(error)")
        }
    }
    
    override func tearDown() {
        // Cleaning
        try! TestManager.disconnect()
    }
    
    func testDocumentValidation() throws {
        for db in TestManager.dbs {
            if db.server.buildInfo.version < Version(3, 2, 0) {
                return
            }
            
            try db["validationtest"].drop()
            
            let validator: Query = "username" == "henk" && "age" > 21 && "drinks" == "beer"
            let collection = try db.createCollection(named: "validationtest", validatedBy: validator)
            
            XCTAssertThrowsError(try collection.insert([
                "username": "henk",
                "age": 12,
                "drinks": "beer"
                ]))
            
            XCTAssertThrowsError(try collection.insert([
                "username": "henk",
                "age": 40,
                "drinks": "coca cola"
                ]))
            
            XCTAssertThrowsError(try collection.insert([
                "username": "gerrit",
                "age": 21,
                "drinks": "beer"
                ]))
            
            _ = try collection.insert([
                "username": "henk",
                "age": 22,
                "drinks": "beer"
                ])
            
            _ = try collection.insert([
                "username": "henk",
                "age": 42,
                "drinks": "beer"
                ])
        }
    }
    
    func testQuery() throws {
        let query: Query = "name_first" == "Henk"
        
        XCTAssertEqual(query.makeDocument(), [
            "name_first": ["$eq": "Henk"] as Document
            ])
        
        let query2: Query = "textSearchTerm"
        
        XCTAssertEqual(query2.makeDocument(), ["$text": [
            "$search": "textSearchTerm",
            "$caseSensitive": false,
            "$diacriticSensitive": false
            ] as Document
            ])
        
        let andQuery: Query = ("username" == "henk" && "age" > 2) && ("password" == "bob" && "age" < 12)
        
        XCTAssertEqual(andQuery.queryDocument, [
            "$and": [
                ["username": ["$eq": "henk"] as Document] as Document,
                ["age": ["$gt": 2] as Document ] as Document,
                ["password": ["$eq": "bob"] as Document] as Document,
                ["age":
                    ["$lt": 12] as Document
                    ] as Document
                ] as Document
            ] as Document)
        
        let notQuery: Query = !("username" == "henk")
        
        XCTAssertEqual(notQuery.queryDocument, [
            "username": [
                "$not": [
                    "$eq": "henk"
                    ] as Document
                ] as Document
            ] as Document)
    }
    
    func testRename() throws {
        for db in TestManager.dbs {
            try db["zips"].rename(to: "zipschange")
            
            let pipeline: AggregationPipeline = [
                .grouping("$state", computed: ["totalPop": .sumOf("$pop")]),
                .matching("totalPop" > 10_000_000),
                .sortedBy(["totalPop": .ascending]),
                .projecting(["_id": false, "totalPop": true]),
                .skipping(2)
            ]
            
            var zipsDocs = Array(try db["zips"].aggregate(pipeline: pipeline))
            XCTAssertEqual(zipsDocs.count, 0)
            
            zipsDocs = Array(try db["zipschange"].aggregate(pipeline: pipeline))
            XCTAssertEqual(zipsDocs.count, 5)
            
            try db["zipschange"].rename(to: "zips")
            
            zipsDocs = Array(try db["zips"].aggregate(pipeline: pipeline))
            XCTAssertEqual(zipsDocs.count, 5)
            
            zipsDocs = Array(try db["zipschange"].aggregate(pipeline: pipeline))
            XCTAssertEqual(zipsDocs.count, 0)
        }
    }
    
    func testDistinct() throws {
        for db in TestManager.dbs {
            let distinct = try db["zips"].distinct(onField: "state")
            
            XCTAssertEqual(distinct?.count, 51)
        }
    }

    func testDistinctWithFilter() throws {

        for db in TestManager.dbs {
            let query = Query(aqt: .startsWith(key: "state", val: "A"))
            let distinct = try db["zips"].distinct(on: "state", usingFilter: query)
            XCTAssertEqual(distinct?.count, 4)
        }

    }
    
    //    func testPerformance() throws {
    //        let collection = TestManager.db["zips"]
    //        var documents = [Document]()
    //        documents.reserveCapacity(29353)
    //
    //        func testQueue(max: Int = 10) {
    //            let perQueue = 25_000 / max
    //
    //            for i in 0..<max {
    //                let start = i * perQueue
    //
    //                let q = DispatchQueue(label: "org.openkitten.tests.performance.\(i)")
    //                let e = expectation(description: "kaas \(i)")
    //
    //                q.async {
    //                    for j in start..<start+perQueue {
    //                        _ = try! collection.findOne(skipping: Int32(j))
    //                    }
    //
    //                    e.fulfill()
    //                }
    //            }
    //        }
    //
    //        testQueue()
    //
    //        waitForExpectations(timeout: 300)
    //    }
    
    
    
    func testFind() throws {
        for db in TestManager.dbs {
            let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
            
            var inserts: [Document]
            
            var brokenUsername = base
            var brokenAge = base
            var brokenKittens = base
            var brokenKittens2 = base
            var brokenDogs = base
            var brokenBeers = base
            
            brokenUsername["username"] = "harrie"
            brokenAge["age"] = 24
            brokenKittens["kittens"] = 3
            brokenKittens2["kittens"] = 1
            brokenDogs["dogs"] = 2
            brokenBeers["beers"] = "broken"
            
            inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
            
            _ = try db["wcol"].insert(inserts)
            
            let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
            
            let response = Array(try db["wcol"].find(matching: query))
            
            let response2 = try db["wcol"].findOne(matching: query)!
            
            XCTAssertEqual(response.count, 2)
            
            XCTAssertEqual(response.first, response2)
            
            try runContainsQuery(onDB: db)
            try runContainsCaseInsensitiveQuery(onDB: db)
            try runStartsWithQuery(onDB: db)
            try runEndsWithQuery(onDB: db)
        }
    }
    
    func testDBRef() throws {
        for db in TestManager.dbs {
            let colA = db["collectionA"]
            let colB = db["collectionB"]
            
            let id = try colA.insert(["name": "Harrie Bob"] as Document)
            
            let dbref = DBRef(referencing: id, inCollection: colA)
            
            let referenceID = try colB.insert(["reference": dbref] as Document)
            
            guard let reference = try colB.findOne(matching: "_id" == referenceID) else {
                XCTFail()
                return
            }
            
            guard let colAreference = DBRef(reference["reference"] as Document? ?? [:], inDatabase: db) else {
                XCTFail()
                return
            }
            
            guard let originalDocument = try colAreference.resolve() else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(originalDocument["name"] as String?, "Harrie Bob")
        }
    }

    func testFindProjection() throws {
        for db in TestManager.dbs {
            let results = Array(try db["zips"].find(matching: "city" == "BARRE", projecting: ["city","pop"] as Projection))

            XCTAssertEqual(results.count, 2)
            XCTAssertNil(results.first?[raw: "state"]?.string)
            XCTAssertNotNil(results.first?[raw: "city"]?.string)
            XCTAssertEqual(results.first?[raw: "city"]?.string, "BARRE")
            XCTAssertNotNil(results.first?[raw: "pop"]?.int)
        }
    }
    
    func testProjection() {
        let projection: Projection = ["name", "age", "awesome"]
        
        XCTAssertEqual(projection.makeBSONPrimitive() as? Document, ["name": true, "age": true, "awesome": true] as Document)
        
        let projection2: Projection = ["henk": .included, "bob": .excluded]
        
        XCTAssertEqual(projection2.makeBSONPrimitive() as? Document, ["henk": true, "bob": false])
    }
    
    func testIndexes() throws {
        loop: for db in TestManager.dbs {
            // TODO: Partially enable for 3.0
            if db.server.buildInfo.version < Version(3, 2, 0) {
                return
            }
            
            try db["wcol"].createIndex(named: "henkbob", withParameters: .sortedCompound(fields: [("name", .ascending), ("age", .descending)]), .expire(afterSeconds: 1), .buildInBackground)
            
            let harriebob = db["harriebob"]
            
            try harriebob.createIndex(named: "imdifferent", withParameters: .unique, .compound(fields: [("unique", Int32(1))]))
            
            try harriebob.insert(["unique": true])
            try harriebob.insert(["unique": false])
            try harriebob.insert(["unique": Null()])
            XCTAssertThrowsError(try harriebob.insert(["unique": true]))
            XCTAssertThrowsError(try harriebob.insert(["unique": false]))
            XCTAssertThrowsError(try harriebob.insert(["unique": Null()]))
            
            for index in try db["wcol"].listIndexes() where index["name"] as String? == "henkbob" {
                continue loop
            }
            
            XCTFail()
        }
    }

    func testDropIndex() throws {
        for db in TestManager.dbs {
            let collection = db["mycollection"]
            try collection.insert(["name":"john"] as Document)

            try collection.createIndex(named: "name_index", withParameters: .sort(field: "name", order: .ascending))

            try collection.dropIndex(named: "name_index")            
        }
    }

    private func runContainsQuery(onDB db: Database) throws {
        let query = Query(aqt: .contains(key: "username", val: "ar", options: []))
        let response = Array(try db["wcol"].find(matching: query))
        XCTAssert(response.count == 2)
    }
    
    private func runStartsWithQuery(onDB db: Database) throws {
        let query = Query(aqt: .startsWith(key: "username", val: "har"))
        let response = Array(try db["wcol"].find(matching: query))
        XCTAssert(response.count == 2)
    }
    
    private func runEndsWithQuery(onDB db: Database) throws {
        let query = Query(aqt: .endsWith(key: "username", val: "rrie"))
        let response = Array(try db["wcol"].find(matching: query))
        XCTAssert(response.count == 2)
    }
    
    private func runContainsCaseInsensitiveQuery(onDB db: Database) throws {
        let query = Query(aqt: .contains(key: "username", val: "AR", options: .caseInsensitive))
        let response = Array(try db["wcol"].find(matching: query))
        XCTAssert(response.count == 2)
    }


    
    
    
    func testTextOperator() throws {
        for db in TestManager.dbs {
            if db.server.buildInfo.version < Version(3, 2, 0) {
                return
            }
            
            let textSearch = db["textsearch"]
            try textSearch.createIndex(named: "subject", withParameters: .text(["subject"]))
            
            try textSearch.remove(matching: Query([:]))
            
            try textSearch.insert([
                ["_id": 1, "subject": "coffee", "author": "xyz", "views": 50] as Document,
                ["_id": 2, "subject": "Coffee Shopping", "author": "efg", "views": 5] as Document,
                ["_id": 3, "subject": "Baking a cake", "author": "abc", "views": 90] as Document,
                ["_id": 4, "subject": "baking", "author": "xyz", "views": 100] as Document,
                ["_id": 5, "subject": "Café Con Leche", "author": "abc", "views": 200] as Document,
                ["_id": 6, "subject": "Сырники", "author": "jkl", "views": 80] as Document,
                ["_id": 7, "subject": "coffee and cream", "author": "efg", "views": 10] as Document,
                ["_id": 8, "subject": "Cafe con Leche", "author": "xyz", "views": 10] as Document
                ])
            
            let resultCount = try textSearch.count(matching: .textSearch(forString: "coffee"))
            
            XCTAssertEqual(resultCount, 3)
        }
    }
    
    func testUpdate() throws {
        for db in TestManager.dbs {
            let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
            
            var inserts: [Document]
            
            var brokenUsername = base
            var brokenAge = base
            var brokenKittens = base
            var brokenKittens2 = base
            var brokenDogs = base
            var brokenBeers = base
            
            brokenUsername["username"] = "harrie"
            brokenAge["age"] = 24
            brokenKittens["kittens"] = 3
            brokenKittens2["kittens"] = 1
            brokenDogs["dogs"] = 2
            brokenBeers["beers"] = "broken"
            
            inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
            try db["wcol"].insert(inserts)
            
            let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
            
            try db["wcol"].update(matching: query, to: ["testieBool": true])
            
            try db.server.fsync()
            
            let response = Array(try db["wcol"].find(matching: "testieBool" == true))
            XCTAssertEqual(response.count, 1)
            
            let response2 = Array(try db["wcol"].find(matching: query))
            XCTAssertEqual(response2.count, 1)
        }
    }
    
    func testRemovingAll() throws {
        for db in TestManager.dbs {
            let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
            
            var inserts: [Document]
            
            var brokenUsername = base
            var brokenAge = base
            var brokenKittens = base
            var brokenKittens2 = base
            var brokenDogs = base
            var brokenBeers = base
            
            brokenUsername["username"] = "harrie"
            brokenAge["age"] = 24
            brokenKittens["kittens"] = 3
            brokenKittens2["kittens"] = 1
            brokenDogs["dogs"] = 2
            brokenBeers["beers"] = "broken"
            
            inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
            
            _ = try db["wcol"].insert(inserts)
            
            let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
            
            XCTAssertGreaterThan(try db["wcol"].remove(matching: query), 0)
            
            let response = Array(try db["wcol"].find(matching: query))
            
            XCTAssertEqual(response.count, 0)
        }
    }
    
    func testRemovingOne() throws {
        for db in TestManager.dbs {
            let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
            
            var inserts: [Document]
            
            var brokenUsername = base
            var brokenAge = base
            var brokenKittens = base
            var brokenKittens2 = base
            var brokenDogs = base
            var brokenBeers = base
            
            brokenUsername["username"] = "harrie"
            brokenAge["age"] = 24
            brokenKittens["kittens"] = 3
            brokenKittens2["kittens"] = 1
            brokenDogs["dogs"] = 2
            brokenBeers["beers"] = "broken"
            
            inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
            
            try db["wcol"].insert(inserts)
            
            let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
            
            XCTAssertEqual(try db["wcol"].remove(matching: query, limitedTo: 1), 1)
            try db.server.fsync()
            
            let response = Array(try db["wcol"].find(matching: query))
            
            XCTAssertEqual(response.count, 1)
        }
    }
    
    func testHelperObjects() {
        let document = [
            "henk": 1 as Int32,
            "klaas": -1 as Int32,
            "roekoe": 1 as Int32
            ] as Document
        let sort = Sort(document)
        
        XCTAssertEqual(document, sort.makeDocument())
        
        let sort2: Sort = [
            "date": .ascending,
            "name": .descending,
            "kaas": .custom(true)
        ]
        
        XCTAssertEqual(sort2.makeDocument(), [
            "date": Int32(1),
            "name": Int32(-1),
            "kaas": true
            ])
    }
    
    
    func testFindAndModify() throws {
        for db in TestManager.dbs {
            let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
            
            var inserts: [Document]
            
            var brokenUsername = base
            var brokenAge = base
            var brokenKittens = base
            var brokenKittens2 = base
            var brokenDogs = base
            var brokenBeers = base
            
            brokenUsername["username"] = "harrie"
            brokenAge["age"] = 24
            brokenKittens["kittens"] = 3
            brokenKittens2["kittens"] = 1
            brokenDogs["dogs"] = 2
            brokenBeers["beers"] = "broken"
            
            inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
            try db["wcol"].insert(inserts)
            
            let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
            
            let modifiedDocument = try db["wcol"].findAndModify(matching: query, action: .update(with: ["testieBool": true], returnModified: true, upserting: false) )
            
            XCTAssertNotNil(modifiedDocument.documentValue)
            
            let response = Array(try db["wcol"].find(matching: "testieBool" == true))
            XCTAssertEqual(response.count, 1)
            
            let response2 = Array(try db["wcol"].find(matching: query))
            XCTAssertEqual(response2.count, 1)
        }
    }
    
    
    
    func testUniqueIndex() throws {
        for db in TestManager.dbs {
            let alphabetCollection = db["alphabet"]
            try alphabetCollection.createIndex(named: "letter", withParameters:.sort(field: "letter", order: .ascending),.unique)
            
            let aDocument: Document = ["letter":"A"]
            let id = try alphabetCollection.insert(aDocument)
            XCTAssertNotNil(id)
            
            let aBisDocument: Document = ["letter":"A"]
            
            XCTAssertThrowsError(try alphabetCollection.insert(aBisDocument))
            try db["alphabet"].drop()
        }
    }
    
}
