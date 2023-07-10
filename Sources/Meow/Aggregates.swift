import MongoCore
import MongoKitten

public protocol MeowAggregateStage: AggregateBuilderStage {
    associatedtype Base: Codable
    associatedtype Result: Codable
}

#if swift(>=5.7)
@resultBuilder public struct MeowCheckedAggregateBuilder<M: KeyPathQueryableModel> {
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
#endif

@resultBuilder public struct MeowUncheckedAggregateBuilder<M: ReadableModel> {
    public static func buildBlock(_ components: AggregateBuilderStage...) -> MeowAggregate<M, Document> {
        MeowAggregate(stages: components)
    }
}

#if swift(>=5.7)
extension MeowCollection where M: KeyPathQueryableModel {
    public func buildCheckedAggregate<Result: Codable>(
        @MeowCheckedAggregateBuilder<M> build: () throws -> MeowAggregate<M, Result>
    ) rethrows -> MappedCursor<AggregateBuilderPipeline, Result> {
        return try AggregateBuilderPipeline(
            stages: build().stages,
            collection: raw
        ).decode(Result.self)
    }
}
#endif

extension MeowCollection where M: ReadableModel {
    public func buildAggregate<Result: Codable>(
        @MeowUncheckedAggregateBuilder<M> build: () throws -> MeowAggregate<M, Result>
    ) rethrows -> MappedCursor<AggregateBuilderPipeline, Result> {
        return try AggregateBuilderPipeline(
            stages: build().stages,
            collection: raw
        ).decode(Result.self)
    }
}

public struct MeowAggregate<Model: ReadableModel, Result: Codable> {
    var stages: [AggregateBuilderStage]
}

public protocol ModelProjection: KeyPathQueryableModel {
    associatedtype Base: KeyPathQueryableModel
}

public struct Sort<Base: Codable>: AggregateBuilderStage {
    public typealias Result = Base
    
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init<T: Comparable & Codable>(
        _ type: Base.Type = Base.self,
        by field: KeyPath<Base, QueryableField<T>>,
        direction: Sorting.Order
    ) where Base: KeyPathQueryable {
        let field = Base.resolveFieldPath(field).joined(separator: ".")
        
        self.stage = [
            "$sort": [
                field: direction.rawValue
            ] as Document
        ]
    }
    
    public init(_ sorting: Sorting) where Base == Document {
        self.stage = [
            "$sort": sorting.document
        ]
    }
}

extension Sort: MeowAggregateStage where Base: KeyPathQueryable {}

public struct Project<Base: Codable, Result: Codable>: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(
        _ type: Base.Type = Base.self,
        as newType: Result.Type = Result.self,
        buildMapping: (inout ModelProjector<Base, Result>) throws -> ()
    ) rethrows {
        var projector = ModelProjector<Base, Result>()
        try buildMapping(&projector)
        
        self.stage = [
            "$project": projector.projection.document
        ]
    }
    
    public init(_ projection: Projection) where Base == Document, Result == Document {
        self.stage = [
            "$project": projection.document
        ]
    }
}

extension Project: MeowAggregateStage where Base: KeyPathQueryable, Result: KeyPathQueryable {}

public struct Group<Base: Codable, Result: Codable>: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(
        _ type: Base.Type = Base.self,
        as newType: Result.Type = Result.self,
        by value: Primitive,
        buildGroup: (inout ModelGrouper<Base, Result>) throws -> ()
    ) rethrows where Base: KeyPathQueryable, Result: KeyPathQueryable {
        var grouper = ModelGrouper<Base, Result>(_id: value)
        try buildGroup(&grouper)
        
        self.stage = [
            "$group": grouper.document
        ]
    }
}

extension Group: MeowAggregateStage where Base: KeyPathQueryable, Result: KeyPathQueryable {}

