//
//  Fakes.swift
//  SignalRClientTests
//
//  Created by Pawel Kadluczka on 11/23/19.
//
import Foundation
import SignalRClient

class TestConnectionDelegate: ConnectionDelegate {
    var connectionDidOpenHandler: ((_ connection: Connection) -> Void)?
    var connectionDidFailToOpenHandler: ((_ error: Error) -> Void)?
    var connectionDidCloseHandler: ((_ error: Error?) -> Void)?
    var connectionDidReceiveDataHandler: ((_ connection: Connection, _ data: Data) -> Void)?
    var connectionWillReconnectHandler: ((_ error: Error?)->Void)?
    var connectionDidReconnectHandler: (()->Void)?

    func connectionDidOpen(connection: Connection) {
        connectionDidOpenHandler?(connection)
    }

    func connectionDidFailToOpen(error: Error) {
        connectionDidFailToOpenHandler?(error)
    }

    func connectionDidReceiveData(connection: Connection, data: Data) {
        connectionDidReceiveDataHandler?(connection, data)
    }

    func connectionDidClose(error: Error?) {
        connectionDidCloseHandler?(error)
    }

    func connectionWillReconnect(error: Error) {
        connectionWillReconnectHandler?(error)
    }

    func connectionDidReconnect() {
        connectionDidReconnectHandler?()
    }

    func connectionDidFail(_ session: URLSession?, task: URLSessionTask?, at: TransportDidFailPoint, didCompleteWithError error: (any Error)?) {
    }
}

class TestHttpClient: HttpClientProtocol {
    
    typealias RequestHandler = (URL) -> (HttpResponse?, Error?)
    
    private var getHandler: RequestHandler?
    private var postHandler: RequestHandler?
    private var deleteHandler: RequestHandler?

    init(getHandler: RequestHandler? = nil, postHandler: RequestHandler? = nil, deleteHandler: RequestHandler? = nil) {
        self.getHandler = getHandler
        self.postHandler = postHandler
        self.deleteHandler = deleteHandler
    }

    func get(url: URL, completionHandler: @escaping (HttpResponse?, Error?) -> Void) {
        handleHttpRequest(url: url, body: nil, handler: getHandler, completionHandler: completionHandler)
    }

    func post(url: URL, body: Data?, completionHandler: @escaping (HttpResponse?, Error?) -> Void) {
        handleHttpRequest(url: url, body: body, handler: postHandler, completionHandler: completionHandler)
    }
    
    func delete(url: URL, completionHandler: @escaping (HttpResponse?, Error?) -> Void) {
        handleHttpRequest(url: url, body: nil, handler: deleteHandler, completionHandler: completionHandler)
    }

    private func handleHttpRequest(url: URL, body: Data?, handler: RequestHandler?, completionHandler: @escaping (HttpResponse?, Error?) -> Void) {
        let (response, error) = (handler?(url)) ?? (nil, nil)
        completionHandler(response, error)
    }
}

/**
 A `Connection` that, like `HttpConnection`, never calls its delegate synchronously from `start`, `send` or `stop`: every
 delegate call is made on `callbackQueue`. It answers the handshake request with a successful handshake response and
 records the messages sent through it. Unlike connections that call their delegate synchronously it can be wrapped in a
 `ReconnectableConnection`.
 */
class AsyncTestConnection: Connection {
    weak var delegate: ConnectionDelegate?
    var inherentKeepAlive = false
    var connectionId: String?

    /// Invoked synchronously, on the sending thread, for every message sent through the connection.
    var sendHandler: ((_ connection: AsyncTestConnection, _ message: String) -> Void)?

    private let callbackQueue: DispatchQueue
    private let lock = NSLock()
    private var started = false
    private var closed = false
    private var messages: [String] = []
    private var closeError: Error?

    init(callbackQueue: DispatchQueue) {
        self.callbackQueue = callbackQueue
    }

    var isStarted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return started
    }

    /// The error passed to `stop(stopError:)`, if the connection was stopped with an error.
    var stopError: Error? {
        lock.lock()
        defer { lock.unlock() }
        return closeError
    }

    var sentMessages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return messages
    }

    func start() {
        lock.lock()
        started = true
        lock.unlock()
        callbackQueue.async { [self] in
            connectionId = UUID().uuidString
            delegate?.connectionDidOpen(connection: self)
        }
    }

    func send(data: Data, sendDidComplete: @escaping (Error?) -> Void) {
        let message = String(data: data, encoding: .utf8) ?? ""
        lock.lock()
        messages.append(message)
        lock.unlock()
        sendHandler?(self, message)
        callbackQueue.async { [self] in
            sendDidComplete(nil)
            if message.contains("\"protocol\"") {
                delegate?.connectionDidReceiveData(connection: self, data: "{}\u{1e}".data(using: .utf8)!)
            }
        }
    }

    func stop(stopError: Error?) {
        callbackQueue.async { [self] in
            guard markClosed(error: stopError) else { return }
            delegate?.connectionDidClose(error: stopError)
        }
    }

    /// Delivers `payload` to the delegate as if it had been received from the server.
    func receive(payload: String) {
        callbackQueue.async { [self] in
            delegate?.connectionDidReceiveData(connection: self, data: payload.data(using: .utf8)!)
        }
    }

    /// Reports the connection as closed without `stop` having been called, as happens when the transport fails.
    func simulateConnectionLoss(error: Error) {
        callbackQueue.async { [self] in
            guard markClosed(error: nil) else { return }
            delegate?.connectionDidClose(error: error)
        }
    }

    private func markClosed(error: Error?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return false }
        closed = true
        closeError = error
        connectionId = nil
        return true
    }
}

/**
 Creates `AsyncTestConnection`s (for example for a `ReconnectableConnection`) and keeps track of them. All connections share
 `callbackQueue`, like the connections a `HubConnectionBuilder` creates share the configured callback queue.
 */
class AsyncTestConnectionFactory {
    let callbackQueue = DispatchQueue(label: "SignalR.test.asyncConnection.callbackQueue")

    /// Invoked for every message sent through any of the connections created by this factory. Set it before the connections are used.
    var sendHandler: ((_ connection: AsyncTestConnection, _ message: String) -> Void)?

    private let lock = NSLock()
    private var connections: [AsyncTestConnection] = []

    func createConnection() -> Connection? {
        let connection = AsyncTestConnection(callbackQueue: callbackQueue)
        connection.sendHandler = { [weak self] connection, message in
            self?.sendHandler?(connection, message)
        }
        lock.lock()
        connections.append(connection)
        lock.unlock()
        return connection
    }

    /// The connections that have been started, in the order they were created.
    var startedConnections: [AsyncTestConnection] {
        lock.lock()
        defer { lock.unlock() }
        return connections.filter { $0.isStarted }
    }
}
