public protocol SuperModel: class, _Model {
    associatedtype InstanceType: RawRepresentable where InstanceType.RawValue == String
    
    var type: InstanceType { get }
}

public protocol SubModel: SuperModel {
    associatedtype Super: SuperModel where Super.InstanceType == InstanceType
    
    static var instanceType: InstanceType { get }
}

extension MeowCollection where M: SuperModel {
    public var submodels: SubModelCollectionGroup<M> {
        SubModelCollectionGroup(superModelCollection: self)
    }
}

public struct SubModelCollectionGroup<M: SuperModel> {
    let superModelCollection: MeowCollection<M>
    
    public subscript<SM: SubModel>(type: SM.Type) -> SubModelCollection<M, SM> {
        collection(for: type)
    }
    
    public func collection<SM: SubModel>(for type: SM.Type) -> SubModelCollection<M, SM> {
        SubModelCollection(superModelCollection: superModelCollection)
    }
}

public struct SubModelCollection<M: SuperModel, SM: SubModel> {
    let superModelCollection: MeowCollection<M>
    var raw: MongoCollection { superModelCollection.raw }
    
    public func find(where filter: Document = [:]) -> MappedCursor<FindQueryBuilder, SM> {
        return raw.find(filter && "type" == SM.instanceType.rawValue).decode(SM.self)
    }
    
    public func find<Q: MongoKittenQuery>(where filter: Q) -> MappedCursor<FindQueryBuilder, SM> {
        return self.find(where: filter.makeDocument())
    }
    
    public func findOne(where filter: Document) -> EventLoopFuture<SM?> {
        return raw.findOne(filter && "type" == SM.instanceType.rawValue, as: SM.self)
    }
    
    public func findOne<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<SM?> {
        return raw.findOne(filter && "type" == SM.instanceType.rawValue, as: SM.self)
    }
    
    public func count(where filter: Document) -> EventLoopFuture<Int> {
        return raw.count(filter && "type" == SM.instanceType.rawValue)
    }
    
    public func count<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<Int> {
        return self.count(where: filter.makeDocument())
    }
}
