//
//  Promise.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 12/12/17.
//  Copyright © 2017 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Tomorrowland.Private
import Dispatch

/// The context in which a Promise body or callback is evaluated.
///
/// Most of these values correspond with Dispatch QoS classes.
public enum PromiseContext: Equatable, Hashable {
    /// Execute on the main queue.
    ///
    /// - Note: Chained callbacks on the `.main` context guarantee that they all execute within the
    ///   same run loop pass. This means UI manipulations in chained callbacks on `.main` will all
    ///   occur within the same CoreAnimation transaction. The only exception is if a callback
    ///   returns an unresolved nested promise, as the subsequent callbacks must wait for that
    ///   promise to resolve first.
    case main
    /// Execute on a dispatch queue with the `.background` QoS.
    case background
    /// Execute on a dispatch queue with the `.utility` QoS.
    case utility
    /// Execute on a dispatch queue with the `.default` QoS.
    case `default`
    /// Execute on a dispatch queue with the `.userInitiated` QoS.
    case userInitiated
    /// Execute on a dispatch queue with the `.userInteractive` QoS.
    case userInteractive
    /// Execute on the specified dispatch queue.
    case queue(DispatchQueue)
    /// Execute on the specified operation queue.
    case operationQueue(OperationQueue)
    /// Execute synchronously.
    ///
    /// - Important: If you use this option with a callback you must be prepared to handle the
    ///   callback executing on *any thread*. This option is usually only used when creating a
    ///   promise, and with callbacks is generally only suitable for running short bits of code that
    ///   are thread-independent. For example you may want to use this with
    ///   `resolver.onRequestCancel` if all you're doing is cancelling the promise, or asking a
    ///   network task to cancel, e.g.
    ///
    ///       resolver.onRequestCancel(on: .immediate, { (_) in
    ///           task.cancel()
    ///       })
    case immediate
    /// Execute synchronously if the promise is already resolved, otherwise use another context.
    ///
    /// This is a convenience for a pattern where you check a promise's `result` to see if it's
    /// already resolved and only attach a callback if it hasn't resolved yet. Passing this context
    /// to a callback will execute it synchronously before returning to the caller if and only if
    /// the promise has already resolved.
    ///
    /// If this is passed to a promise initializer it acts like `.immediate`. If passed to a
    /// `DelayedPromise` initializer it acts like the given context.
    indirect case nowOr(PromiseContext)
    
    /// Returns `.main` when accessed from the main thread, otherwise `.default`.
    public static var auto: PromiseContext {
        if Thread.isMainThread {
            return .main
        } else {
            return .default
        }
    }
    
    /// Returns whether a `.nowOr(_:)` context is executing synchronously.
    ///
    /// When accessed from within a callback registered with `.nowOr(_:)` this returns `true` if the
    /// callback is executing synchronously or `false` if it's executing on the wrapped context.
    /// When accessed from within a callback (including `Promise.init(on:_:)` registered with
    /// `.immediate` this returns `true` if and only if the callback is executing synchronously and
    /// is nested within a `.nowOr(_:)` context that is executing synchronously. When accessed from
    /// any other scenario this always returns `false`.
    ///
    /// - Remark: The behavior of `.immediate` is intended to allow `Promise(on: .immediate, { … })`
    ///   to query the synchronous state of its surrounding scope.
    ///
    /// - Note: This flag will return `false` when executed from within `DispatchQueue.main.sync`
    ///   nested inside a `.nowOr` callback, or any similar construct that blocks the current thread
    ///   and runs code on another thread.
    public static var isExecutingNow: Bool {
        return TWLGetSynchronousContextThreadLocalFlag()
    }
    
    /// Returns the `PromiseContext` that corresponds to a given Dispatch QoS class.
    ///
    /// If the given QoS is `.unspecified` then `.default` is assumed.
    public init(qos: DispatchQoS.QoSClass) {
        switch qos {
        case .background:
            self = .background
        case .utility:
            self = .utility
        case .unspecified, .default:
            self = .default
        case .userInitiated:
            self = .userInitiated
        case .userInteractive:
            self = .userInteractive
        @unknown default:
            self = .queue(.global(qos: qos))
        }
    }
    
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func ==(lhs: PromiseContext, rhs: PromiseContext) -> Bool {
        switch (lhs, rhs) {
        case (.main, .main), (.background, .background), (.utility, .utility),
             (.default, .default), (.userInitiated, .userInitiated), (.userInteractive, .userInteractive),
             (.immediate, .immediate): return true
        case (.main, _), (.background, _), (.utility, _), (.default, _),
             (.userInitiated, _), (.userInteractive, _), (.immediate, _): return false
        case let (.queue(a), .queue(b)): return a === b
        case (.queue, _): return false
        case let (.operationQueue(a), .operationQueue(b)): return a === b
        case (.operationQueue, _): return false
        case let (.nowOr(a), .nowOr(b)): return a == b
        case (.nowOr, _): return false
        }
    }
    
    internal func execute(isSynchronous: Bool, _ f: @escaping @convention(block) () -> Void) {
        switch self {
        case .main:
            if TWLGetMainContextThreadLocalFlag() {
                assert(Thread.isMainThread, "Found thread-local flag set while not executing on the main thread")
                // We're already executing on the .main context
                TWLEnqueueThreadLocalBlock(f)
            } else {
                var f = Optional.some(f)
                DispatchQueue.main.async {
                    TWLExecuteBlockWithMainContextThreadLocalFlag {
                        f.unsafelyUnwrapped()
                        f = nil
                        while let block = TWLDequeueThreadLocalBlock() {
                            block()
                        }
                    }
                }
            }
        case .background:
            DispatchQueue.global(qos: .background).async(execute: f)
        case .utility:
            DispatchQueue.global(qos: .utility).async(execute: f)
        case .default:
            DispatchQueue.global(qos: .default).async(execute: f)
        case .userInitiated:
            DispatchQueue.global(qos: .userInitiated).async(execute: f)
        case .userInteractive:
            DispatchQueue.global(qos: .userInteractive).async(execute: f)
        case .queue(let queue):
            queue.async(execute: f)
        case .operationQueue(let queue):
            queue.addOperation(f)
        case .immediate:
            if isSynchronous {
                // Inherit the synchronous context flag from our current scope
                f()
            } else {
                TWLExecuteBlockWithSynchronousContextThreadLocalFlag(false, f)
            }
        case .nowOr(let context):
            if isSynchronous {
                TWLExecuteBlockWithSynchronousContextThreadLocalFlag(true, f)
            } else {
                context.execute(isSynchronous: false, f)
            }
        }
    }
    
    internal enum Destination {
        case queue(DispatchQueue)
        case operationQueue(OperationQueue)
    }
    
    /// Returns the destination of the context. If the context is `.immediate` it behaves like
    /// `.auto`.
    internal func getDestination() -> Destination {
        switch self {
        case .main: return .queue(.main)
        case .background: return .queue(.global(qos: .background))
        case .utility: return .queue(.global(qos: .utility))
        case .default: return .queue(.global(qos: .default))
        case .userInitiated: return .queue(.global(qos: .userInitiated))
        case .userInteractive: return .queue(.global(qos: .userInteractive))
        case .queue(let queue): return.queue(queue)
        case .operationQueue(let queue): return .operationQueue(queue)
        case .immediate: return PromiseContext.auto.getDestination()
        case .nowOr(let context): return context.getDestination()
        }
    }
}

/// `StdPromise` is an alias for a `Promise` whose error type is `Swift.Error`.
public typealias StdPromise<Value> = Promise<Value,Swift.Error>

/// A `Promise` is a construct that will eventually hold a value or error, and can invoke callbacks
/// when that happens.
///
/// Example usage:
///
///     Promise(on: .utility) { resolver in
///         let value = try someLongComputation()
///         resolver.fulfill(with: value)
///     }.then(on: main) { value in
///         self.updateUI(with: value)
///     }.catch(on: .main) { error in
///         self.handleError(error)
///     }
///
/// Promises can also be cancelled. With a `Promise` object you can invoke `.requestCancel()`, which
/// is merely advisory; the promise does not have to actually implement cancellation and may resolve
/// anyway. But if a promise does implement cancellation, it can then call `resolver.cancel()`. Note
/// that even if the promise supports cancellation, calling `.requestCancel()` on an unresolved
/// promise does not guarantee that it will cancel, as the promise may be in the process of
/// resolving when that method is invoked. Make sure to use the invalidation token support if you
/// need to ensure your registered callbacks aren't invoked past a certain point.
///
/// - Note: If a registered callback is invoked (or would have been invoked if no token was
///   provided) it is guaranteed to be released on the context. This is important if the callback
///   captures a value whose deallocation must occur on a specific thread (such as the main thread).
///   If the callback is not invoked (ignoring tokens) it will be released on whatever thread the
///   promise was resolved on. For example, if a promise is fulfilled, any callback registered with
///   `.then(on:token:_:)` will be released on the context, but callbacks registered with
///   `.catch(on:token:_:)` will not. If you need to guarantee the thread that the callback is
///   released on, you should use `.always(on:token:_:)` or one of the `.mapResult(on:token:_:)`
///   variants.
public struct Promise<Value,Error> {
    /// A `Resolver` is used to fulfill, reject, or cancel its associated `Promise`.
    public struct Resolver {
        fileprivate let _box: PromiseBox<Value,Error>
        
