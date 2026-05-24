//
//  UUAsyncCoalescer.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import Foundation

public actor UUAsyncCoalescer<Key: Hashable & Sendable, Value: Sendable>
{
    private var inFlight: [Key: Task<Value, Error>] = [:]
    
    public func run(
        key: Key,
        operation: @Sendable @escaping () async throws -> Value
    ) async throws -> Value
    {
        if let existing = inFlight[key]
        {
            return try await existing.value
        }
        let task = Task
        {
            try await operation()
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }
}