public struct Match<Base: Codable>: AggregateBuilderStage {
    public typealias Result = Base
    
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(
        _ type: Base.Type = Base.self,
        matching: (QueryMatcher<Base>) throws -> Document
    ) rethrows where Base: KeyPathQueryable {
        let matcher = QueryMatcher<Base>()
        let filter = try matching(matcher)
        self.stage = [
            "$match": filter
        ]
    }
    
    public init<MKQ: MongoKittenQuery>(
        _ type: Base.Type = Base.self,
        matching: (QueryMatcher<Base>) throws -> MKQ
    ) rethrows where Base: KeyPathQueryable {
        let matcher = QueryMatcher<Base>()
        let filter = try matching(matcher)
        self.stage = [
            "$match": filter.makeDocument()
        ]
    }
    
    public init<MKQ: MongoKittenQuery>(
        _ query: MKQ
    ) where Base == Document {
        self.stage = [
            "$match": query.makeDocument()
        ]
    }
    
    public init(
        _ query: Document
    ) where Base == Document {
        self.stage = [
            "$match": query
        ]
    }
}

extension Match: MeowAggregateStage where Base: KeyPathQueryable {}

public struct Limit<Base: Codable>: AggregateBuilderStage {
    public typealias Result = Base
    
    public var stage: BSON.Document { limit.stage }
    public var minimalVersionRequired: MongoCore.WireVersion? { limit.minimalVersionRequired }
    
    let limit: MongoKitten.Limit
    
    public init(_ n: Int) {
        self.limit = .init(n)
    }
}

extension Limit: MeowAggregateStage where Base: KeyPathQueryable {}

public struct Unwind<Base: Codable, Result: Codable>: MeowAggregateStage {
    let unwind: MongoKitten.Unwind
    public var stage: Document { unwind.stage }
    public var minimalVersionRequired: MongoCore.WireVersion? { unwind.minimalVersionRequired }
    
}

extension Unwind where Base == Document, Result == Document {
    public init(fieldPath: FieldPath, includeArrayIndex: String? = nil, preserveNullAndEmptyArrays: Bool? = nil) {
        self.unwind = .init(fieldPath: fieldPath, includeArrayIndex: includeArrayIndex, preserveNullAndEmptyArrays: preserveNullAndEmptyArrays)
    }
}

extension Unwind where Base: KeyPathQueryable, Result: KeyPathQueryable {
    public init<Value: Codable, Values: Sequence & Codable>(
        from base: KeyPath<Base, QueryableField<Values>>,
        into result: KeyPath<Result, QueryableField<Value>>
    ) where Values.Element == Value {
        let base = Base.resolveFieldPath(base)
        let result = Result.resolveFieldPath(result)
        
        assert(base == result, "Base and Result must be in the same path location for MongoDB")
        
        self.unwind = .init(fieldPath: FieldPath(components: base))
    }
}

public struct Lookup<Base: Codable, Foreign: Codable, Result: Codable>: MeowAggregateStage {
    private let lookup: MongoKitten.Lookup
    public var stage: Document { lookup.stage }
    public var minimalVersionRequired: MongoCore.WireVersion? { lookup.minimalVersionRequired }
}

