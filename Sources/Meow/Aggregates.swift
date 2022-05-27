#if swift(>=5.7)
import MongoCore
import MongoKitten

public protocol MeowAggregateStage: AggregateBuilderStage {
    associatedtype Base: Codable
    associatedtype Result: Codable
}

@resultBuilder public struct MeowAggregateBuilder<M: KeyPathQueryableModel> {
    public static func buildPartialBlock<Stage: MeowAggregateStage>(
        first stage: Stage
    ) -> MeowAggregate<M, Stage.Result> where Stage.Base == M {
        MeowAggregate(stages: [stage])
    }
    
    public static func buildPartialBlock<
        PreviousResult,
        Stage: MeowAggregateStage
    >(
        accumulated base: MeowAggregate<M, PreviousResult>,
        next: Stage
    ) -> MeowAggregate<M, Stage.Result> where Stage.Base == PreviousResult {
        MeowAggregate(stages: base.stages + [next])
    }
}

extension MeowCollection where M: KeyPathQueryableModel {
    public func buildAggregate<Result: Codable>(
        @MeowAggregateBuilder<M> build: () -> MeowAggregate<M, Result>
    ) -> MappedCursor<AggregateBuilderPipeline, Result> {
        return AggregateBuilderPipeline(
            stages: build().stages,
            collection: raw
        ).decode(Result.self)
    }
}

public struct MeowAggregate<Model: KeyPathQueryableModel, Result: Codable> {
    var stages: [AggregateBuilderStage]
}

public protocol ModelProjection: KeyPathQueryableModel {
    associatedtype Base: KeyPathQueryableModel
}

public struct Sort<Base: KeyPathQueryableModel>: MeowAggregateStage {
    public typealias Result = Base
    
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init<T: Comparable>(
        _ type: Base.Type = Base.self,
        by field: KeyPath<Base, QueryableField<T>>,
        direction: Sorting.Order
    ) {
        let field = Base.resolveFieldPath(field).joined(separator: ".")
        
        self.stage = [
            "$sort": [
                field: direction.rawValue
            ] as Document
        ]
    }
}

public struct Match<Base: KeyPathQueryableModel>: MeowAggregateStage {
    public typealias Result = Base
    
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(
        _ type: Base.Type = Base.self,
        matching: (QueryMatcher<Base>) -> Document
    ) {
        let matcher = QueryMatcher<Base>()
        let filter = matching(matcher)
        self.stage = [
            "$match": filter
        ]
    }
}

public struct Lookup<Base: Codable, Foreign: KeyPathQueryableModel, Result: Codable>: MeowAggregateStage {
    private let lookup: MongoKitten.Lookup
    public var stage: Document { lookup.stage }
    public var minimalVersionRequired: MongoCore.WireVersion? { lookup.minimalVersionRequired }
}

extension Lookup where Result == Base {
    public init<FieldValue, FieldValues>(
        from type: Foreign.Type,
        localField: KeyPath<Base, QueryableField<FieldValue>>,
        foreignField: KeyPath<Foreign, QueryableField<FieldValue>>,
        as asField: KeyPath<Base, QueryableField<FieldValues>>
    ) where Base: KeyPathQueryableModel, FieldValues: Sequence, FieldValues.Element == FieldValue {
        let localField = FieldPath(components: Base.resolveFieldPath(localField))
        let foreignField = FieldPath(components: Foreign.resolveFieldPath(foreignField))
        let asField = FieldPath(components: Base.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localField,
            foreignField: foreignField,
            as: asField
        )
    }
    
    public init<FieldValues>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>>>,
        as asField: KeyPath<Base, QueryableField<FieldValues?>>
    ) where Base: KeyPathQueryableModel, FieldValues: Sequence, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Base.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>>>,
        as asField: KeyPath<Base, QueryableField<FieldValues>>
    ) throws where Base: KeyPathQueryableModel, FieldValues: Sequence, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Base.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<[Reference<Foreign>]>>,
        as asField: KeyPath<Base, QueryableField<FieldValues>>
    ) throws where Base: KeyPathQueryableModel, FieldValues: Sequence, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Base.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<[Reference<Foreign>]>>,
        as asField: KeyPath<Base, QueryableField<FieldValues?>>
    ) throws where Base: KeyPathQueryableModel, FieldValues: Sequence, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Base.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>?>>,
        as asField: KeyPath<Base, QueryableField<FieldValues?>>
    ) throws where Base: KeyPathQueryableModel, FieldValues: Sequence, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Base.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>?>>,
        as asField: KeyPath<Base, QueryableField<FieldValues>>
    ) throws where Base: KeyPathQueryableModel, FieldValues: Sequence, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Base.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValue, FieldValues>(
        from type: Foreign.Type,
        localField: KeyPath<Base, QueryableField<FieldValue>>,
        foreignField: KeyPath<Foreign, QueryableField<FieldValue>>,
        as asField: KeyPath<Base, QueryableField<FieldValues?>>
    ) throws where Base: KeyPathQueryableModel, FieldValues: Sequence, FieldValues.Element == FieldValue {
        let localField = FieldPath(components: Base.resolveFieldPath(localField))
        let foreignField = FieldPath(components: Foreign.resolveFieldPath(foreignField))
        let asField = FieldPath(components: Base.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localField,
            foreignField: foreignField,
            as: asField
        )
    }
}
#endif
