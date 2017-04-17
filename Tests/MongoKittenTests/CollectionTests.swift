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
import Schrodinger

class CollectionTests: XCTestCase {
    static var allTests: [(String, (CollectionTests) -> () throws -> Void)] {
        return [
            ("testEverything", testEverything),
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
            ("testInsertErrors", testInsertErrors),
            ("testUpdateErrors", testUpdateErrors),
        ]
    }
    
    var superQuery: Query {
        let q: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2
        let q2: Query = "kittens" != 3 && "dogs" <= 1 && "beers" < 100
        return q && q2
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
    
    func testCollectionSlice() throws {
        for db in TestManager.dbs {
            var counter = 0
            
            let zips = try db["zips"].find(withBatchSize: 300)
            
            XCTAssertEqual(try zips.count(), 29353)
            
            for _ in zips {
                counter += 1
            }

            XCTAssertEqual(counter, 29353)
        }
    }
    
    func testEverything() throws {
        let everything: [() throws -> Void] = [
            testUniqueIndex,
            testQuery,
            testRename,
            testFind,
            testDBRef,
            testProjection,
            testIndexes,
            testDropIndex,
            testTextOperator,
            testUpdate,
            testRemovingAll,
            testRemovingOne,
            testHelperObjects,
            testFindAndModify,
            testDocumentValidation,
            testInsertErrors,
            testUpdateErrors,
            ]
        
        var futures = [Promise<Void>]()
        
        for test in everything {
            let future = async {
                try test()
            }

            futures.append(future)
        }

        for future in futures {
            _ = try future.await()
        }
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
            "name_first": ["$eq": "Henk"]
            ])
        
        let query2: Query = "textSearchTerm"
        
        XCTAssertEqual(query2.makeDocument(), ["$text": [
            "$search": "textSearchTerm",
            "$caseSensitive": false,
            "$diacriticSensitive": false
            ]
            ])
        
        let andQuery: Query = ("username" == "henk" && "age" > 2) && ("password" == "bob" && "age" < 12)
        
        XCTAssertEqual(andQuery.queryDocument, [
            "$and": [
                ["username": ["$eq": "henk"]],
                ["age": ["$gt": 2] ],
                ["password": ["$eq": "bob"]],
                ["age":
                    ["$lt": 12]
                    ]
                ]
            ])
        
        let notQuery: Query = !("username" == "henk")
        
