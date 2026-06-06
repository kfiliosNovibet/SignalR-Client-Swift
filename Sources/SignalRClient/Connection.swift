//
//  Connection.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 3/4/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Foundation

public protocol Connection {
    var delegate: ConnectionDelegate? {get set}
    var inherentKeepAlive: Bool {get}
    var connectionId: String? {get}
    func start() -> Void
    func send(data: Data, sendDidComplete: @escaping (_ error: Error?) -> Void) -> Void
    func stop(stopError: Error?) -> Void
    /// Tear down the underlying transport immediately, bypassing any pending
    /// handshake bookkeeping. Use when the caller needs the connection killed
    /// *now* (e.g. to supersede an in-flight attempt). The default
    /// implementation falls back to `stop(stopError:)` so external implementers
    /// remain source-compatible.
    func forceStop() -> Void
}

extension Connection {
    public func forceStop() {
        stop(stopError: nil)
    }
}
