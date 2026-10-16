//
//  HubConnectionOptions.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 10/4/21.
//

import Foundation

/**
 HubConnection configuration options.
 */
public class HubConnectionOptions {
    /**
     Keep-alive interval in seconds. If nil keep-alive is disabled
     */
    public var keepAliveInterval: Double? = 15

    /**
     Server timeout in seconds. If nil (the default), zero or negative, server timeout detection is disabled.

     When set, the client considers the connection lost if it receives nothing from the server for this long. Every
     message counts, including the pings the server sends to keep the connection alive, so a server that sends pings
     keeps the connection alive even when no hub messages are flowing. When the timeout elapses the transport is failed
     with `SignalRError.serverTimeout`: a connection built with automatic reconnect then reconnects according to its
     reconnect policy, otherwise it is closed. This detects connections that stopped delivering data without being
     closed (for example a half-open TCP connection), which can otherwise go unnoticed for minutes.

     The timer is started after every successful handshake, including the one that completes a reconnect, and is
     stopped when the connection is lost, closed or stopped.

     - note: Use a value of at least double the server's keep-alive interval, so that a single late ping does not cause
             a timeout. ASP.NET Core SignalR servers send a ping every 15 seconds by default; the official SignalR clients
             use a server timeout of 30 seconds.
     - note: The timeout is not used with transports that have an inherent keep-alive (long polling).
     - note: Timers do not fire while the host app is suspended, so the timeout cannot detect a dead connection during
             that time. When the app resumes, the timer can fire right away, before messages the server sent in the
             meantime have been processed, or only after up to the full interval. An app that needs predictable
             behaviour when it returns to the foreground may need to re-arm the timeout at that point, for example by
             restarting the connection.
     */
    public var serverTimeout: Double? = nil

    /**
    The queue to run callbacks on
     */
    public var callbackQueue: DispatchQueue = DispatchQueue.main
    
    /**
     Initializes `HubConnectionOptions`
     */
    public init() {
    }
}