        XCTAssertEqual(notQuery.queryDocument, [
            "username": [
                "$not": [
                    "$eq": "henk"
                    ]
                ]
            ])
    }
    
    func testRename() throws {
        for db in TestManager.dbs {
            try db["zips"].rename(to: "zipschange")
            
            try db.server.fsync(blocking: true)
            
            let pipeline: AggregationPipeline = [
                .group("$state", computed: ["totalPop": .sumOf("$pop")]),
                .match("totalPop" > 10_000_000),
                .sort(["totalPop": .ascending]),
                .project(["_id": false, "totalPop": true]),
                .skip(2)
            ]
            
            var zipsDocs = Array(try db["zips"].aggregate(pipeline))
            XCTAssertEqual(zipsDocs.count, 0)
            
            zipsDocs = Array(try db["zipschange"].aggregate(pipeline))
            XCTAssertEqual(zipsDocs.count, 5)
            
            try db["zipschange"].rename(to: "zips")
            
            try db.server.fsync(blocking: true)
            
            zipsDocs = Array(try db["zips"].aggregate(pipeline))
            XCTAssertEqual(zipsDocs.count, 5)
            
            zipsDocs = Array(try db["zipschange"].aggregate(pipeline))
            XCTAssertEqual(zipsDocs.count, 0)
        }
    }
    
    func testDistinct() throws {
        for db in TestManager.dbs {
            let distinct = try db["zips"].distinct(on: "state")
            
            XCTAssertEqual(distinct?.count, 51)
        }
    }

    func testDistinctWithFilter() throws {

        for db in TestManager.dbs {
            let query = Query(aqt: .startsWith(key: "state", val: "A"))
            let distinct = try db["zips"].distinct(on: "state", filtering: query)
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
            
            _ = try db["findTest"].insert(contentsOf: inserts)
            
            let response = Array(try db["findTest"].find(superQuery))
            
            guard let response2 = try db["findTest"].findOne(superQuery) else {
                XCTFail()
                return
            }
            
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
            
            let id = try colA.insert(["name": "Harrie Bob"])
            
            let dbref = DBRef(referencing: id, inCollection: colA)
            
            let referenceID = try colB.insert(["reference": dbref])
            
            guard let reference = try colB.findOne("_id" == referenceID) else {
                XCTFail()
                return
            }
            
            guard let colAreference = DBRef(reference["reference"] as? Document ?? [:], inDatabase: db) else {
                XCTFail()
                return
            }
            
            guard let originalDocument = try colAreference.resolve() else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(String(originalDocument["name"]), "Harrie Bob")
        }
    }

    func testFindProjection() throws {
        for db in TestManager.dbs {
            let results = Array(try db["zips"].find("city" == "BARRE", projecting: ["city","pop"] as Projection))

            XCTAssertEqual(results.count, 2)
            XCTAssertNil(String(results.first?["state"]))
            XCTAssertNotNil(String(results.first?["city"]))
            XCTAssertEqual(String(results.first?["city"]), "BARRE")
            XCTAssertNotNil(Int(results.first?["pop"]))
        }
    }
    
    func testProjection() {
        let projection: Projection = ["name", "age", "awesome"]
        
        XCTAssertEqual(projection.makePrimitive() as? Document, ["name": true, "age": true, "awesome": true])
        
        let projection2: Projection = ["henk": .included, "bob": .excluded]
        
        XCTAssertEqual(projection2.makePrimitive() as? Document, ["henk": true, "bob": false])
    }
    
    func testIndexes() throws {
        loop: for db in TestManager.dbs {
            // TODO: Partially enable for 3.0
            if db.server.buildInfo.version < Version(3, 2, 0) {
                continue loop
            }
            
            try db["indexTest"].createIndex(named: "henkbob", withParameters: .sortedCompound(fields: [("name", .ascending), ("age", .descending)]), .expire(afterSeconds: 1), .buildInBackground)
            
            let harriebob = db["harriebob"]
            
            try harriebob.createIndex(named: "imdifferent", withParameters: .unique, .compound(fields: [("unique", Int32(1))]))
            
            try harriebob.insert(["unique": true])
            try harriebob.insert(["unique": false])
            try harriebob.insert(["unique": Null()])
            XCTAssertThrowsError(try harriebob.insert(["unique": true]))
            XCTAssertThrowsError(try harriebob.insert(["unique": false]))
            XCTAssertThrowsError(try harriebob.insert(["unique": Null()]))
            
            for index in try db["indexTest"].listIndexes() where String(index["name"]) == "henkbob" {
                continue loop
            }
            
            XCTFail()
        }
    }

    func testDropIndex() throws {
        for db in TestManager.dbs {
            let collection = db["mycollection"]
            try collection.insert(["name":"john"])

            try collection.createIndex(named: "name_index", withParameters: .sort(field: "name", order: .ascending))

            try collection.dropIndex(named: "name_index")            
        }
    }

    private func runContainsQuery(onDB db: Database) throws {
        let query = Query(aqt: .contains(key: "username", val: "ar", options: []))
        let response = Array(try db["findTest"].find(query))
        XCTAssert(response.count == 2)
    }
    
    private func runStartsWithQuery(onDB db: Database) throws {
        let query = Query(aqt: .startsWith(key: "username", val: "har"))
        let response = Array(try db["findTest"].find(query))
        XCTAssert(response.count == 2)
    }
    
    private func runEndsWithQuery(onDB db: Database) throws {
        let query = Query(aqt: .endsWith(key: "username", val: "rrie"))
        let response = Array(try db["findTest"].find(query))
        XCTAssert(response.count == 2)
    }
    
    private func runContainsCaseInsensitiveQuery(onDB db: Database) throws {
        let query = Query(aqt: .contains(key: "username", val: "AR", options: .caseInsensitive))
        let response = Array(try db["findTest"].find(query))
        XCTAssert(response.count == 2)
    }
    
    func testTextOperator() throws {
        for db in TestManager.dbs {
            guard db.server.buildInfo.version >= Version(3, 2, 0) else {
                continue
            }
            
            let textSearch = db["textsearchTest"]
            try textSearch.createIndex(named: "subject", withParameters: .text(["subject"]))
            
            try textSearch.remove(Query([:]))
            
            try textSearch.insert(contentsOf: [
                ["_id": 1, "subject": "coffee", "author": "xyz", "views": 50],
                ["_id": 2, "subject": "Coffee Shopping", "author": "efg", "views": 5],
                ["_id": 3, "subject": "Baking a cake", "author": "abc", "views": 90],
                ["_id": 4, "subject": "baking", "author": "xyz", "views": 100],
                ["_id": 5, "subject": "Café Con Leche", "author": "abc", "views": 200],
                ["_id": 6, "subject": "Сырники", "author": "jkl", "views": 80],
                ["_id": 7, "subject": "coffee and cream", "author": "efg", "views": 10],
                ["_id": 8, "subject": "Cafe con Leche", "author": "xyz", "views": 10]
                ])
            
            let resultCount = try textSearch.count(.textSearch(forString: "coffee"))
            
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
            try db["updateTest"].insert(contentsOf: inserts)
            
            try db["updateTest"].update(superQuery, to: ["testieBool": true])
            
            try db.server.fsync()
            
            let response = Array(try db["updateTest"].find("testieBool" == true))
            XCTAssertEqual(response.count, 1)
            
            let response2 = Array(try db["updateTest"].find(superQuery))
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
            
            _ = try db["removeAllTest"].insert(contentsOf: inserts)
            
            XCTAssertGreaterThan(try db["removeAllTest"].remove(superQuery), 0)
            
            let response = Array(try db["removeAllTest"].find(superQuery))
            
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
            
            try db["removeOneTest"].insert(contentsOf: inserts)
            
            try db.server.fsync()
            
            XCTAssertEqual(try db["removeOneTest"].remove(superQuery, limiting: 1), 1)
            try db.server.fsync()
            
            let response = Array(try db["removeOneTest"].find(superQuery))
            
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
            try db["findAndModifyTest"].append(contentsOf: inserts)
            
            _ = try db["findAndModifyTest"].findAndUpdate(superQuery, with: ["testieBool": true], upserting: false, returnedDocument: .old, sortedBy: nil, projection: nil)
            
            let response = Array(try db["findAndModifyTest"].find("testieBool" == true))
            XCTAssertEqual(response.count, 1)
            
            let response2 = Array(try db["findAndModifyTest"].find(superQuery))
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
    
    func testInsertErrors() throws {
        for db in TestManager.dbs {
            var documents = [Document]()
            let duplicateID = ObjectId()

            documents.append([
                "_id": duplicateID,
                "data": true
            ])

            documents.append([
                "_id": duplicateID,
                "data": true
            ])

            documents.append([
                "_id": duplicateID,
                "data": true
            ])

            do {
                try db["inserterrors"].append(contentsOf: documents)
                XCTFail()
            } catch let insertErrors as InsertErrors {
                XCTAssertEqual(insertErrors.successfulIds.count, 2)
                XCTAssertEqual(insertErrors.errors.count, 1)
                XCTAssertEqual(insertErrors.errors[0].writeErrors.count, 1)
                XCTAssertEqual(ObjectId(insertErrors.errors[0].writeErrors[0].affectedDocument["_id"]), duplicateID)
            } catch {
                XCTFail()
            }
        }
    }
    
    func testExplain() throws {
        for db in TestManager.dbs {
            try db["explain"].drop()
            
            var docs = [Document]()
            var buffer = [Document]()
            
            for i in 0..<10_000 {
                docs.append([
                        "superKey": i
                    ])
            }
            
            for _ in 0..<5_000 {
                buffer.append([
                        "superKey": ObjectId()
                    ])
            }
            
            try db["explain"].append(contentsOf: buffer)
            try db["explain"].append(contentsOf: docs)
            try db["explain"].append(contentsOf: buffer)
            
            print(try db["explain"].explained.find())
            let explaination = try db["explain"].explained.find("superKey" >= 4_000 && "superKey" <= 6_000)
            
            print(explaination)
            try db["explain"].createIndex(named: "superkey", withParameters: .sort(field: "superKey", order: .ascending))
            
            try db.server.fsync()
            print("")
            print("FSYNC")
            print("")
            
            print(try db["explain"].explained.find())
            print(try db["explain"].explained.find("superKey" >= 4_000 && "superKey" <= 6_000))
        }
    }

    func testUpdateErrors() throws {
        for db in TestManager.dbs {
            var documents = [Document]()
            documents.append([
                "_id": 0,
                "data": true
            ])

            documents.append([
                "_id": 1,
                "data": true
            ])

            documents.append([
                "_id": 2,
                "data": true
            ])

            try db["updateerrors"].append(contentsOf: documents)
            
            try db.server.fsync()
            
            do {
                try db["updateerrors"].update("_id" == 2, to: [
                    "$set": [
                        "_id": 1
                    ]
                ], stoppingOnError: true)
                XCTFail()
            } catch let updateError as UpdateError {
                XCTAssertEqual(updateError.writeErrors.count, 1)
                XCTAssertEqual(updateError.writeErrors[0].affectedQuery.makeDocument(), [
                    "_id": [
                        "$eq": 2
                    ]
                    ])
                
                XCTAssertEqual(updateError.writeErrors[0].affectedUpdate, [
                    "$set": [
                        "_id": 1
                    ]
                    ])
            } catch {
                XCTFail()
            }
        }
    }
}
