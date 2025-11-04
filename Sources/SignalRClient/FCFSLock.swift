//
//  FCFSLock.swift
//  Novibet
//
//  Created by Kostas Filios on 27/8/25.
//  Copyright © 2025 Novibet. All rights reserved.
//

import Atomics
import Foundation

// FCFS = First-Come-First-Served
class FCFSLock {
    private let nextTicket = UnsafeAtomic<UInt64>.create(0)
    private let nowServing = UnsafeAtomic<UInt64>.create(0)

    deinit {
        nextTicket.destroy()
        nowServing.destroy()
    }

    func withLock<T>(_ block: () throws -> T) rethrows -> T {
        let myTicket = nextTicket.loadThenWrappingIncrement(ordering: .acquiringAndReleasing)

        while nowServing.load(ordering: .acquiring) != myTicket {
            sched_yield() // POSIX (Portable Operating System Interface) yield function
        }

        defer {
            nowServing.wrappingIncrement(ordering: .releasing)
        }

        return try block()
    }
}