extension Lookup where Base: KeyPathQueryable, Foreign: KeyPathQueryableModel, Result: KeyPathQueryable {
    public init<FieldValue: Codable, FieldValues: Codable>(
        from type: Foreign.Type,
        localField: KeyPath<Base, QueryableField<FieldValue>>,
        foreignField: KeyPath<Foreign, QueryableField<FieldValue>>,
        as asField: KeyPath<Result, QueryableField<FieldValues>>
    ) where FieldValues: Sequence, FieldValues.Element == Foreign {
        let localField = FieldPath(components: Base.resolveFieldPath(localField))
        let foreignField = FieldPath(components: Foreign.resolveFieldPath(foreignField))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localField,
            foreignField: foreignField,
            as: asField
        )
    }

    public init<FieldValue: Codable, FieldValues: Codable>(
        from type: Foreign.Type,
        localField: KeyPath<Base, QueryableField<FieldValue>>,
        foreignField: KeyPath<Foreign, QueryableField<FieldValue>>,
        as asField: KeyPath<Result, QueryableField<FieldValues?>>
    ) where Base: KeyPathQueryable, Foreign: KeyPathQueryableModel, Result: KeyPathQueryable, FieldValues: Sequence, FieldValues.Element == Foreign {
        let localField = FieldPath(components: Base.resolveFieldPath(localField))
        let foreignField = FieldPath(components: Foreign.resolveFieldPath(foreignField))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))

        self.lookup = .init(
            from: type.collectionName,
            localField: localField,
            foreignField: foreignField,
            as: asField
        )
    }

    public init<FieldValues: Codable>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>>>,
        as asField: KeyPath<Result, QueryableField<FieldValues?>>
    ) where FieldValues: Sequence, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))

        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }

    public init<Match: Codable, Field: Codable>(
        from type: Foreign.Type,
        localField: KeyPath<Base, QueryableField<Match>>,
        foreignField: KeyPath<Foreign, QueryableField<Match>>,
        @AggregateBuilder uncheckedPipeline: () throws -> [AggregateBuilderStage],
        as asField: KeyPath<Result, QueryableField<Field>>
    ) rethrows where Base: KeyPathQueryable, Foreign: KeyPathQueryableModel, Result: KeyPathQueryable {
        let localField = FieldPath(components: Base.resolveFieldPath(localField))
        let foreignField = FieldPath(components: Foreign.resolveFieldPath(foreignField))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        let pipeline = try uncheckedPipeline()

        self.lookup = .init(
            from: type.collectionName,
            localField: localField,
            foreignField: foreignField,
            pipeline: {
                return pipeline
            },
            as: asField
        )
    }

    public init<M, Field: Codable, Fields: Sequence & Codable>(
        from type: Foreign.Type,
        localField: KeyPath<Base, QueryableField<M.Identifier>>,
        foreignField: KeyPath<Foreign, QueryableField<Reference<M>>>,
        @AggregateBuilder uncheckedPipeline: () throws -> [AggregateBuilderStage],
        as asField: KeyPath<Result, QueryableField<Fields>>
    ) rethrows where Base: KeyPathQueryable, Foreign: KeyPathQueryableModel, Result: KeyPathQueryable, Fields.Element == Field {
        let localField = FieldPath(components: Base.resolveFieldPath(localField))
        let foreignField = FieldPath(components: Foreign.resolveFieldPath(foreignField))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        let pipeline = try uncheckedPipeline()

        self.lookup = .init(
            from: type.collectionName,
            localField: localField,
            foreignField: foreignField,
            pipeline: {
                return pipeline
            },
            as: asField
        )
    }
}

extension Lookup {
    public init<
        LocalIdentifier: FieldPathRepresentable,
        AsField: FieldPathRepresentable
    >(
        from type: Foreign.Type,
        localIdentifier: LocalIdentifier,
        as asField: AsField
    ) where Foreign: ReadableModel {
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier.makeFieldPath(),
            foreignField: "_id",
            as: asField.makeFieldPath()
        )
    }

    public init<
        LocalIdentifier: FieldPathRepresentable,
        AsField: FieldPathRepresentable
    >(
        from collection: String,
        localIdentifier: LocalIdentifier,
        as asField: AsField
    ) where Foreign: ReadableModel {
        self.lookup = .init(
            from: collection,
            localField: localIdentifier.makeFieldPath(),
            foreignField: "_id",
            as: asField.makeFieldPath()
        )
    }
}

