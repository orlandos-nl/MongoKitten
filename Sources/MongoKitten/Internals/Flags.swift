//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation

/// The flags that can be used in an Insert Message
internal struct InsertFlags : OptionSet {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of InsertFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// Continue inserting documents if one of them fails
    internal static let ContinueOnError = InsertFlags(rawValue: 1 << 0)
}

/// The flags that can be used in a Find/Query message
public struct QueryFlags : OptionSet {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of QueryFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    // Not supported
    //    internal static let TailableCursor = QueryFlags(rawValue: 1 << 0)
    //    internal static let NoCursorTimeout = QueryFlags(rawValue: 4 << 0)
    //    internal static let AwaitData = QueryFlags(rawValue: 5 << 0)
    //    internal static let Exhaust = QueryFlags(rawValue: 6 << 0)
}

/// The flags that can be used in an Update Message
internal struct UpdateFlags : OptionSet {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of InsertFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// If we can't find any resulting documents to update.. insert it
    public static let Upsert = UpdateFlags(rawValue: 1 << 0)
    
    /// Update more than one matching document
    public static let MultiUpdate = UpdateFlags(rawValue: 1 << 1)
}

/// The flags that can be used in a Delete Message
internal struct DeleteFlags : OptionSet {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of InsertFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// Remove only the first matching Document from the collection
    public static let RemoveOne = DeleteFlags(rawValue: 1 << 0)
}

/// The flags that are used by the Reply message
internal struct ReplyFlags : OptionSet {
    /// The raw value in Int32
    internal let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of ReplyFlags
    internal init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// The server could not find the cursor we tried to use
    internal static let CursorNotFound = InsertFlags(rawValue: 0 << 0)
    
    /// The query we entered failed
    internal static let QueryFailure = InsertFlags(rawValue: 1 << 0)
    
    /// The server is await-capable and thus supports the QueryFlag's AwaitData flag
    internal static let AwaitCapable = InsertFlags(rawValue: 3 << 0)
}
