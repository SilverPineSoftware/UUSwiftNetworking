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
    private let inFlightMirrorLock = NSLock()
    nonisolated(unsafe) private var inFlightMirror: Set<Key> = []

    public func isInFlight(key: Key) -> Bool
    {
        isInFlightSync(key: key)
    }

    public var inFlightCount: Int
    {
        syncInFlightCount
    }

    nonisolated public func isInFlightSync(key: Key) -> Bool
    {
        inFlightMirrorLock.lock()
        defer { inFlightMirrorLock.unlock() }
        return inFlightMirror.contains(key)
    }

    nonisolated public var syncInFlightCount: Int
    {
        inFlightMirrorLock.lock()
        defer { inFlightMirrorLock.unlock() }
        return inFlightMirror.count
    }
    
    /// Cancels the in-flight task for `key`, if any. Waiters receive `CancellationError`.
    public func cancel(key: Key)
    {
        if let task = inFlight[key]
        {
            task.cancel()
            inFlight[key] = nil
            trackInFlight(key, active: false)
        }
    }

    public func run(
        key: Key,
        operation: @Sendable @escaping () async throws -> Value
    ) async throws -> Value
    {
        if let existing = inFlight[key]
        {
            return try await existing.value
        }

        trackInFlight(key, active: true)
        defer { trackInFlight(key, active: false) }

        let task = Task
        {
            try await operation()
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }

    private func trackInFlight(_ key: Key, active: Bool)
    {
        inFlightMirrorLock.lock()
        defer { inFlightMirrorLock.unlock() }
        if active
        {
            inFlightMirror.insert(key)
        }
        else
        {
            inFlightMirror.remove(key)
        }
    }
}
