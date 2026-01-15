//
//  CancellationToken.swift
//  SignalRClient
//
//  Created by Kostas Filios on 15/1/26.
//  Copyright © 2026 Pawel Kadluczka. All rights reserved.
//

import Foundation


    /// Cancellation token to prevent objc_loadWeakRetained crash.
    /// This token is captured strongly in callbacks, allowing us to check cancellation
    /// BEFORE accessing [weak self], which prevents the crash when self is deallocating.
    class CancellationToken {
        @FairLock var isCancelled = false
        let token: UUID = UUID()
    }
