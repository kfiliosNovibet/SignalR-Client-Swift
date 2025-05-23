//
//  ReadWriteLock.swift
//  Novibet
//
//  Created by Kostas Filios on 16/5/23.
//  Copyright © 2023 Novibet. All rights reserved.
//

import Foundation

@propertyWrapper
final class ReadWriteLock<Value> {
    private var value: Value
    private var _lock = pthread_rwlock_t()

    init(wrappedValue value: Value) {
        self.value = value
        pthread_rwlock_init(&_lock, nil)
    }

    deinit {
        pthread_rwlock_destroy(&_lock)
    }

    var wrappedValue: Value {
        get { load() }
        set { store(newValue: newValue) }
    }

    func load() -> Value {
        pthread_rwlock_rdlock(&_lock)
        defer { pthread_rwlock_unlock(&_lock) }
        return value
    }

    func store(newValue: Value) {
        pthread_rwlock_wrlock(&_lock)
        defer { pthread_rwlock_unlock(&_lock) }
        value = newValue
    }
}
