//
//  Utilities.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 12/21/17.
//  Copyright © 2017 Lily Ballard.
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
    /// Returns a `Promise` that fulfills with the given value after a delay.
    ///
    /// Requesting that the promise be cancelled prior to it resolving will immediately cancel the
    /// promise.
    ///
    /// This can be used as a sort of cancellable timer. It can also be used in conjunction with
    /// `when(first:cancelRemaining:)` to implement a timeout that fulfills with a given value on
    /// timeout instead of rejecting with a `PromiseTimeoutError`.
    ///
    /// - Parameter context: The context to resolve the `Promise` on. This is generally only
    ///   important when using callbacks registered with `.immediate`. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    ///   If provided as `.immediate`, behaves the same as `.auto`. If provided as `.operationQueue`
    ///   it enqueues an operation on the operation queue immediately that becomes ready once the
    ///   delay has elapsed.
    /// - Parameter value: The value the promise will be fulfilled with.
    /// - Parameter delay: The number of seconds to delay the promise by.
    public init(on context: PromiseContext = .auto, fulfilled value: Value, after delay: TimeInterval) {
        self.init(on: context, with: .value(value), after: delay)
    }
    
    /// Returns a `Promise` that rejects with the given error after a delay.
    ///
    /// Requesting that the promise be cancelled prior to it resolving will immediately cancel the
    /// promise.
    ///
    /// - Parameter context: The context to resolve the `Promise` on. This is generally only
    ///   important when using callbacks registered with `.immediate`. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    ///   If provided as `.immediate`, behaves the same as `.auto`. If provided as `.operationQueue`
    ///   it enqueues an operation on the operation queue immediately that becomes ready once the
    ///   delay has elapsed.
    /// - Parameter error: The error the promise will be rejected with.
    /// - Parameter delay: The number of seconds to delay the promise by.
    public init(on context: PromiseContext = .auto, rejected error: Error, after delay: TimeInterval) {
        self.init(on: context, with: .error(error), after: delay)
    }
    
    /// Returns a `Promise` that resolves with the given result after a delay.
    ///
    /// Requesting that the promise be cancelled prior to it resolving will immediately cancel the
    /// promise.
    ///
    /// - Parameter context: The context to resolve the `Promise` on. This is generally only
    ///   important when using callbacks registered with `.immediate`. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    ///   If provided as `.immediate`, behaves the same as `.auto`. If provided as `.operationQueue`
    ///   it enqueues an operation on the operation queue immediately that becomes ready once the
    ///   delay has elapsed.
    /// - Parameter result: The result the promise will be resolved with.
    /// - Parameter delay: The number of seconds to delay the promise by.
    public init(on context: PromiseContext = .auto, with result: PromiseResult<Value,Error>, after delay: TimeInterval) {
        _seal = PromiseSeal()
        let resolver = Resolver(box: _box)
        let timer: DispatchSourceTimer
        switch context.getDestination() {
        case .queue(let queue):
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer.setEventHandler {
                resolver.resolve(with: result)
            }
        case .operationQueue(let queue):
            timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
            let operation = TWLBlockOperation {
                resolver.resolve(with: result)
            }
            timer.setEventHandler {
                operation.markReady()
            }
            timer.setCancelHandler {
                // Clean up the operation
                operation.cancel()
                operation.markReady()
            }
            queue.addOperation(operation)
        }
        resolver.onRequestCancel(on: .immediate) { (resolver) in
            timer.cancel() // NB: This reference also keeps the timer alive
            resolver.cancel()
        }
        timer.schedule(deadline: .now() + delay)
        timer.resume()
    }
    
    // MARK: -
    
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
            _seal._enqueue { (result, _) in
                let timer = DispatchSource.makeTimerSource(queue: queue)
                timer.setEventHandler {
                    resolver.resolve(with: result)
                    timer.cancel()
                }
                timer.schedule(deadline: .now() + delay)
                if case .cancelled = result {
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        timer.cancel()
                        resolver.cancel()
                    })
                }
                timer.resume()
            }
        case .operationQueue(let queue):
            let operation = TWLBlockOperation()
            _seal._enqueue { (result, _) in
                operation.addExecutionBlock {
                    resolver.resolve(with: result)
                }
                let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
                timer.setEventHandler {
                    operation.markReady()
                    timer.cancel()
                }
                timer.schedule(deadline: .now() + delay)
                if case .cancelled = result {
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        timer.cancel()
                        resolver.cancel()
                    })
                }
                timer.resume()
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
    ///   it enqueues an operation on the operation queue immediately that becomes ready when the
    ///   promise times out.
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
        let destination: TimeoutDestination
        switch context.getDestination() {
        case .queue(let queue): destination = .queue(queue)
        case .operationQueue(let operationQueue):
            let operation = TWLBlockOperation {
                timeoutBlock.perform()
            }
            destination = .operationQueue(operation, operationQueue)
        }
        _seal._enqueue { (result, isSynchronous) in
            timeoutBlock.cancel() // make sure we can't timeout merely because it raced our context switch
            context.execute(isSynchronous: isSynchronous) {
                resolver.resolve(with: result.mapError({ .rejected($0) }))
            }
            switch destination {
            case .queue: break
            case .operationQueue(let operation, _):
                // Clean up the operation early
                operation.cancel()
                operation.markReady()
            }
        }
        resolver.onRequestCancel(on: .immediate) { (resolver) in
            propagateCancelBlock.invoke()
        }
        switch destination {
        case .queue(let queue):
            queue.asyncAfter(deadline: .now() + delay, execute: timeoutBlock)
        case let .operationQueue(operation, queue):
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
                operation.markReady()
            }
            queue.addOperation(operation)
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
    ///   it enqueues an operation on the operation queue immediately that becomes ready when the
    ///   promise times out.
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
        let destination: TimeoutDestination
        switch context.getDestination() {
        case .queue(let queue): destination = .queue(queue)
        case .operationQueue(let operationQueue):
            let operation = TWLBlockOperation {
                timeoutBlock.perform()
            }
            destination = .operationQueue(operation, operationQueue)
        }
        _seal._enqueue { (result, isSynchronous) in
            timeoutBlock.cancel() // make sure we can't timeout merely because it raced our context switch
            context.execute(isSynchronous: isSynchronous) {
                resolver.resolve(with: result)
            }
            switch destination {
            case .queue: break
            case .operationQueue(let operation, _):
                // Clean up the operation early
                operation.cancel()
                operation.markReady()
            }
        }
        resolver.onRequestCancel(on: .immediate) { (resolver) in
            propagateCancelBlock.invoke()
        }
        switch destination {
        case .queue(let queue):
            queue.asyncAfter(deadline: .now() + delay, execute: timeoutBlock)
        case let .operationQueue(operation, queue):
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
                operation.markReady()
            }
            queue.addOperation(operation)
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

extension PromiseTimeoutError: Equatable where Error: Equatable {}

extension PromiseTimeoutError: Hashable where Error: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .timedOut: hasher.combine(0)
        case .rejected(let error):
            hasher.combine(1)
            hasher.combine(error)
        }
    }
}

// MARK: -

private enum TimeoutDestination {
    case queue(DispatchQueue)
    case operationQueue(TWLBlockOperation, OperationQueue)
}
