import Foundation
import BSON

//public struct Pipeline: ExpressibleByArrayLiteral {
//    var document: Document
//    
//    /// A stage in the aggregate
//    public enum Stage: ValueConvertible {
//        /// Takes a `Projection` that defines the inclusions or the exclusion of _id
//        ///
//        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/project/#pipe._S_project
//        case project(Projection)
//        
//        /// Filters the documents to pass only the documents that match the specified condition(s) to the next pipeline stage as defined in the provided `Query`
//        case match(Query)
//        
//        /// Limits the returned results to the provided `Int` of results
//        ///
//        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/limit/#pipe._S_limit
//        case limit(Int)
//        
//        /// Takes the documents returned by the aggregation pipelien and writes them to a specified collection. This `Stage` must be the last stage in the pipeline.
//        ///
//        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/out/#pipe._S_out
//        case out(collection: String)
//        
//        /// Performs a left outer join to an unsharded collection in the same database to filter in documents from the “joined” collection for processing
//        ///
//        /// fromCollection is an unshaded collection in the same database to perform the join with
//        ///
//        /// localField is the field from the input documents into the lookup stage
//        ///
//        /// foreignField is the field in the `fromCollection`
//        ///
//        /// as is the name of the array to add to the input documents. The array will contain the matching Documents from the `fromCollection` collection. Will overwrite the existing key if there is one.
//        ///
//        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/#pipe._S_lookup
//        case lookup(fromCollection: String, localfield: String, foreignField: String, as: String)
//        
//        /// Sorts all input documents and puts them in the pipeline in the sorted order
//        ///
//        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/sort/#pipe._S_sort
//        case sort(Sort)
//        
//        /// Randomly selects N Documents from the aggregation pipeline input where N is the inputted size.
//        ///
//        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/sample/#pipe._S_sample
//        case sample(size: Int)
//        
//        /// For more information: https://docs.mongodb.com/manual/reference/operator/aggregation/unwind/#pipe._S_unwind
//        case unwind(path: String, includeArrayIndex: String?, preserveNullAndEmptyArrays: Bool?)
//        
//        /// Skips over the specified number of documents that pass into the stage and passes the remaining documents to the next stage in the pipeline.
//        case skip(Int)
//        
//        /// Creates a geoNear aggregate with the provided options as described [here](https://docs.mongodb.com/manual/reference/operator/aggregation/geoNear/#pipe._S_geoNear)
//        case geoNear(options: Document)
//        
//        case group(Document)
//        
//        /// Creates a custom aggregate stage using the provided Document
//        ///
//        /// Used for aggregations that MongoKitten does not support
//        case custom(Document)
//        
//        public func makeBSONPrimitive() -> BSONPrimitive {
//            switch self {
//            case .custom(let doc):
//                return doc
//            case .project(let projection):
//                return [
//                    "$project": projection.makeBSONPrimitive()
//                    ] as Document
//            case .match(let query):
//                return [
//                    "$match": query
//                    ] as Document
//            case .limit(let limit):
//                return [
//                    "$limit": limit
//                    ] as Document
//            case .out(let collection):
//                return ["$out": collection] as Document
//            case .lookup(let from, let localField, let foreignField, let namedAs):
//                return ["$lookup": [
//                    "from": from,
//                    "localField": localField,
//                    "foreignField": foreignField,
//                    "as": namedAs
//                    ] as Document
//                    ] as Document
//            case .sort(let sort):
//                return ["$sort": sort] as Document
//            case .sample(let size):
//                return ["$sample": [
//                    ["$size": size] as Document
//                    ] as Document
//                    ] as Document
//            case .unwind(let path, let includeArrayIndex, let preserveNullAndEmptyArrays):
//                let unwind: ValueConvertible
//                
//                if let includeArrayIndex = includeArrayIndex {
//                    var unwind1 = [
//                        "path": path
//                        ] as Document
//                    
//                    unwind1["includeArrayIndex"] = includeArrayIndex
//                    
//                    if let preserveNullAndEmptyArrays = preserveNullAndEmptyArrays {
//                        unwind1["preserveNullAndEmptyArrays"] = preserveNullAndEmptyArrays
//                    }
//                    
//                    unwind = unwind1
//                } else if let preserveNullAndEmptyArrays = preserveNullAndEmptyArrays {
//                    unwind = [
//                        "path": path,
//                        "preserveNullAndEmptyArrays": preserveNullAndEmptyArrays
//                        ] as Document
//                } else {
//                    unwind = path
//                }
//                
//                return [
//                    "$unwind": unwind
//                    ] as Document
//            case .skip(let amount):
//                return ["$skip": amount] as Document
//            case .geoNear(let options):
//                return ["$geoNear": options] as Document
//            case .group(let document):
//                return ["$group": document] as Document
//            }
//        }
//    }
//    
//    public init(_ document: Document) {
//        self.document = document
//    }
//    
//    public init(arrayLiteral elements: Stage...) {
//        self.document = Document(array: elements.map {
//            $0
//        })
//    }
//}
