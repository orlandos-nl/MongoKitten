// import Foundation
// import XCTest
// @testable import Meow
// import MongoKitten

// class KeyPathQueryTests: XCTestCase {
//     func testBasicKeyPathQueryGeneration() throws {
//         let user = QueryMatcher<User>()
//         let id = ObjectId()
//         let name = "Bert"
//         let matchesId: Document = [
//             "_id": [
//                 "$eq": id
//             ]
//         ]
//         let matchesName: Document = [
//             "name": [
//                 "$eq": name
//             ]
//         ]
        
//         XCTAssertEqual(user._id == id, matchesId)
//         XCTAssertEqual(user.name == name, matchesName)
        
//         XCTAssertEqual(
//             (user._id == id && user.name == name).makeDocument(),
//             AndQuery(conditions: [matchesId, matchesName]).makeDocument()
//         )
//     }
// }

// fileprivate final class User: KeyPathQueryableModel {
//     struct Profile: Codable {
//         let name: String
//     }
    
//     let _id: ObjectId
//     var name: String
//     var profile: Profile
    
//     static var keyPathMap: [AnyKeyPath: [String]] = [
//         \User._id: ["_id"],
//         \User.name: ["name"],
//         \User.profile: ["profile"],
//         \User.profile.name: ["profile", "name"]
//     ]
    
//     static func makePathComponents<T>(forKeyPath keyPath: KeyPath<User, T>) -> [String] {
//         return keyPathMap[keyPath]!
//     }
// }