extension Lookup where Base: KeyPathQueryable, Foreign: KeyPathQueryableModel {
    public init(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>>>,
        as asField: FieldPath
    ) where Base: KeyPathQueryable, Foreign: KeyPathQueryableModel {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues: Codable & Sequence>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>>>,
        as asField: KeyPath<Result, QueryableField<FieldValues>>
    ) where Base: KeyPathQueryable, Result: KeyPathQueryableModel, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues: Codable & Sequence>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<[Reference<Foreign>]>>,
        as asField: KeyPath<Result, QueryableField<FieldValues>>
    ) where Base: KeyPathQueryable, Result: KeyPathQueryableModel, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues: Codable & Sequence>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<[Reference<Foreign>]>>,
        as asField: KeyPath<Result, QueryableField<FieldValues?>>
    ) where Base: KeyPathQueryable, Result: KeyPathQueryableModel, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues: Codable & Sequence>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>?>>,
        as asField: KeyPath<Result, QueryableField<FieldValues?>>
    ) where Base: KeyPathQueryable, Result: KeyPathQueryableModel, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
    
    public init<FieldValues: Codable & Sequence>(
        from type: Foreign.Type,
        localIdentifier: KeyPath<Base, QueryableField<Reference<Foreign>?>>,
        as asField: KeyPath<Result, QueryableField<FieldValues>>
    ) where Base: KeyPathQueryable, Result: KeyPathQueryableModel, FieldValues.Element == Foreign {
        let localIdentifier = FieldPath(components: Base.resolveFieldPath(localIdentifier))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier,
            foreignField: "_id",
            as: asField
        )
    }
}

#if swift(>=5.7)
extension Lookup {
    public init<
        LocalIdentifier: FieldPathRepresentable,
        AsField: FieldPathRepresentable,
        Field: Codable
    >(
        from type: Foreign.Type,
        localIdentifier: LocalIdentifier,
        @MeowUncheckedAggregateBuilder<Foreign> uncheckedPipeline: () throws -> MeowAggregate<Foreign, Field>,
        as asField: AsField
    ) rethrows where Foreign: KeyPathQueryableModel {
        let pipeline = try uncheckedPipeline()

        self.lookup = .init(
            from: type.collectionName,
            localField: localIdentifier.makeFieldPath(),
            foreignField: "_id",
            pipeline: {
                return pipeline.stages
            },
            as: asField.makeFieldPath()
        )
    }

    public init<Match: Codable, Field: Codable>(
        from type: Foreign.Type,
        localField: KeyPath<Base, QueryableField<Match>>,
        foreignField: KeyPath<Foreign, QueryableField<Match>>,
        @MeowCheckedAggregateBuilder<Foreign> pipeline: () throws -> MeowAggregate<Foreign, Field>,
        as asField: KeyPath<Result, QueryableField<Field>>
    ) rethrows where Base: KeyPathQueryable, Foreign: KeyPathQueryableModel, Result: KeyPathQueryable {
        let localField = FieldPath(components: Base.resolveFieldPath(localField))
        let foreignField = FieldPath(components: Foreign.resolveFieldPath(foreignField))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        let pipeline = try pipeline()
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localField,
            foreignField: foreignField,
            pipeline: {
                return pipeline.stages
            },
            as: asField
        )
    }
    
    public init<M: Codable, Field: Codable, Fields: Sequence & Codable>(
        from type: Foreign.Type,
        localField: KeyPath<Base, QueryableField<M.Identifier>>,
        foreignField: KeyPath<Foreign, QueryableField<Reference<M>>>,
        @MeowCheckedAggregateBuilder<Foreign> pipeline: () throws -> MeowAggregate<Foreign, Field>,
        as asField: KeyPath<Result, QueryableField<Fields>>
    ) rethrows where Base: KeyPathQueryable, Foreign: KeyPathQueryableModel, Result: KeyPathQueryable, Fields.Element == Field {
        let localField = FieldPath(components: Base.resolveFieldPath(localField))
        let foreignField = FieldPath(components: Foreign.resolveFieldPath(foreignField))
        let asField = FieldPath(components: Result.resolveFieldPath(asField))
        let pipeline = try pipeline()
        
        self.lookup = .init(
            from: type.collectionName,
            localField: localField,
            foreignField: foreignField,
            pipeline: {
                return pipeline.stages
            },
            as: asField
        )
    }
}
#endif
