//
//  TransportDidFailPoint.swift
//  SignalRClient
//
//  Created by Kostas Filios on 5/5/25.
//  Copyright © 2025 Pawel Kadluczka. All rights reserved.
//


public enum TransportDidFailPoint: String {
    case wssReceiveData = "WSS did receive data"
    case wssURLSessionInit = "WSS did fail to init connection at the beging"
}