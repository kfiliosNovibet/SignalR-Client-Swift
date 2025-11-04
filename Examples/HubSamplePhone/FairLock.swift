//
//  FairLock.swift
//  Novibet
//
//  Created by Kostas Filios on 27/8/25.
//  Copyright © 2025 Novibet. All rights reserved.
//

import Foundation

@propertyWrapper
final class FairLock<Value> {
    private var value: Value
    private var _lock = FCFSLock()

    init(wrappedValue value: Value) {
        self.value = value
    }

    var wrappedValue: Value {
        get { load() }
        set { store(newValue: newValue) }
    }

    func load() -> Value {
        _lock.withLock {
            value
        }
    }

    func store(newValue: Value) {
        _lock.withLock { [weak self] in
            guard let self else { return }
            value = newValue
        }
    }
}
