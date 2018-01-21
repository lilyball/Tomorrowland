//
//  Utilities.swift
//  Tomorrowland
//
//  Created by Ballard, Kevin on 12/21/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Dispatch
import Foundation

extension Promise {
    /// Returns a new `Promise` that adopts the receiver's result after a delay.
    ///
    /// - Parameter context: The context to resolve the new `Promise` on. This is generally only
    ///   important when using callbacks registered with `.immediate`. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    ///   If provided as `.immediate`, behaves the same as `.auto`. If provided as `.operationQueue`
    ///   it uses the `OperationQueue`'s underlying queue, or `.default` if there is no underlying
    ///   queue.
    /// - Parameter delay: The number of seconds to delay the resulting promise by.
    /// - Returns: A `Promise` that adopts the same result as the receiver after a delay.
    public func delay(on context: PromiseContext = .auto, _ delay: TimeInterval) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _seal.enqueue { [queue=context.getQueue()] (result) in
            queue.asyncAfter(deadline: .now() + delay) {
                resolver.resolve(with: result)
            }
        }
        resolver.onRequestCancel(on: .immediate) { [weak _box] (_) in
            _box?.propagateCancel()
        }
        return promise
    }
    
    /// Returns a `Promise` that is rejected with an error if the receiver does not resolve within
    /// the given interval.
    ///
    /// The returned `Promise` will adopt the receiver's value if it resolves within the given
    /// interval. Otherwise it will be rejected with the error `PromiseTimeoutError.timedOut`. If
    /// the receiver is rejected, the returned promise will be rejected with
    /// `PromiseTimeoutError.rejected(error)`.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    ///
    ///   If the promise times out, the returned promise will be rejected using the same context. In
    ///   this event, `.immediate` is treated the same as `.auto`. If provided as `.operationQueue`
    ///   it uses the `OperationQueue`'s underlying queue, or `.default` if there is no underlying
    ///   queue.
    /// - Parameter delay: The delay before the returned promise times out. If less than or equal to
    ///   zero, the returned `Promise` will be timed out at once unless the receiver is already
    ///   resolved.
    /// - Parameter cancelOnTimeout: The default value of `true` means the receiver will be
    ///   cancelled if the returned promise times out.
    /// - Returns: A new `Promise`.
    public func timeout(on context: PromiseContext = .auto, delay: TimeInterval, cancelOnTimeout: Bool = true) -> Promise<Value,PromiseTimeoutError<Error>> {
        let (promise, resolver) = Promise<Value,PromiseTimeoutError<Error>>.makeWithResolver()
        let timeoutBlock = DispatchWorkItem { [weak _box, weak newBox=promise._box] in
            if let box = newBox {
                let resolver = Promise<Value,PromiseTimeoutError<Error>>.Resolver(box: box)
                // double-check the result just in case
                if let result = _box?.result {
                    resolver.resolve(with: result.mapError({ .rejected($0) }))
                } else {
                    resolver.reject(with: .timedOut)
                }
            }
            if cancelOnTimeout {
                _box?.requestCancel()
            }
        }
        _seal.enqueue { (result) in
            timeoutBlock.cancel() // make sure we can't timeout merely because it raced our context switch
            context.execute {
                resolver.resolve(with: result.mapError({ .rejected($0) }))
            }
        }
        resolver.onRequestCancel(on: .immediate) { [weak _box] (resolver) in
            _box?.propagateCancel()
        }
        context.getQueue().asyncAfter(deadline: .now() + delay, execute: timeoutBlock)
        return promise
    }
}

extension Promise where Error == Swift.Error {
    /// Returns a `Promise` that is rejected with an error if the receiver does not resolve within
    /// the given interval.
    ///
    /// The returned `Promise` will adopt the receiver's value if it resolves within the given
    /// interval. Otherwise it will be rejected with the error
    /// `PromiseTimeoutError<Error>.timedOut`. If the receiver is rejected, the returned promise
    /// will be rejected with the same error.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    ///
    ///   If the promise times out, the returned promise will be rejected using the same context. In
    ///   this event, `.immediate` is treated the same as `.auto`. If provided as `.operationQueue`
    ///   it uses the `OperationQueue`'s underlying queue, or `.default` if there is no underlying
    ///   queue.
    /// - Parameter delay: The delay before the returned promise times out. If less than or equal to
    ///   zero, the returned `Promise` will be timed out at once unless the receiver is already
    ///   resolved.
    /// - Parameter cancelOnTimeout: The default value of `true` means the receiver will be
    ///   cancelled if the returned promise times out.
    /// - Returns: A new `Promise`.
    public func timeout(on context: PromiseContext = .auto, delay: TimeInterval, cancelOnTimeout: Bool = true) -> Promise<Value,Swift.Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        let timeoutBlock = DispatchWorkItem { [weak _box, weak newBox=promise._box] in
            if let box = newBox {
                let resolver = Promise<Value,Error>.Resolver(box: box)
                // double-check the result just in case
                if let result = _box?.result {
                    resolver.resolve(with: result)
                } else {
                    resolver.reject(with: PromiseTimeoutError<Error>.timedOut)
                }
            }
            if cancelOnTimeout {
                _box?.requestCancel()
            }
        }
        _seal.enqueue { (result) in
            timeoutBlock.cancel() // make sure we can't timeout merely because it raced our context switch
            context.execute {
                resolver.resolve(with: result)
            }
        }
        resolver.onRequestCancel(on: .immediate) { [weak _box] (resolver) in
            _box?.propagateCancel()
        }
        context.getQueue().asyncAfter(deadline: .now() + delay, execute: timeoutBlock)
        return promise
    }
}

/// The error type returned from `Promise.timeout`.
///
/// - SeeAlso: `Promise.timeout`.
public enum PromiseTimeoutError<Error>: Swift.Error, CustomNSError {
    /// The promise did not resolve within the given interval.
    case timedOut
    /// The promise was rejected with an error.
    case rejected(Error)
    
    public var errorUserInfo: [String: Any] {
        switch self {
        case .timedOut:
            return [
                NSLocalizedFailureReasonErrorKey: "The operation timed out."
            ]
        case .rejected(let error):
            switch error {
            case let error as Swift.Error:
                return [
                    NSLocalizedDescriptionKey: error.localizedDescription,
                    NSUnderlyingErrorKey: error as NSError
                ]
            default:
                return [
                    // Don't set localized description because we don't know if the error has a usable description
                    NSLocalizedFailureReasonErrorKey: String(describing: error)
                ]
            }
        }
    }
}

extension PromiseTimeoutError where Error: Equatable {
    public static func ==(lhs: PromiseTimeoutError, rhs: PromiseTimeoutError) -> Bool {
        switch (lhs, rhs) {
        case (.timedOut, .timedOut): return true
        case let (.rejected(a), .rejected(b)): return a == b
        default: return false
        }
    }
    
    public static func !=(lhs: PromiseTimeoutError, rhs: PromiseTimeoutError) -> Bool {
        return !(lhs == rhs)
    }
}

#if swift(>=4.1)
    extension PromiseTimeoutError: Equatable where Error: Equatable {}

    extension PromiseTimeoutError: Hashable where Error: Hashable {
        public var hashValue: Int {
            switch self {
            case .timedOut: return 0
            case .rejected(let error): return error.hashValue << 1 | 1
            }
        }
    }
#endif
