//
//  WebsocketsTransport.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 2/23/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Foundation

@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public class WebsocketsTransport: NSObject, Transport, URLSessionWebSocketDelegate {
    private let logger: Logger
    private let dispatchQueue = DispatchQueue(label: "SignalR.webSocketTransport.queue")
    private let dispatchQueueWebSocket = DispatchQueue(label: "SignalR.websocket.queue")
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var authenticationChallengeHandler: ((_ session: URLSession, _ challenge: URLAuthenticationChallenge, _ completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?

    private var isTransportClosed = false

    public  weak var delegate: TransportDelegate?
    public let inherentKeepAlive = false

    init(logger: Logger) {
        self.logger = logger
    }

    public func start(url: URL, options: HttpConnectionOptions) {
        dispatchQueueWebSocket.async { [weak self] in
            guard let self else { return }
            logger.log(logLevel: .info, message: "Starting WebSocket transport")

            authenticationChallengeHandler = options.authenticationChallengeHandler

            var request = URLRequest(url: convertUrl(url: url))
            populateHeaders(headers: options.headers, request: &request)
            setAccessToken(accessTokenProvider: options.accessTokenProvider, request: &request)
            urlSession = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: OperationQueue())
            webSocketTask = urlSession!.webSocketTask(with: request)
            if let maximumWebsocketMessageSize = options.maximumWebsocketMessageSize {
                webSocketTask?.maximumMessageSize = maximumWebsocketMessageSize
            }

            webSocketTask!.resume()
        }
    }

    public func send(data: Data, sendDidComplete: @escaping (Error?) -> Void) {
        dispatchQueueWebSocket.async { [weak self] in
            guard let self else { return }
            let message = URLSessionWebSocketTask.Message.data(data)
            logger.log(logLevel: .info, message: "WSS sending data: \(message) sting: \(String(data: data, encoding: .utf8) ?? "<binary data>")")
            guard webSocketTask?.state == .running else {
                dispatchQueue.async { [weak self] in
                    guard let self else { return }
                    sendDidComplete(SignalRError.connectionIsBeingClosed)
                    isTransportClosed = true
                    delegate?.transportDidClose(SignalRError.connectionIsBeingClosed)
                }

                return
            }
            webSocketTask?.send(message, completionHandler: sendDidComplete)
        }
    }

    public func close() {
        dispatchQueueWebSocket.async { [weak self] in
            guard let self else { return }
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            urlSession?.finishTasksAndInvalidate()
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.log(logLevel: .info, message: "urlSession didOpenWithProtocol invoked. WebSocket open")
        delegate?.transportDidOpen()
        readMessage()
    }

    private func readMessage()  {
        dispatchQueueWebSocket.async { [weak self] in
            guard let self else { return }
            guard let webSocketTask = webSocketTask, webSocketTask.state == .running, !isTransportClosed else {
                logger.log(logLevel: .debug, message: "readMessage called but WebSocket is not running or transport is closed.")
                return
            }
            webSocketTask.receive { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    // This failure always occurs when the task is cancelled. If the code
                    // is not normalClosure this is a real error.
                    if self.webSocketTask?.closeCode != .normalClosure {
                        delegate?.transportDidFail(nil, task: nil, at: .wssReceiveData, didCompleteWithError: error)
                        handleError(error: error)
                    }
                case .success(let message):
                    handleMessage(message: message)
                    readMessage()
                }
            }
        }
    }

    private func handleMessage(message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            delegate?.transportDidReceiveData(text.data(using: .utf8)!)
        case .data(let data):
            delegate?.transportDidReceiveData(data)
        @unknown default:
            fatalError()
        }
    }

    private func handleError(error: Error) {
        logger.log(logLevel: .info, message: "WebSocket error. Error: \(error). Websocket status: \(webSocketTask?.state.rawValue ?? -1)")
        // This handler should not be called after the close event but we need to mark the transport as closed to prevent calling transportDidClose
        // on the delegate multiple times so we can as well add the check and log
        guard !markTransportClosed() else {
            logger.log(logLevel: .debug, message: "Transport already marked as closed - ignoring error. (handleError)")
            return
        }
        delegate?.transportDidClose(error)
        shutdownTransport()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        logger.log(logLevel: .debug, message: "urlSession didCompleteWithError invoked")
        delegate?.transportDidFail(session, task: task, at: .wssURLSessionInit, didCompleteWithError: error)
        guard error != nil else {
            logger.log(logLevel: .debug, message: "error is nil - ignoring error")
            // As per docs: "Error may be nil, which implies that no error occurred and this task is complete."
            return
        }

        guard !markTransportClosed() else {
            logger.log(logLevel: .debug, message: "Transport already marked as closed - ignoring error. (didCompleteWithError)")
            return
        }

        let statusCode = (webSocketTask?.response as? HTTPURLResponse)?.statusCode ?? -1
        logger.log(logLevel: .info, message: "Error starting webSocket. Error: \(error!), HttpStatusCode: \(statusCode), WebSocket closeCode: \(webSocketTask?.closeCode.rawValue ?? -1)")
        delegate?.transportDidClose(error)
        shutdownTransport()
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.log(logLevel: .debug, message: "urlSession didCloseWith invoked")
        var reasonString = ""
        if let reason = reason {
            reasonString = String(decoding: reason, as: UTF8.self)
        }
        logger.log(logLevel: .info, message: "WebSocket close. Code: \(closeCode.rawValue), reason: \(reasonString)")

        // the transport could have already been closed as a result of an error. In this case we should not call
        // transportDidClose again on the delegate.
        guard !markTransportClosed() else {
            logger.log(logLevel: .debug, message: "Transport already marked as closed due to an error - ignoring close. (didCloseWith)")
            return
        }

        if closeCode == .normalClosure {
            delegate?.transportDidClose(nil)
        } else {
            delegate?.transportDidClose(WebSocketsTransportError.webSocketClosed(statusCode: closeCode.rawValue, reason: reasonString))
        }
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if authenticationChallengeHandler != nil {
            logger.log(logLevel: .debug, message: "(ws) invoking custom auth challenge handler")
            authenticationChallengeHandler!(session, challenge, completionHandler)
        } else {
            logger.log(logLevel: .debug, message: "(ws) no auth challenge handler registered - falling back to default handling")
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private func markTransportClosed() -> Bool {
        logger.log(logLevel: .debug, message: "Marking transport as closed.")
        var previousCloseStatus = false
        dispatchQueue.sync { [weak self] in
            guard let self else { return }
            previousCloseStatus = isTransportClosed
            isTransportClosed = true
        }
        return previousCloseStatus
    }

    private func shutdownTransport() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        urlSession?.finishTasksAndInvalidate()
    }

    private func convertUrl(url: URL) -> URL {
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if (components.scheme == "http") {
                components.scheme = "ws"
            } else if (components.scheme == "https") {
                components.scheme = "wss"
            }
            return components.url!
        }

        return url
    }

    @inline(__always) private func populateHeaders(headers: [String : String], request: inout URLRequest) {
        headers.forEach { (key, value) in
            request.addValue(value, forHTTPHeaderField: key)
        }
    }

    @inline(__always) private func setAccessToken(accessTokenProvider: () -> String?, request: inout URLRequest) {
        if let accessToken = accessTokenProvider() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }
}

fileprivate enum WebSocketsTransportError: Error {
    case webSocketClosed(statusCode: Int, reason: String)
}
