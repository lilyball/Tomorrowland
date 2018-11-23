//
//  Utilities.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 12/21/17.
//  Copyright © 2017 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Dispatch
import Foundation
import Tomorrowland.Private

extension Promise {
    /// Returns a new `Promise` that adopts the receiver's result after a delay.
    ///
    /// - Parameter context: The context to resolve the new `Promise` on. This is generally only
    ///   important when using callbacks registered with `.immediate`. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    ///   If provided as `.immediate`, behaves the same as `.auto`. If provided as `.operationQueue`
    ///   it enqueues an operation on the operation queue immediately that becomes ready once the
    ///   delay has elapsed.
    /// - Parameter delay: The number of seconds to delay the resulting promise by.
    /// - Returns: A `Promise` that adopts the same result as the receiver after a delay.
    public func delay(on context: PromiseContext = .auto, _ delay: TimeInterval) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        switch context.getDestination() {
        case .queue(let queue):
            _seal.enqueue { (result) in
                queue.asyncAfter(deadline: .now() + delay) {
                    resolver.resolve(with: result)
                }
            }
        case .operationQueue(let queue):
            let operation = TWLBlockOperation()
            _seal.enqueue { (result) in
                operation.addExecutionBlock {
                    resolver.resolve(with: result)
                }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
                    operation.markReady()
                }
            }
            queue.addOperation(operation)
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
    /// - Returns: A new `Promise`.
    public func timeout(on context: PromiseContext = .auto, delay: TimeInterval) -> Promise<Value,PromiseTimeoutError<Error>> {
        let (promise, resolver) = Promise<Value,PromiseTimeoutError<Error>>.makeWithResolver()
        let propagateCancelBlock = TWLOneshotBlock(block: { [weak _box] in
            _box?.propagateCancel()
        })
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
            propagateCancelBlock.invoke()
        }
        _seal.enqueue { (result) in
            timeoutBlock.cancel() // make sure we can't timeout merely because it raced our context switch
            context.execute {
                resolver.resolve(with: result.mapError({ .rejected($0) }))
            }
        }
        resolver.onRequestCancel(on: .immediate) { (resolver) in
            propagateCancelBlock.invoke()
        }
        if let queue = context.getQueue() {
            queue.asyncAfter(deadline: .now() + delay, execute: timeoutBlock)
        } else {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
                context.execute {
                    timeoutBlock.perform()
                }
            }
        }
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
    /// - Returns: A new `Promise`.
    public func timeout(on context: PromiseContext = .auto, delay: TimeInterval) -> Promise<Value,Swift.Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        let propagateCancelBlock = TWLOneshotBlock(block: { [weak _box] in
            _box?.propagateCancel()
        })
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
            propagateCancelBlock.invoke()
        }
        _seal.enqueue { (result) in
            timeoutBlock.cancel() // make sure we can't timeout merely because it raced our context switch
            context.execute {
                resolver.resolve(with: result)
            }
        }
        resolver.onRequestCancel(on: .immediate) { (resolver) in
            propagateCancelBlock.invoke()
        }
        if let queue = context.getQueue() {
            queue.asyncAfter(deadline: .now() + delay, execute: timeoutBlock)
        } else {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
                context.execute {
                    timeoutBlock.perform()
                }
            }
        }

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
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func ==(lhs: PromiseTimeoutError, rhs: PromiseTimeoutError) -> Bool {
        switch (lhs, rhs) {
        case (.timedOut, .timedOut): return true
        case let (.rejected(a), .rejected(b)): return a == b
        default: return false
        }
    }
    
    /// Returns a Boolean value indicating whether two values are not equal.
    ///
    /// Inequality is the inverse of equality. For any values `a` and `b`, `a != b`
    /// implies that `a == b` is `false`.
    ///
    /// This is the default implementation of the not-equal-to operator (`!=`)
    /// for any type that conforms to `Equatable`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
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