        internal init(box: PromiseBox<Value,Error>) {
            _box = box
        }
        
        /// Fulfills the promise with the given value.
        ///
        /// If the promise has already been resolved or cancelled, this does nothing.
        public func fulfill(with value: Value) {
            _box.resolveOrCancel(with: .value(value))
        }
        
        /// Rejects the promise with the given error.
        ///
        /// If the promise has already been resolved or cancelled, this does nothing.
        public func reject(with error: Error) {
            _box.resolveOrCancel(with: .error(error))
        }
        
        /// Cancels the promise.
        ///
        /// If the promise has already been resolved or cancelled, this does nothing.
        public func cancel() {
            _box.resolveOrCancel(with: .cancelled)
        }
        
        /// Resolves the promise with the given result.
        ///
        /// If the promise has already been resolved or cancelled, this does nothing.
        public func resolve(with result: PromiseResult<Value,Error>) {
            _box.resolveOrCancel(with: result)
        }
        
        /// Resolves the promise with another promise.
        ///
        /// If `promise` has already been resolved, the receiver will be resolved immediately.
        /// Otherwise the receiver will wait until `promise` is resolved and resolve to the same
        /// result.
        ///
        /// If the receiver is cancelled, it will also propagate the cancellation to `promise`. If
        /// this is not desired, then either use `resolve(with: promise.ignoringCancel())` or
        /// `promise.always(on: .immediate, resolver.resolve(with:))`.
        public func resolve(with promise: Promise<Value,Error>) {
            promise.pipe(to: self)
        }
        
        /// Registers a block that will be invoked if `requestCancel()` is invoked on the promise
        /// before the promise is resolved.
        ///
        /// If the promise has already had cancellation requested (and is not resolved), the
        /// callback is invoked on the context at once.
        ///
        /// - Note: If you register the callback for a serial queue and resolve the promise on that
        ///   same serial queue, the callback is guaranteed to not execute after the promise is
        ///   resolved.
        ///
        /// - Parameter context: The context that the callback is invoked on.
        /// - Parameter callback: The callback to invoke.
        public func onRequestCancel(on context: PromiseContext, _ callback: @escaping (Resolver) -> Void) {
            let nodePtr = UnsafeMutablePointer<PromiseBox<Value,Error>.RequestCancelNode>.allocate(capacity: 1)
            nodePtr.initialize(to: .init(next: nil, context: context, callback: callback))
            if _box.swapRequestCancelLinkedList(with: UnsafeMutableRawPointer(nodePtr), linkBlock: { (nextPtr) in
                nodePtr.pointee.next = nextPtr?.assumingMemoryBound(to: PromiseBox<Value,Error>.RequestCancelNode.self)
            }) == TWLLinkedListSwapFailed {
                nodePtr.deinitialize(count: 1)
                nodePtr.deallocate()
                switch _box.unfencedState {
                case .cancelling, .cancelled:
                    context.execute(isSynchronous: true) {
                        callback(self)
                    }
                case .delayed, .empty, .resolving, .resolved:
                    break
                }
            }
        }
        
        /// Returns whether the promise has already been requested to cancel.
        ///
        /// This can be used when a promise init method does long-running work that can't easily be
        /// interrupted with a `onRequestCancel` handler.
        public var hasRequestedCancel: Bool {
            switch _box.unfencedState {
            case .cancelling, .cancelled: return true
            case .delayed, .empty, .resolving, .resolved: return false
            }
        }
        
        internal func propagateCancellation<T,E>(to promise: Promise<T,E>) {
            onRequestCancel(on: .immediate) { [weak box=promise._box] (_) in
                box?.propagateCancel()
            }
        }
    }
    
    /// Returns the result of the promise.
    ///
    /// Once this value becomes non-`nil` it will never change.
    public var result: PromiseResult<Value,Error>? {
        return _box.result
    }
    
    internal let _seal: PromiseSeal<Value,Error>
    internal var _box: PromiseBox<Value,Error> {
        return _seal.box
    }
    
    /// Returns a `Promise` and a `Promise.Resolver` that can be used to fulfill that promise.
    ///
    /// - Note: In most cases you want to use `Promise(on:_:)` instead.
    public static func makeWithResolver() -> (Promise<Value,Error>, Promise<Value,Error>.Resolver) {
        let promise = Promise<Value,Error>()
        return (promise, Resolver(box: promise._box))
    }
    
    /// Returns a new `Promise` that will be resolved using the given block.
    ///
    /// - Parameter context: The context to execute the handler on.
    /// - Parameter handler: A block that is executed in order to fulfill the promise.
    /// - Parameter resolver: The `Resolver` used to resolve the promise.
    public init(on context: PromiseContext, _ handler: @escaping (_ resolver: Resolver) -> Void) {
        _seal = PromiseSeal()
        let resolver = Resolver(box: _box)
        context.execute(isSynchronous: true) {
            handler(resolver)
        }
    }
    
    @available(*, unavailable, message: "Use Promise(on:_:) instead")
    public init(_ handler: @escaping (_ resolver: Resolver) -> Void) {
        fatalError()
    }
    
    private init() {
        _seal = PromiseSeal()
    }
    
    internal init(seal: PromiseSeal<Value,Error>) {
        _seal = seal
    }
    
    /// Returns a `Promise` that is already fulfilled with the given value.
    public init(fulfilled value: Value) {
        _seal = PromiseSeal(result: .value(value))
    }
    
    /// Returns a `Promise` that is already rejected with the given error.
    public init(rejected error: Error) {
        _seal = PromiseSeal(result: .error(error))
    }
    
    /// Returns a `Promise` that is already resolved with the given result.
    public init(with result: PromiseResult<Value,Error>) {
        _seal = PromiseSeal(result: result)
    }
    
