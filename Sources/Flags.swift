//
//  Flags.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 17/03/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

/// The flags that are used by the Reply message
internal struct ReplyFlags : OptionSetType {
    /// The raw value in Int32
    internal let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of ReplyFlags
    internal init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// The server could not find the cursor we tried to use
    internal static let CursorNotFound = ReplyFlags(rawValue: 0 << 0)
    
    /// The query we entered failed
    internal static let QueryFailure = ReplyFlags(rawValue: 1 << 0)
    
    /// The server is await-capable and thus supports the QueryFlag's AwaitData flag
    internal static let AwaitCapable = ReplyFlags(rawValue: 3 << 0)
}

/// The flags that can be used in a Find/Query message
public struct QueryFlags : OptionSetType {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of QueryFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
}