    // MARK: -
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will resolve to the same value as the receiver. You may safely
    ///   ignore this value.
    public func then(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) -> Void) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onSuccess) { [generation=token?.generation] (result, onSuccess, isSynchronous) in
            switch result {
            case .value(let value):
                context.execute(isSynchronous: isSynchronous) {
                    let onSuccess = onSuccess()
                    if generation == token?.generation {
                        onSuccess(value)
                    }
                    resolver.fulfill(with: value)
                }
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be fulfilled with the return value of `onSuccess`. If the
    ///   receiver is rejected or cancelled, the returned promise will also be rejected or
    ///   cancelled.
    public func map<U>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) -> U) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onSuccess) { [generation=token?.generation] (result, onSuccess, isSynchronous) in
            switch result {
            case .value(let value):
                context.execute(isSynchronous: isSynchronous) {
                    let onSuccess = onSuccess()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    resolver.fulfill(with: onSuccess(value))
                }
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`. If the receiver is rejected or cancelled, the returned promise will also be
    ///   rejected or cancelled.
    public func flatMap<U>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) -> Promise<U,Error>) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onSuccess) { [generation=token?.generation] (result, onSuccess, isSynchronous) in
            switch result {
            case .value(let value):
                context.execute(isSynchronous: isSynchronous) {
                    let onSuccess = onSuccess()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    let nextPromise = onSuccess(value)
                    nextPromise.pipe(to: resolver)
                }
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// This method (or `always`) should be used to terminate a promise chain.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will resolve to the same value as the receiver. You may safely
    ///   ignore this value.
    @discardableResult
    public func `catch`(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Void) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    if generation == token?.generation {
                        onError(error)
                    }
                    resolver.reject(with: error)
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be fulfilled with the return value of `onError`. If the
    ///   receiver is fulfilled or cancelled, the returned promise will also be fulfilled or
    ///   cancelled.
    public func recover(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Value) -> Promise<Value,NoError> {
        let (promise, resolver) = Promise<Value,NoError>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    resolver.fulfill(with: onError(error))
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    //
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be rejected with the return value of `onError`. If the
    ///   receiver is fulfilled or cancelled, the returned promise will also be fulfilled or
    ///   cancelled.
    public func mapError<E>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> E) -> Promise<Value,E> {
        let (promise, resolver) = Promise<Value,E>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    resolver.reject(with: onError(error))
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`. If the receiver is fulfilled or cancelled, the returned promise will also be
    ///   fulfilled or cancelled.
    public func flatMapError<E>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Promise<Value,E>) -> Promise<Value,E> {
        let (promise, resolver) = Promise<Value,E>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    let nextPromise = onError(error)
                    nextPromise.pipe(to: resolver)
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    //
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be rejected with the return value of `onError`, or is
    ///   rejected if `onError` throws an error. If the receiver is fulfilled or cancelled, the
    ///   returned promise will also be fulfilled or cancelled.
    public func tryMapError<E: Swift.Error>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> E) -> Promise<Value,Swift.Error> {
        let (promise, resolver) = Promise<Value,Swift.Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    do {
                        resolver.reject(with: try onError(error))
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`, or is rejected if `onError` throws an error. If the receiver is fulfilled or
    ///   cancelled, the returned promise will also be fulfilled or cancelled.
    public func tryFlatMapError<E: Swift.Error>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Promise<Value,E>) -> Promise<Value,Swift.Error> {
        let (promise, resolver) = Promise<Value,Swift.Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    do {
                        let nextPromise = try onError(error)
                        nextPromise.pipe(toStd: resolver)
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    #if !compiler(>=5) // Swift 5 compiler makes the Swift.Error existential conform to itself
    /// Registers a callback that is invoked when the promise is rejected.
    //
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be rejected with the return value of `onError`, or is
    ///   rejected if `onError` throws an error. If the receiver is fulfilled or cancelled, the
    ///   returned promise will also be fulfilled or cancelled.
    public func tryMapError(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Swift.Error) -> Promise<Value,Swift.Error> {
        let (promise, resolver) = Promise<Value,Swift.Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    do {
                        resolver.reject(with: try onError(error))
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`, or is rejected if `onError` throws an error. If the receiver is fulfilled or
    ///   cancelled, the returned promise will also be fulfilled or cancelled.
    public func tryFlatMapError(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Promise<Value,Swift.Error>) -> Promise<Value,Swift.Error> {
        let (promise, resolver) = Promise<Value,Swift.Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    do {
                        let nextPromise = try onError(error)
                        nextPromise.pipe(to: resolver)
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    #endif
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked.
    /// - Parameter onComplete: The callback that is invoked with the promise's value.
    /// - Returns: A new promise that will resolve to the same value as the receiver. You may safely
    ///   ignore this value.
    @discardableResult
    public func always(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onComplete) { [generation=token?.generation] (result, onComplete, isSynchronous) in
            context.execute(isSynchronous: isSynchronous) {
                let onComplete = onComplete()
                if generation == token?.generation {
                    onComplete(result)
                }
                resolver.resolve(with: result)
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new result.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new result, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the result returned by `onComplete`.
    public func mapResult<T,E>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) -> PromiseResult<T,E>) -> Promise<T,E> {
        let (promise, resolver) = Promise<T,E>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onComplete) { [generation=token?.generation] (result, onComplete, isSynchronous) in
            context.execute(isSynchronous: isSynchronous) {
                let onComplete = onComplete()
                guard generation == token?.generation else {
                    resolver.cancel()
                    return
                }
                resolver.resolve(with: onComplete(result))
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the same value that the promise returned by
    ///   `onComplete` does.
    public func flatMapResult<T,E>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Promise<T,E>) -> Promise<T,E> {
        let (promise, resolver) = Promise<T,E>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onComplete) { [generation=token?.generation] (result, onComplete, isSynchronous) in
            context.execute(isSynchronous: isSynchronous) {
                let onComplete = onComplete()
                guard generation == token?.generation else {
                    resolver.cancel()
                    return
                }
                let nextPromise = onComplete(result)
                nextPromise.pipe(to: resolver)
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new result.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new result, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the result returned by `onComplete`, or is rejected
    ///   if `onComplete` throws an error.
    public func tryMapResult<T,E: Swift.Error>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> PromiseResult<T,E>) -> Promise<T,Swift.Error> {
        let (promise, resolver) = Promise<T,Swift.Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onComplete) { [generation=token?.generation] (result, onComplete, isSynchronous) in
            context.execute(isSynchronous: isSynchronous) {
                let onComplete = onComplete()
                guard generation == token?.generation else {
                    resolver.cancel()
                    return
                }
                do {
                    resolver.resolve(with: try onComplete(result))
                } catch {
                    resolver.reject(with: error)
                }
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the same value that the promise returned by
    ///   `onComplete` does, or is rejected if `onComplete` throws an error.
    public func tryFlatMapResult<T,E: Swift.Error>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,E>) -> Promise<T,Swift.Error> {
        let (promise, resolver) = Promise<T,Swift.Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onComplete) { [generation=token?.generation] (result, onComplete, isSynchronous) in
            context.execute(isSynchronous: isSynchronous) {
                let onComplete = onComplete()
                guard generation == token?.generation else {
                    resolver.cancel()
                    return
                }
                do {
                    let nextPromise = try onComplete(result)
                    nextPromise.pipe(toStd: resolver)
                } catch {
                    resolver.reject(with: error)
                }
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    #if !compiler(>=5) // Swift 5 compiler makes the Swift.Error existential conform to itself
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new result.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new result, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the result returned by `onComplete`, or is rejected
    ///   if `onComplete` throws an error.
    public func tryMapResult<T>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> PromiseResult<T,Swift.Error>) -> Promise<T,Swift.Error> {
        let (promise, resolver) = Promise<T,Swift.Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onComplete) { [generation=token?.generation] (result, onComplete, isSynchronous) in
            context.execute(isSynchronous: isSynchronous) {
                let onComplete = onComplete()
                guard generation == token?.generation else {
                    resolver.cancel()
                    return
                }
                do {
                    resolver.resolve(with: try onComplete(result))
                } catch {
                    resolver.reject(with: error)
                }
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the same value that the promise returned by
    ///   `onComplete` does, or is rejected if `onComplete` throws an error.
    public func tryFlatMapResult<T>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,Swift.Error>) -> Promise<T,Swift.Error> {
        let (promise, resolver) = Promise<T,Swift.Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onComplete) { [generation=token?.generation] (result, onComplete, isSynchronous) in
            context.execute(isSynchronous: isSynchronous) {
                let onComplete = onComplete()
                guard generation == token?.generation else {
                    resolver.cancel()
                    return
                }
                do {
                    let nextPromise = try onComplete(result)
                    nextPromise.pipe(to: resolver)
                } catch {
                    resolver.reject(with: error)
                }
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    #endif
    
    /// Registers a callback that will be invoked when the promise is resolved without affecting behavior.
    ///
    /// This is similar to an `always` callback except it doesn't create a new `Promise` and instead
    /// returns its receiver. This means it won't delay any chained callbacks and it won't affect
    /// automatic cancellation propagation behavior.
    ///
    /// This is similar to `tap().always(on:token:_:)` except it can be inserted into any promise
    /// chain without affecting the chain.
    ///
    /// - Note: This method is intended for inserting into the middle of a promise chain without
    ///   affecting existing behavior (in particular, cancellation propagation). If you are not
    ///   inserting this into the middle of a promise chain, you probably want to use
    ///   `then(on:token:_:)`, `map(on:token:_:)`, `catch(on:token:_:)`, or `always(on:token:_:)`
    ///   instead.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked.
    /// - Parameter onComplete: The callback that is invoked with the promise's value.
    /// - Returns: The receiver.
    ///
    /// - SeeAlso: `tap()`
    @discardableResult
    public func tap(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) -> Promise<Value,Error> {
        let token = token?.box
        _seal.enqueue(willPropagateCancel: false, makeOneshot: onComplete) { [generation=token?.generation] (result, onComplete, isSynchronous) in
            context.execute(isSynchronous: isSynchronous) {
                let onComplete = onComplete()
                if generation == token?.generation {
                    onComplete(result)
                }
            }
        }
        return self
    }
    
    /// Returns a new `Promise` that adopts the result of the receiver without affecting its behavior.
    ///
    /// The returned `Promise` will always resolve with the same value that its receiver does, but
    /// it won't affect the timing of any of the receiver's other observers and it won't affect
    /// automatic cancellation propagation behavior.
    ///
    /// `tap().always(on:token:_:)` behaves the same as `tap(on:token:_:)` except it returns a new
    /// `Promise` whereas `tap(on:token:_:)` returns the receiver and can be inserted into any
    /// promise chain without affecting the chain.
    ///
    /// - Note: This method is intended for inserting into the middle of a promise chain without
    ///   affecting existing behavior (in particular, cancellation propagation). If you are not
    ///   inserting this into the middle of a promise chain, you probably want to use
    ///   `then(on:token:_:)`, `map(on:token:_:)`, `catch(on:token:_:)`, or `always(on:token:_:)`
    ///   instead.
    ///
    /// - Returns: A new `Promise` that adopts the same result as the receiver. Requesting this new
    ///   promise to cancel does nothing.
    ///
    /// - SeeAlso: `tap(on:token:_:)`, `ignoringCancel()`
    public func tap() -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _seal._enqueue(willPropagateCancel: false) { (result, _) in
            resolver.resolve(with: result)
        }
        return promise
    }
    
    /// Registers a callback that will be invoked when the promise is cancelled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onCancel` from being invoked.
    /// - Parameter onCancel: The callback that is invoked when the promise is cancelled.
    /// - Returns: A new promise that will resolve to the same value as the receiver. You may safely
    ///   ignore this value.
    @discardableResult
    public func onCancel(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onCancel: @escaping () -> Void) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onCancel) { [generation=token?.generation] (result, onCancel, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                context.execute(isSynchronous: isSynchronous) {
                    let onCancel = onCancel()
                    if generation == token?.generation {
                        onCancel()
                    }
                    resolver.cancel()
                }
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    // MARK: -
    
    
    /// Returns a promise that adopts the same value as the receiver, and propagates cancellation
    /// from its children upwards even when it still exists.
    ///
    /// Normally cancellation is only propagated from children upwards when the parent promise is no
    /// longer held on to directly. This allows more children to be attached to the parent later,
    /// and only after the parent has been dropped will cancellation requests from its children
    /// propagate up to its own parent.
    ///
    /// This method returns a promise that ignores that logic and propagates cancellation upwards
    /// even while it still exists. As soon as all existing children have requested cancellation,
    /// the cancellation request will propagate to the receiver. A callback is provided to allow you
    /// to drop the returned promise at that point, so you don't try to attach new children.
    ///
    /// The intent of this method is to allow you to deduplicate requests for a long-lived resource
    /// (such as a network load) without preventing cancellation of the load in the event that no
    /// children care about it anymore.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter cancelRequested: The callback that is invoked when the promise is requested to
    ///   cancel, either because `.requestCancel()` was invoked on it directly or because all
    ///   children have requested cancellation. This callback is executed immediately prior to the
    ///   cancellation request being propagated to the receiver.
    /// - Parameter promise: The same promise that's returned from this method.
    /// - Returns: A new promise that will resolve to the same value as the receiver.
    public func propagatingCancellation(on context: PromiseContext, cancelRequested: @escaping (_ promise: Promise<Value,Error>) -> Void) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _seal._enqueue { (result, _) in
            resolver.resolve(with: result)
        }
        // Replicate the "oneshot" behavior from _seal.enqueue, as resolver.onRequestCancel does not have this same behavior.
        var callback = Optional.some(cancelRequested)
        let oneshot: () -> (Promise<Value,Error>) -> Void = {
            defer { callback = nil }
            return callback.unsafelyUnwrapped
        }
        resolver.onRequestCancel(on: context) { [weak box=self._box] _ in
            // Retaining promise in its own callback will keep it alive until it's resolved. This is
            // safe because our box is kept alive by the parent promise until it's resolved, and the
            // seal doesn't matter as we already sealed it.
            oneshot()(promise)
            box?.propagateCancel()
        }
        // Seal the promise now. This allows cancellation propagation.
        promise._box.seal()
        return promise
    }
    
    // MARK: -
    
    /// Passes the `Promise` to a block and then returns the `Promise` for further chaining.
    ///
    /// This method exists to make it easy to add multiple children to the same `Promise` in a
    /// promise chain.
    ///
    /// - Note: Having multiple children on a single `Promise` can interfere with automatic
    ///   cancellation propagation. You may want to use `tap(on:token:_:)` or `tap()` for your
    ///   sibling children if you're returning the result of the promise chain to a caller that may
    ///   wish to cancel the chain.
    ///
    /// Example:
    ///
    ///     return urlSession.dataTaskAsPromise(for: url)
    ///         .fork({ $0.tap().then(on: .main, { analytics.recordNetworkLoad($0.response, for: url) }) })
    ///         .tryMap(on: .utility, { try JSONDecoder().decode(Model.self, from: $0.data) })
    public func fork(_ handler: (Promise) throws -> Void) rethrows -> Promise {
        try handler(self)
        return self
    }
    
    /// Requests that the `Promise` should be cancelled.
    ///
    /// If the promise is already resolved, this does nothing. Otherwise, if the `Promise` registers
    /// any `onRequestCancel` handlers, those handlers will be called.
    ///
    /// - Note: Requesting that a `Promise` should be cancelled doesn't guarantee it will be. If you
    ///   need to ensure your `then` block isn't invoked, also use a `PromiseInvalidationToken` and
    ///   call `.invalidate()` on it.
    public func requestCancel() {
        _box.requestCancel()
    }
    
    /// Requests that the `Promise` should be cancelled when the token is invalidated.
    ///
    /// This is equivalent to calling `token.requestCancelOnInvalidate(promise)` and is intended to
    /// be used to terminate a promise chain. For example:
    ///
    ///     urlSession.promiseDataTask(for: url).then(token: token, { (data) in
    ///         …
    ///     }).catch(token: token, { (error) in
    ///         …
    ///     }).requestCancelOnInvalidate(token)
    ///
    /// - Parameter token: A `PromiseInvalidationToken`. When the token is invalidated the receiver
    ///   will be requested to cancel.
    /// - Returns: The receiver. This value can be ignored.
    @discardableResult
    public func requestCancelOnInvalidate(_ token: PromiseInvalidationToken) -> Promise<Value,Error> {
        token.requestCancelOnInvalidate(self)
        return self
    }
    
    /// Returns a new `Promise` that adopts the value of the receiver but ignores cancel requests.
    ///
    /// This is primarily useful when returning a nested promise in a callback handler in order to
    /// unlink cancellation of the outer promise with the inner one. It can also be used to stop
    /// propagating cancel requests up the chain, e.g. if you want to implement something similar to
    /// `tap(on:token:_:)`.
    ///
    /// - Note: This is similar to `tap()` except it prevents the parent promise from being
    ///   automatically cancelled due to cancel propagation from any observer.
    ///
    /// - Note: The returned `Promise` will still be cancelled if its parent promise is cancelled.
    ///
    /// - SeeAlso: `tap()`
    public func ignoringCancel() -> Promise<Value,Error> {
        let (promise, resolver) = Promise.makeWithResolver()
        _seal._enqueue { (result, _) in
            resolver.resolve(with: result)
        }
        return promise
    }
    
    private func pipe(to resolver: Promise<Value,Error>.Resolver) {
        _seal._enqueue { (result, _) in
            resolver.resolve(with: result)
        }
        resolver.onRequestCancel(on: .immediate) { [cancellable] (_) in
            cancellable.requestCancel()
        }
    }
}

// MARK: Promise<_,E> where E: Swift.Error

extension Promise where Error: Swift.Error {
    /// Returns a new promise with an error type of `Swift.Error`.
    ///
    /// The new promise adopts the exact same result as the receiver, but if the promise resolves to
    /// an error, it's upcast to `Swift.Error`.
    public var upcast: Promise<Value,Swift.Error> {
        let (promise, resolver) = Promise<Value,Swift.Error>.makeWithResolver()
        pipe(toStd: resolver)
        return promise
    }
    
    private func pipe(toStd resolver: Promise<Value,Swift.Error>.Resolver) {
        _seal._enqueue { (result, _) in
            resolver.resolve(with: result)
        }
        resolver.onRequestCancel(on: .immediate) { [cancellable] (_) in
            cancellable.requestCancel()
        }
    }
}

// MARK: Promise<_,NoError>

extension Promise where Error == NoError {
    /// Returns a new promise with an error type of `Swift.Error`.
    ///
    /// The new promise adopts the exact same result as the receiver. As the receiver's error type
    /// is `NoError`, the receiver cannot ever be rejected, but this upcast allows the promise to
    /// compose better with other promises.
    public var upcast: Promise<Value,Swift.Error> {
        let (promise, resolver) = Promise<Value,Swift.Error>.makeWithResolver()
        _seal._enqueue { (result, _) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error:
                fatalError("unreachable")
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.onRequestCancel(on: .immediate) { [cancellable] (_) in
            cancellable.requestCancel()
        }
        return promise
    }
}

// MARK: Promise<_,Swift.Error>

extension Promise where Error == Swift.Error {
    /// Returns a new `Promise` that will be resolved using the given block.
    ///
    /// - Parameter context: The context to execute the handler on.
    /// - Parameter handler: A block that is executed in order to fulfill the promise. If the block
    ///   throws an error the promise will be rejected (unless it was already resolved first).
    /// - Parameter resolver: The `Resolver` used to resolve the promise.
    public init(on context: PromiseContext, _ handler: @escaping (_ resolver: Resolver) throws -> Void) {
        _seal = PromiseSeal()
        let resolver = Resolver(box: _box)
        context.execute(isSynchronous: true) {
            do {
                try handler(resolver)
            } catch {
                resolver.reject(with: error)
            }
        }
    }
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will resolve to the same value as the receiver, or rejected if
    ///   `onSuccess` throws an error. If the receiver is rejected or cancelled, the returned
    ///   promise will also be rejected or cancelled.
    public func tryThen(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Void) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onSuccess) { [generation=token?.generation] (result, onSuccess, isSynchronous) in
            switch result {
            case .value(let value):
                context.execute(isSynchronous: isSynchronous) {
                    let onSuccess = onSuccess()
                    do {
                        if generation == token?.generation {
                            try onSuccess(value)
                        }
                        resolver.fulfill(with: value)
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be fulfilled with the return value of `onSuccess`, or
    ///   rejected if `onSuccess` throws an error. If the receiver is rejected or cancelled, the
    ///   returned promise will also be rejected or cancelled.
    public func tryMap<U>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> U) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onSuccess) { [generation=token?.generation] (result, onSuccess, isSynchronous) in
            switch result {
            case .value(let value):
                context.execute(isSynchronous: isSynchronous) {
                    let onSuccess = onSuccess()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    do {
                        resolver.fulfill(with: try onSuccess(value))
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    #if !compiler(>=5) // Swift 5 compiler makes the Swift.Error existential conform to itself
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`, or rejected if `onSuccess` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    public func tryFlatMap<U>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Promise<U,Error>) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue { [generation=token?.generation] (result, isSynchronous) in
            switch result {
            case .value(let value):
                context.execute(isSynchronous: isSynchronous) {
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    do {
                        let nextPromise = try onSuccess(value)
                        nextPromise.pipe(to: resolver)
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    #endif
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`, or rejected if `onSuccess` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    public func tryFlatMap<U,E: Swift.Error>(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Promise<U,E>) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onSuccess) { [generation=token?.generation] (result, onSuccess, isSynchronous) in
            switch result {
            case .value(let value):
                context.execute(isSynchronous: isSynchronous) {
                    let onSuccess = onSuccess()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    do {
                        let nextPromise = try onSuccess(value)
                        nextPromise.pipe(toStd: resolver)
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    ///
    /// - Parameter context: The context to invoke the callback on.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be fulfilled with the return value of `onError`, or
    ///   rejected if `onError` throws an error. If the receiver is rejected or cancelled, the
    ///   returned promise will also be rejected or cancelled.
    public func tryRecover(on context: PromiseContext, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Value) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        let token = token?.box
        _seal.enqueue(makeOneshot: onError) { [generation=token?.generation] (result, onError, isSynchronous) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute(isSynchronous: isSynchronous) {
                    let onError = onError()
                    guard generation == token?.generation else {
                        resolver.cancel()
                        return
                    }
                    do {
                        resolver.fulfill(with: try onError(error))
                    } catch {
                        resolver.reject(with: error)
                    }
                }
            case .cancelled:
                resolver.cancel()
            }
        }
        resolver.propagateCancellation(to: self)
        return promise
    }
}

// MARK: Equatable

extension Promise: Equatable {
    /// Two `Promise`s compare as equal if they represent the same promise.
    ///
    /// Two distinct `Promise`s that are resolved to the same value compare as unequal.
    public static func ==(lhs: Promise, rhs: Promise) -> Bool {
        return lhs._box === rhs._box
    }
}

// MARK: Resolver<_,Swift.Error>

extension Promise.Resolver where Error == Swift.Error {
    /// Resolves the promise with the given result.
    ///
    /// If the promise has already been resolved or cancelled, this does nothing.
    public func resolve<E: Swift.Error>(with result: PromiseResult<Value,E>) {
        switch result {
        case .value(let value): fulfill(with: value)
        case .error(let error): reject(with: error)
        case .cancelled: cancel()
        }
    }
    
    /// Convenience method for handling framework callbacks.
    ///
    /// This method returns a closure that can be passed to a framework method as a callback in
    /// order to resolve the promise. It takes an optional parameter that can be used to determine
    /// when the error represents cancellation. For example:
    ///
    ///     geocoder.reverseGeocodeLocation(location, completionHandler: resolver.handleCallback(isCancelError: { CLError.geocodeCanceled ~= $0 }))
    ///
    /// If both the `Value` and `Error` passed to the closure are `nil` the promise is rejected with
    /// `PromiseCallbackError.apiMismatch`. If they're both non-`nil` this should be considered an
    /// error, but the promise will be fulfilled with the value and the error will be ignored.
    ///
    /// - Parameter isCancelError: An optional block that can be used to indicate that specific
    ///   errors represent cancellation.
    /// - Returns: A closure that can be passed to a framework method as a callback.
    public func handleCallback(isCancelError: @escaping (Error) -> Bool = { _ in false }) -> (Value?, Error?) -> Void {
        return { (value, error) in
            if let value = value {
                self.fulfill(with: value)
            } else if let error = error {
                if isCancelError(error) {
                    self.cancel()
                } else {
                    self.reject(with: error)
                }
            } else {
                self.reject(with: PromiseCallbackError.apiMismatch)
            }
        }
    }
}

/// An error potentially returned from `Promise.Resolver.handleCallback(isCancelError:)`.
@objc(TWLPromiseCallbackError)
public enum PromiseCallbackError: Int, Error {
    /// The callback did not conform to the expected API.
    @objc(TWLPromiseCallbackErrorAPIMismatch)
    case apiMismatch
}

/// The result of a resolved promise.
public enum PromiseResult<Value,Error> {
    /// The value the promise was fulfilled with.
    case value(Value)
    /// The error the promise was rejected with.
    case error(Error)
    /// The promise was cancelled.
    case cancelled
    
    /// Returns the contained value if the result is `.value`, otherwise `nil`.
    public var value: Value? {
        switch self {
        case .value(let value): return value
        case .error, .cancelled: return nil
        }
    }
    
    /// Returns the contained error if the result is `.error`, otherwise `nil`.
    public var error: Error? {
        switch self {
        case .value, .cancelled: return nil
        case .error(let error): return error
        }
    }
    
    /// Returns `true` if the result is `.cancelled`, otherwise `false`.
    public var isCancelled: Bool {
        switch self {
        case .value, .error: return false
        case .cancelled: return true
        }
    }
    
    /// Maps a successful result through a block and returns the new result.
    public func map<T>(_ transform: (Value) throws -> T) rethrows -> PromiseResult<T,Error> {
        switch self {
        case .value(let value): return .value(try transform(value))
        case .error(let error): return .error(error)
        case .cancelled: return .cancelled
        }
    }
    
    /// Maps a rejected result through a block and returns the new result.
    public func mapError<E>(_ transform: (Error) throws -> E) rethrows -> PromiseResult<Value,E> {
        switch self {
        case .value(let value): return .value(value)
        case .error(let error): return .error(try transform(error))
        case .cancelled: return .cancelled
        }
    }
    
    /// Maps a successful result through a block and returns the new result.
    public func flatMap<T>(_ transform: (Value) throws -> PromiseResult<T,Error>) rethrows -> PromiseResult<T,Error> {
        switch self {
        case .value(let value): return try transform(value)
        case .error(let error): return .error(error)
        case .cancelled: return .cancelled
        }
    }
    
    /// Maps a rejected result through a block and returns the new result.
    public func flatMapError<E>(_ transform: (Error) throws -> PromiseResult<Value,E>) rethrows -> PromiseResult<Value,E> {
        switch self {
        case .value(let value): return .value(value)
        case .error(let error): return try transform(error)
        case .cancelled: return .cancelled
        }
    }
}

extension PromiseResult: Equatable where Value: Equatable, Error: Equatable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func ==(lhs: PromiseResult, rhs: PromiseResult) -> Bool {
        switch (lhs, rhs) {
        case let (.value(a), .value(b)) where a == b: return true
        case let (.error(a), .error(b)) where a == b: return true
        case (.cancelled, .cancelled): return true
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
    public static func !=(lhs: PromiseResult, rhs: PromiseResult) -> Bool {
        return !(lhs == rhs)
    }
}

// MARK: -

extension Promise {
    /// Returns a value that can be used to cancel this promise without holding onto the full promise.
    ///
    /// In particular, this acts like a weak reference, allowing for cancelling the promise without
    /// creating a retain cycle. Promise retain cycles normally break themselves anyway when the promise
    /// is resolved, but a misbehaving promise body may drop the resolver without ever resolving the
    /// promise. If the `Promise` has no more references to it this automatically cancels the
    /// promise, but a retain cycle prevents this.
    ///
    /// If you trust the promise provider to always resolve the promise, you can safely ignore this.
    public var cancellable: PromiseCancellable {
        return PromiseCancellable(_box)
    }
}

/// A type that can be used to cancel a promise without holding onto the full promise.
///
/// In particular, this acts like a weak reference, allowing for cancelling the promise without
/// creating a retain cycle. Promise retain cycles normally break themselves anyway when the promise
/// is resolved, but a misbehaving promise body may drop the resolver without ever resolving the
/// promise. If the `Promise` has no more references to it this automatically cancels the
/// promise, but a retain cycle prevents this.
///
/// This is returned from `Promise.cancellable`.
public struct PromiseCancellable {
    private(set) fileprivate weak var cancellable: TWLCancellable?
    
    fileprivate init(_ cancellable: TWLCancellable) {
        self.cancellable = cancellable
    }
    
    /// Requests cancellation of the promise this `PromiseCancellable` was created from.
    public func requestCancel() {
        cancellable?.requestCancel()
    }
}

extension PromiseResult: Hashable where Value: Hashable, Error: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .value(let value):
            hasher.combine(0)
            hasher.combine(value)
        case .error(let error):
            hasher.combine(1)
            hasher.combine(error)
        case .cancelled:
            hasher.combine(2)
        }
    }
}

extension PromiseResult {
    /// :nodoc:
    enum CodingKeys: CodingKey {
        case value
        case error
    }
}

extension PromiseResult: Encodable where Value: Encodable, Error: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .value(let value):
            try container.encode(value, forKey: .value)
            try container.encodeNil(forKey: .error)
        case .error(let error):
            try container.encodeNil(forKey: .value)
            try container.encode(error, forKey: .error)
        case .cancelled:
            try container.encodeNil(forKey: .value)
            try container.encodeNil(forKey: .error)
        }
    }
}

extension PromiseResult: Decodable where Value: Decodable, Error: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decode(Optional<Value>.self, forKey: .value) {
            self = .value(value)
        } else if let error = try container.decode(Optional<Error>.self, forKey: .error) {
            self = .error(error)
        } else {
            self = .cancelled
        }
    }
}

// MARK: -

/// An invalidation token that can be used to cancel callbacks registered to a `Promise`.
public struct PromiseInvalidationToken: CustomStringConvertible, CustomDebugStringConvertible {
    private let _inner: Inner
    
    /// Creates and returns a new `PromiseInvalidationToken`.
    ///
    /// - Parameter invalidateOnDeinit: The default value of `true` means the token will
    ///   automatically be invalidated when it deinits. If `false` it won't invalidate unless you
    ///   explicitly call `invalidate()`. This is primarily useful in conjunction with
    ///   `requestCancelOnInvalidate(_:)` so you don't have to cancel your promises when the object
    ///   that owns the invalidation token deinits.
    public init(invalidateOnDeinit: Bool = true) {
        _inner = Inner(invalidateOnDeinit: invalidateOnDeinit)
    }
    
    /// Invalidates the token and cancels any associated promises.
    ///
    /// After invoking this method, all `Promise` callbacks registered with this token will be
    /// suppressed. Any callbacks whose return value is used for a subsequent promise (e.g. with
    /// `map(on:token:_:)`) will result in a cancelled promise instead if the callback would
    /// otherwise have been executed.
    ///
    /// In addition, any promises that have been registered with `requestCancelOnInvalidate(_:)`
    /// will be requested to cancel.
    public func invalidate() {
        box.invalidate()
    }
    
    /// Cancels any associated promises without invalidating the token.
    ///
    /// After invoking this method, any promises that have been registered with
    /// `requestCancelOnInvalidate(_:)` will be requested to cancel.
    public func cancelWithoutInvalidating() {
        box.cancelWithoutInvalidating()
    }
    
    /// Registers a `Promise` to be requested to cancel automatically when the token is invalidated.
    public func requestCancelOnInvalidate<V,E>(_ promise: Promise<V,E>) {
        box.requestCancelOnInvalidate(promise.cancellable)
    }
    
    /// Registers an `ObjCPromise` to be requested to cancel automatically when the token is
    /// invalidated.
    public func requestCancelOnInvalidate<V,E>(_ promise: ObjCPromise<V,E>) {
        box.requestCancelOnInvalidate(PromiseCancellable(promise.cancellable))
    }
    
    /// Invalidates the token whenever another token is invalidated.
    ///
    /// When the given other token is invalidated, the receiver will also be invalidated. This
    /// allows you to build trees of tokens for fine-grained cancellation control while still
    /// allowing for the ability to cancel a lot of promises from a single token.
    ///
    /// - Note: Chained invalidation is a permanent relationship with no way to un-chain it later.
    ///   Invalidating `token` multiple times will invalidate the receiver every time.
    ///
    /// - Remark: By using chained invalidation it's possible to construct a scenario wherein you
    ///   respond to cancellation of a promise associated with the parent token by immediately
    ///   constructing a new promise using a child token, prior to the child token being invalidated
    ///   due to the parent token's invalidation. This is a rather esoteric case.
    ///
    /// - Important: Do not introduce any cycles into the invalidation chain, as this will produce
    ///   an infinite loop upon invalidation.
    ///
    /// - Parameter token: Another token that, when invalidated, will cause the current token to be
    ///   invalidated as well.
    /// - Parameter includingCancelWithoutInvalidating: The default value of `true` means calls to
    ///   `token.cancelWithoutInvalidating()` will similarly call `cancelWithoutInvalidating()` on
    ///   the current token.
    public func chainInvalidation(from token: PromiseInvalidationToken, includingCancelWithoutInvalidating: Bool = true) {
        box.chainInvalidation(from: token.box, includingCancelWithoutInvalidating: includingCancelWithoutInvalidating)
    }
    
    fileprivate var box: PromiseInvalidationTokenBox {
        return _inner.box
    }
    
    // hack for TWLInvalidationToken
    internal var __objcBox: TWLPromiseInvalidationTokenBox {
        return box
    }
    
    private class Inner {
        let invalidateOnDeinit: Bool
        let box: PromiseInvalidationTokenBox
        
        init(invalidateOnDeinit: Bool) {
            box = PromiseInvalidationTokenBox()
            self.invalidateOnDeinit = invalidateOnDeinit
        }
        
        deinit {
            if invalidateOnDeinit {
                box.invalidate()
            }
        }
    }
    
    public var description: String {
        return "<PromiseInvalidationToken: \(String(UInt(bitPattern: Unmanaged.passUnretained(_inner).toOpaque()), radix: 16))>"
    }
    
    public var debugDescription: String {
        return "<PromiseInvalidationToken: \(String(UInt(bitPattern: Unmanaged.passUnretained(_inner).toOpaque()), radix: 16)); box=\(_inner.box)>"
    }
}

// MARK: Equatable

extension PromiseInvalidationToken: Hashable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func ==(lhs: PromiseInvalidationToken, rhs: PromiseInvalidationToken) -> Bool {
        return lhs._inner === rhs._inner
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(_inner))
    }
}

/// `NoError` is a type that cannot be constructed.
///
/// It's intended to be used as the error type for promises that cannot return an error. It is
/// similar to `Never` except it conforms to some protocols in order to make working with types
/// containing it easier.
public enum NoError: Hashable, Equatable, Codable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func ==(lhs: NoError, rhs: NoError) -> Bool {
        #if !compiler(>=5.1)
        return true
        #endif
    }
    
    public func hash(into hasher: inout Hasher) {}
    
    public init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Tomorrowland.NoError does not support decoding."))
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError()
    }
}

// MARK: - Private

private class PromiseInvalidationTokenBox: TWLPromiseInvalidationTokenBox {
    private struct CallbackNode {
        var next: UnsafeMutablePointer<CallbackNode>?
        var generation: UInt
        let cancellable: PromiseCancellable
        
        static func castPointer(_ pointer: UnsafeMutableRawPointer) -> UnsafeMutablePointer<CallbackNode>? {
            guard UInt(bitPattern: pointer) & 1 == 0 else { return nil }
            return pointer.assumingMemoryBound(to: self)
        }
        
        /// Destroys the linked list.
        ///
        /// - Precondition: The pointer must be initialized.
        /// - Postcondition: The pointer is deallocated.
        static func destroyPointer(_ pointer: UnsafeMutablePointer<CallbackNode>) {
            var nextPointer = pointer.pointee.next
            pointer.deinitialize(count: 1)
            pointer.deallocate()
            while let current = nextPointer {
                nextPointer = current.pointee.next
                current.deinitialize(count: 1)
                current.deallocate()
            }
        }
        
        static func reverseList(_ pointer: UnsafeMutablePointer<CallbackNode>) -> UnsafeMutablePointer<CallbackNode> {
            var nextPointer = replace(&pointer.pointee.next, with: nil)
            var previous = pointer
            while let next = nextPointer {
                nextPointer = replace(&next.pointee.next, with: previous)
                previous = next
            }
            return previous
        }
        
        static func generation(from pointer: UnsafeMutableRawPointer) -> UInt {
            if let nodePtr = castPointer(pointer) {
                return nodePtr.pointee.generation
            } else {
                return interpretTaggedInteger(pointer)
            }
        }
        
        static func interpretTaggedInteger(_ pointer: UnsafeMutableRawPointer) -> UInt {
            return UInt(bitPattern: pointer) >> 1
        }
    }
    
    private struct TokenChainNode {
        var next: UnsafeMutablePointer<TokenChainNode>?
        let includesCancelWithoutInvalidation: Bool
        weak var tokenBox: PromiseInvalidationTokenBox?
        
        static func castPointer(_ pointer: UnsafeMutableRawPointer) -> UnsafeMutablePointer<TokenChainNode> {
            return pointer.assumingMemoryBound(to: TokenChainNode.self)
        }
        
        /// Destroys the linked list
        ///
        /// - Precondition: The pointer must be initialized.
        /// - Postcondition: The pointer is deallocated.
        static func destroyPointer(_ pointer: UnsafeMutablePointer<TokenChainNode>) {
            var nextPointer = pointer.pointee.next
            pointer.deinitialize(count: 1)
            pointer.deallocate()
            while let current = nextPointer {
                nextPointer = current.pointee.next
                current.deinitialize(count: 1)
                current.deallocate()
            }
        }
    }
    
    deinit {
        if let nodePtr = CallbackNode.castPointer(callbackLinkedList) {
            CallbackNode.destroyPointer(nodePtr)
        }
        if let nodePtr = tokenChainLinkedList.map(TokenChainNode.castPointer) {
            TokenChainNode.destroyPointer(nodePtr)
        }
    }
    
    func invalidate() {
        // Read the invalidation chain before calling out to external code
        let tokenChain = tokenChainLinkedList.map(TokenChainNode.castPointer)
        
        resetCallbacks(andIncrementGenerationBy: 1)
        
        if let tokenChain = tokenChain {
            for nodePtr in sequence(first: tokenChain, next: { $0.pointee.next }) {
                nodePtr.pointee.tokenBox?.invalidate()
            }
        }
    }
    
    func cancelWithoutInvalidating() {
        // Read the invalidation chain before calling out to external code
        let tokenChain = tokenChainLinkedList.map(TokenChainNode.castPointer)
        
        resetCallbacks(andIncrementGenerationBy: 0)
        
        if let tokenChain = tokenChain {
            for nodePtr in sequence(first: tokenChain, next: { $0.pointee.next }) where nodePtr.pointee.includesCancelWithoutInvalidation {
                nodePtr.pointee.tokenBox?.cancelWithoutInvalidating()
            }
        }
    }
    
    func requestCancelOnInvalidate(_ cancellable: PromiseCancellable) {
        let nodePtr = UnsafeMutablePointer<CallbackNode>.allocate(capacity: 1)
        nodePtr.initialize(to: .init(next: nil, generation: 0, cancellable: cancellable))
        var freeRange: (from: UnsafeMutablePointer<CallbackNode>, to: UnsafeMutablePointer<CallbackNode>?)?
        pushNodeOntoCallbackLinkedList(nodePtr) { (rawPtr) in
            if let nextPtr = CallbackNode.castPointer(rawPtr) {
                nodePtr.pointee.generation = nextPtr.pointee.generation
                // Prune nil promises off the top of the list.
                // This is safe to do because we aren't modifying any shared data structures, only
                // tweaking the `next` pointer of our brand new node. Any popped nodes are freed
                // when we're done.
                var next = Optional.some(nextPtr)
                while let nextPtr = next, nextPtr.pointee.cancellable.cancellable == nil {
                    next = nextPtr.pointee.next
                }
                nodePtr.pointee.next = next
                freeRange = (nextPtr, next)
            } else {
                nodePtr.pointee.generation = CallbackNode.interpretTaggedInteger(rawPtr)
                nodePtr.pointee.next = nil
            }
        }
        // Free any popped nodes
        var next = freeRange?.from
        while let nextPtr = next, nextPtr != freeRange?.to {
            next = nextPtr.pointee.next
            nextPtr.deinitialize(count: 1)
            nextPtr.deallocate()
        }
    }
    
    func chainInvalidation(from token: PromiseInvalidationTokenBox, includingCancelWithoutInvalidating: Bool) {
        guard token !== self else { return } // trivial check for looping on self
        let nodePtr = UnsafeMutablePointer<TokenChainNode>.allocate(capacity: 1)
        nodePtr.initialize(to: .init(next: nil, includesCancelWithoutInvalidation: includingCancelWithoutInvalidating, tokenBox: self))
        var freeRange: (from: UnsafeMutablePointer<TokenChainNode>, to: UnsafeMutablePointer<TokenChainNode>?)?
        token.pushNodeOntoTokenChainLinkedList(nodePtr) { (rawPtr) in
            let nextPtr = TokenChainNode.castPointer(rawPtr)
            // Prune nil tokens off the top of the list.
            // This is safe to do because we aren't modifying any shared data structures, only
            // tweaking the `next` pointer of our brand new node. Any popped nodes are freed when
            // we're done.
            var next = Optional.some(nextPtr)
            while let nextPtr = next, nextPtr.pointee.tokenBox == nil {
                next = nextPtr.pointee.next
            }
            nodePtr.pointee.next = next
            freeRange = (nextPtr, next)
        }
        // Free any popped nodes
        var next = freeRange?.from
        while let nextPtr = next, nextPtr != freeRange?.to {
            next = nextPtr.pointee.next
            nextPtr.deinitialize(count: 1)
            nextPtr.deallocate()
        }
    }
    
    @objc internal var generation: UInt {
        return CallbackNode.generation(from: callbackLinkedList)
    }
    
    private func resetCallbacks(andIncrementGenerationBy increment: UInt) {
        let rawPtr = resetCallbackLinkedList { (ptr) -> UInt in
            return CallbackNode.generation(from: ptr) &+ increment
        }
        if var nodePtr = CallbackNode.castPointer(rawPtr) {
            nodePtr = CallbackNode.reverseList(nodePtr)
            defer {
                CallbackNode.destroyPointer(nodePtr)
            }
            for nodePtr in sequence(first: nodePtr, next: { $0.pointee.next }) {
                nodePtr.pointee.cancellable.requestCancel()
            }
        }
    }
    
    override var description: String {
        let address = "0x\(String(UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque()), radix: 16))"
        let generation: UInt
        let callbackCount: String
        do {
            let rawPtr = callbackLinkedList
            if let nodePtr = CallbackNode.castPointer(rawPtr) {
                generation = nodePtr.pointee.generation
                let count = sequence(first: nodePtr, next: { $0.pointee.next }).reduce(0, { (x, _) in x + 1 })
                callbackCount = "\(count) node\(count == 1 ? "" : "s")"
            } else {
                generation = CallbackNode.interpretTaggedInteger(rawPtr)
                callbackCount = "0 nodes"
            }
        }
        let tokenChainCount: String
        if let nodePtr = tokenChainLinkedList.map(TokenChainNode.castPointer) {
            let count = sequence(first: nodePtr, next: { $0.pointee.next }).reduce(0, { (x, _) in x + 1 })
            tokenChainCount = "\(count) node\(count == 1 ? "" : "s")"
        } else {
            tokenChainCount = "0 nodes"
        }
        return "<\(type(of: self)): \(address); generation=\(generation) callbackLinkedList=(\(callbackCount)) tokenChainLinkedList=(\(tokenChainCount))>"
    }
}

internal class PromiseBox<T,E>: TWLPromiseBox, TWLCancellable {
    struct CallbackNode: NodeProtocol {
        var next: UnsafeMutablePointer<CallbackNode>?
        var callback: (PromiseResult<T,E>, _ isSynchronous: Bool) -> Void
    }
    
    struct RequestCancelNode: NodeProtocol {
        var next: UnsafeMutablePointer<RequestCancelNode>?
        var context: PromiseContext
        var callback: (Promise<T,E>.Resolver) -> Void
        
        func invoke(with resolver: Promise<T,E>.Resolver) {
            if case .immediate = context {
                // skip the state check
                callback(resolver)
            } else {
                context.execute(isSynchronous: false) { [callback] in
                    switch resolver._box.unfencedState {
                    case .delayed, .empty:
                        assertionFailure("We shouldn't be invoking an onRequestCancel callback on an empty promise")
                    case .cancelling, .cancelled:
                        callback(resolver)
                    case .resolving, .resolved:
                        // if the promise has been resolved, skip the cancel callback
                        break
                    }
                }
            }
        }
    }
    
    deinit {
        if var nodePtr = CallbackNode.castPointer(swapCallbackLinkedList(with: TWLLinkedListSwapFailed, linkBlock: nil)) {
            // If we actually have a callback list, we must not have been resolved, so inform our
            // callbacks that we've cancelled.
            // NB: No need to actually transition to the cancelled state first, if anyone still had
            // a reference to us to look at that, we wouldn't be in deinit.
            nodePtr = CallbackNode.reverseList(nodePtr)
            defer { CallbackNode.destroyPointer(nodePtr) }
            for nodePtr in sequence(first: nodePtr, next: { $0.pointee.next }) {
                nodePtr.pointee.callback(.cancelled, false)
            }
        }
        if let nodePtr = RequestCancelNode.castPointer(swapRequestCancelLinkedList(with: TWLLinkedListSwapFailed, linkBlock: nil)) {
            // NB: We can't fire these callbacks because they take a Resolver and we can't have them
            // resurrecting ourselves. We could work around this, but the only reason to even have
            // these callbacks at this point is if the promise handler drops the last reference to
            // the resolver, and since that means it's a buggy implementation, we don't need to
            // support it.
            RequestCancelNode.destroyPointer(nodePtr)
        }
        _value = nil // make sure this is destroyed after the fence
    }
    
    /// Returns the result of the promise.
    ///
    /// Once this value becomes non-`nil` it will never change.
    var result: PromiseResult<T,E>? {
        switch state {
        case .delayed, .empty, .resolving, .cancelling: return nil
        case .resolved:
            switch _value {
            case nil:
                assertionFailure("PromiseBox held nil value while in fulfilled state")
                return nil
            case .value(let value)?: return .value(value)
            case .error(let error)?: return .error(error)
            }
        case .cancelled:
            return .cancelled
        }
    }
    
    /// Requests that the promise be cancelled.
    ///
    /// If the promise has already been resolved or cancelled, or a cancel already requested, this
    /// does nothing.
    func requestCancel() {
        if transitionState(to: .cancelling) {
            if var nodePtr = RequestCancelNode.castPointer(swapRequestCancelLinkedList(with: TWLLinkedListSwapFailed, linkBlock: nil)) {
                nodePtr = RequestCancelNode.reverseList(nodePtr)
                defer { RequestCancelNode.destroyPointer(nodePtr) }
                let resolver = Promise<T,E>.Resolver(box: self)
                for nodePtr in sequence(first: nodePtr, next: { $0.pointee.next }) {
                    nodePtr.pointee.invoke(with: resolver)
                }
            }
        }
    }
    
    /// Resolves or cancels the promise.
    ///
    /// If the promise has already been resolved or cancelled, this does nothing.
    func resolveOrCancel(with result: PromiseResult<T,E>) {
        func handleCallbacks() {
            if let nodePtr = RequestCancelNode.castPointer(swapRequestCancelLinkedList(with: TWLLinkedListSwapFailed, linkBlock: nil)) {
                RequestCancelNode.destroyPointer(nodePtr)
            }
            if var nodePtr = CallbackNode.castPointer(swapCallbackLinkedList(with: TWLLinkedListSwapFailed, linkBlock: nil)) {
                nodePtr = CallbackNode.reverseList(nodePtr)
                defer { CallbackNode.destroyPointer(nodePtr) }
                for nodePtr in sequence(first: nodePtr, next: { $0.pointee.next }) {
                    nodePtr.pointee.callback(result, false)
                }
            }
        }
        let value: Value
        switch result {
        case .value(let x): value = .value(x)
        case .error(let err): value = .error(err)
        case .cancelled:
            if transitionState(to: .cancelled) {
                handleCallbacks()
            }
            return
        }
        guard transitionState(to: .resolving) else { return }
        _value = value
        if transitionState(to: .resolved) {
            handleCallbacks()
        } else {
            assertionFailure("Couldn't transition PromiseBox to .resolved after transitioning to .resolving")
        }
    }
    
    /// Propagates cancellation from a downstream Promise.
    ///
    /// This may result in the receiver being cancelled.
    ///
    /// - Precondition: Every call to `propagateCancel()` must be preceded with a call to
    ///   `seal.enqueue(willPropagateCancel: true, …)` first.
    func propagateCancel() {
        if decrementObserverCount() {
            requestCancel()
        }
    }
    
    /// Seals the box, if not already sealed.
    ///
    /// If there are no registered observers this does nothing. If there are registered observers
    /// and they've all propagated cancellation, we cancel immediately.
    func seal() {
        if sealObserverCount() {
            requestCancel()
        }
    }
    
    private typealias Value = PromiseBoxValue<T,E>
    
    /// The value of the box.
    ///
    /// - Important: It is not safe to access this without first checking `state`.
    private var _value: Value?
    
    override init() {
        _value = nil
        super.init(state: .empty)
    }
    
    /// Only for use by `DelayedPromiseBox`.
    init(delayed: ()) {
        _value = nil
        super.init(state: .delayed)
    }
    
    init(result: PromiseResult<T,E>) {
        switch result {
        case .value(let value):
            _value = .value(value)
            super.init(state: .resolved)
        case .error(let error):
            _value = .error(error)
            super.init(state: .resolved)
        case .cancelled:
            _value = nil
            super.init(state: .cancelled)
        }
    }
    
    override var description: String {
        let address = "0x\(String(UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque()), radix: 16))"
        func countNodes<Node: NodeProtocol>(_ ptr: UnsafeMutableRawPointer?, as _: Node.Type) -> String {
            guard let nodePtr = Node.castPointer(ptr) else { return "0 nodes" }
            let count = sequence(first: nodePtr, next: { $0.pointee.next }).reduce(0, { (x, _) in x + 1 })
            return "\(count) node\(count == 1 ? "" : "s")"
        }
        let callbackCount = countNodes(callbackList, as: CallbackNode.self)
        let requestCancelCount = countNodes(requestCancelLinkedList, as: RequestCancelNode.self)
        let flaggedCount = flaggedObserverCount
        let observerCount = flaggedCount & ~(3 << 62)
        let sealed = (flaggedCount & (1 << 63)) == 0
        return "<\(type(of: self)): \(address); state=\(unfencedState) callbackList=(\(callbackCount)) requestCancelList=(\(requestCancelCount)) observerCount=\(observerCount)\(sealed ? " sealed" : "")>"
    }
}

// Note: Subclass NSObject because we rely on the Obj-C runtime issuing a memory barrier before
// dealloc.
internal class PromiseSeal<T,E>: NSObject {
    let box: PromiseBox<T,E>
    
    override init() {
        box = PromiseBox()
    }
    
    init(result: PromiseResult<T,E>) {
        box = PromiseBox(result: result)
    }
    
    init(delayedBox: DelayedPromiseBox<T,E>) {
        box = delayedBox
    }
    
    deinit {
        box.seal()
    }
    
    /// Enqueues a callback onto the box's callback list.
    ///
    /// If the callback list has already been consumed, the callback is executed immediately.
    ///
    /// - Parameter value: A value that is wrapped in a oneshot block and passed to the callback.
    ///   Executing the block passed to the callback multiple times results in undefined behavior.
    ///
    /// - Parameter isSynchronous: `true` if the callback is being called synchronously before the
    ///   enqueue returns, otherwise `false`.
    ///
    /// - Note: The oneshot value should only be accessed inside the context being dispatched on.
    ///   The reason for this behavior is to ensure that any user-supplied data is released either
    ///   on the thread that registers the callback, or on the context itself, and is not released
    ///   on whatever thread the receiver happens to be resolved on. We only make this guarantee in
    ///   the case where the callback is invoked (ignoring tokens).
    func enqueue<Value>(willPropagateCancel: Bool = true, makeOneshot value: Value, callback: @escaping (PromiseResult<T,E>, _ oneshot: @escaping () -> Value, _ isSynchronous: Bool) -> Void) {
        var value = Optional.some(value)
        let oneshot: () -> Value = {
            defer { value = nil }
            return value.unsafelyUnwrapped
        }
        _enqueue(willPropagateCancel: willPropagateCancel) { (result, isSynchronous) in
            callback(result, oneshot, isSynchronous)
        }
    }
    
    /// Enqueues a callback onto the box's callback list.
    ///
    /// If the callback list has already been consumed, the callback is executed immediately.
    ///
    /// - Parameter isSynchronous: `true` if the callback is being called synchronously before the
    ///   enqueue returns, otherwise `false`.
    ///
    /// - Important: This function should only be called if there's no user-supplied callback
    ///   involved that should be turned into a oneshot.
    func _enqueue(willPropagateCancel: Bool = true, callback: @escaping (_ value: PromiseResult<T,E>, _ isSynchronous: Bool) -> Void) {
        if willPropagateCancel {
            // If the subsequent swap fails, that means we've already resolved (or started
            // resolving) the promise, so the observer count modification is harmless.
            box.incrementObserverCount()
        }
        
        let nodePtr = UnsafeMutablePointer<PromiseBox<T,E>.CallbackNode>.allocate(capacity: 1)
        nodePtr.initialize(to: .init(next: nil, callback: callback))
        if box.swapCallbackLinkedList(with: UnsafeMutableRawPointer(nodePtr), linkBlock: { (nextPtr) in
            let next = nextPtr?.assumingMemoryBound(to: PromiseBox<T,E>.CallbackNode.self)
            nodePtr.pointee.next = next
        }) == TWLLinkedListSwapFailed {
            nodePtr.deinitialize(count: 1)
            nodePtr.deallocate()
            guard let result = box.result else {
                fatalError("Callback list empty but state isn't actually resolved")
            }
            callback(result, true)
        }
    }
}

private protocol NodeProtocol {
    var next: UnsafeMutablePointer<Self>? { get set }
}

private extension NodeProtocol {
    static func castPointer(_ pointer: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<Self>? {
        guard let pointer = pointer, pointer != TWLLinkedListSwapFailed else { return nil }
        return pointer.assumingMemoryBound(to: self)
    }
    
    /// Destroys the linked list.
    ///
    /// - Precondition: The pointer must be initialized.
    /// - Postcondition: The pointer is deallocated.
    static func destroyPointer(_ pointer: UnsafeMutablePointer<Self>) {
        var nextPointer = pointer.pointee.next
        pointer.deinitialize(count: 1)
        pointer.deallocate()
        while let current = nextPointer {
            nextPointer = current.pointee.next
            current.deinitialize(count: 1)
            current.deallocate()
        }
    }
    
    static func reverseList(_ pointer: UnsafeMutablePointer<Self>) -> UnsafeMutablePointer<Self> {
        var nextPointer = replace(&pointer.pointee.next, with: nil)
        var previous = pointer
        while let next = nextPointer {
            nextPointer = replace(&next.pointee.next, with: previous)
            previous = next
        }
        return previous
    }
}

private enum PromiseBoxValue<T,E> {
    case value(T)
    case error(E)
}

/// :nodoc:
extension TWLPromiseBoxState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .delayed: return "delayed"
        case .empty: return "empty"
        case .resolving: return "resolving"
        case .resolved: return "resolved"
        case .cancelling: return "cancelling"
        case .cancelled: return "cancelled"
        }
    }
}

private func replace<T>(_ slot: inout T, with value: T) -> T {
    var value = value
    swap(&slot, &value)
    return value
}
