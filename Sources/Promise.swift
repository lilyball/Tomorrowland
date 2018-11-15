//
//  Promise.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 12/12/17.
//  Copyright © 2017 Lily Ballard. All rights reserved.
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
    
    /// Returns `.main` when accessed from the main thread, otherwise `.default`.
    public static var auto: PromiseContext {
        if Thread.isMainThread {
            return .main
        } else {
            return .default
        }
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
        }
    }
    
    public var hashValue: Int {
        switch self {
        case .main: return 0
        case .background: return 1
        case .utility: return 2
        case .default: return 3
        case .userInitiated: return 4
        case .userInteractive: return 5
        case .immediate: return 6
        case .queue(let queue):
            return queue.hashValue << 3
        case .operationQueue(let queue):
            return queue.hashValue << 3 | 1
        }
    }
    
    internal func execute(_ f: @escaping @convention(block) () -> Void) {
        switch self {
        case .main:
            if TWLGetMainContextThreadLocalFlag() {
                assert(Thread.isMainThread, "Found thread-local flag set while not executing on the main thread")
                // We're already executing on the .main context
                TWLEnqueueThreadLocalBlock(f)
            } else {
                DispatchQueue.main.async {
                    TWLExecuteBlockWithMainContextThreadLocalFlag {
                        f()
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
            f()
        }
    }
    
    /// Returns the `DispatchQueue` corresponding to the context, if any. If the context is
    /// `.immediate`, it behaves like `.auto`.
    internal func getQueue() -> DispatchQueue? {
        switch self {
        case .main: return .main
        case .background: return .global(qos: .background)
        case .utility: return .global(qos: .utility)
        case .default: return .global(qos: .default)
        case .userInitiated: return .global(qos: .userInitiated)
        case .userInteractive: return .global(qos: .userInteractive)
        case .queue(let queue): return queue
        case .operationQueue: return nil
        case .immediate: return PromiseContext.auto.getQueue()
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
            switch result {
            case .value(let value): fulfill(with: value)
            case .error(let error): reject(with: error)
            case .cancelled: cancel()
            }
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
                    context.execute {
                        callback(self)
                    }
                case .delayed, .empty, .resolving, .resolved:
                    break
                }
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
        context.execute {
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
    public init(result: PromiseResult<Value,Error>) {
        _seal = PromiseSeal(result: result)
    }
    
    // MARK: -
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be fulfilled with the return value of `onSuccess`. If the
    ///   receiver is rejected or cancelled, the returned promise will also be rejected or
    ///   cancelled.
    public func then<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) -> U) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                context.execute {
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
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`. If the receiver is rejected or cancelled, the returned promise will also be
    ///   rejected or cancelled.
    public func then<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) -> Promise<U,Error>) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                context.execute {
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
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute {
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
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be fulfilled with the return value of `onError`. If the
    ///   receiver is fulfilled or cancelled, the returned promise will also be fulfilled or
    ///   cancelled.
    public func recover(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Value) -> Promise<Value,NoError> {
        let (promise, resolver) = Promise<Value,NoError>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute {
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
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   rejected and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`. If the receiver is fulfilled or cancelled, the returned promise will also be
    ///   fulfilled or cancelled.
    public func recover<E>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Promise<Value,E>) -> Promise<Value,E> {
        let (promise, resolver) = Promise<Value,E>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute {
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
        _seal.enqueue { [generation=token?.generation] (result) in
            context.execute {
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
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the same value that the promise returned by
    ///   `onComplete` does.
    public func always<T,E>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Promise<T,E>) -> Promise<T,E> {
        let (promise, resolver) = Promise<T,E>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            context.execute {
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
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the same value that the promise returned by
    ///   `onComplete` does, or is rejected if `onComplete` throws an error.
    public func tryAlways<T,E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,E>) -> Promise<T,Swift.Error> {
        let (promise, resolver) = Promise<T,Swift.Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            context.execute {
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
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked and will cause
    ///   the returned `Promise` to be cancelled.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new `Promise` that adopts the same value that the promise returned by
    ///   `onComplete` does, or is rejected if `onComplete` throws an error.
    public func tryAlways<T>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,Swift.Error>) -> Promise<T,Swift.Error> {
        let (promise, resolver) = Promise<T,Swift.Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            context.execute {
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
    ///   `then(on:token:_:)`, `catch(on:token:_:)`, or `always(on:token:_:)` instead.
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
        _seal.enqueue(willPropagateCancel: false) { [generation=token?.generation] (result) in
            context.execute {
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
    ///   `then(on:token:_:)`, `catch(on:token:_:)`, or `always(on:token:_:)` instead.
    ///
    /// - Returns: A new `Promise` that adopts the same result as the receiver. Requesting this new
    ///   promise to cancel does nothing.
    ///
    /// - SeeAlso: `tap(on:token:_:)`, `ignoringCancel()`
    public func tap() -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _seal.enqueue(willPropagateCancel: false) { (result) in
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
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                resolver.reject(with: error)
            case .cancelled:
                context.execute {
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
    ///         .tryThen(on: .utility, { try JSONDecoder().decode(Model.self, from: $0.data) })
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
        _seal.enqueue { (result) in
            resolver.resolve(with: result)
        }
        return promise
    }
    
    private func pipe(to resolver: Promise<Value,Error>.Resolver) {
        _seal.enqueue { (result) in
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
        pipe(to: resolver)
        return promise
    }
    
    private func pipe(to resolver: Promise<Value,Swift.Error>.Resolver) {
        _seal.enqueue { (result) in
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
        _seal.enqueue { (result) in
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
        context.execute {
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
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be fulfilled with the return value of `onSuccess`, or
    ///   rejected if `onSuccess` throws an error. If the receiver is rejected or cancelled, the
    ///   returned promise will also be rejected or cancelled.
    public func tryThen<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> U) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                context.execute {
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
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`, or rejected if `onSuccess` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    public func tryThen<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Promise<U,Error>) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                context.execute {
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
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onSuccess` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`, or rejected if `onSuccess` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    public func tryThen<U,E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Promise<U,E>) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                context.execute {
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
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be fulfilled with the return value of `onError`, or
    ///   rejected if `onError` throws an error. If the receiver is rejected or cancelled, the
    ///   returned promise will also be rejected or cancelled.
    public func tryRecover(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Value) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute {
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
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`, or rejected if `onError` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    public func tryRecover(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Promise<Value,Error>) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute {
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
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`, or rejected if `onError` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    public func tryRecover<E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Promise<Value,E>) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _seal.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
            case .error(let error):
                context.execute {
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

extension PromiseResult where Value: Equatable, Error: Equatable {
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
#if swift(>=4.1)
    extension PromiseResult: Equatable where Value: Equatable, Error: Equatable {}
#else
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public func ==<T,E>(lhs: PromiseResult<T,E>?, rhs: PromiseResult<T,E>?) -> Bool
        where T: Equatable, E: Equatable
    {
        switch (lhs, rhs) {
        case let (a?, b?): return a == b
        case (nil, _?), (_?, nil): return false
        case (nil, nil): return true
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
    public func !=<T,E>(lhs: PromiseResult<T,E>?, rhs: PromiseResult<T,E>?) -> Bool
        where T: Equatable, E: Equatable
    {
        return !(lhs == rhs)
    }
#endif

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
    private weak var cancellable: TWLCancellable?
    
    fileprivate init(_ cancellable: TWLCancellable) {
        self.cancellable = cancellable
    }
    
    /// Requests cancellation of the promise this `PromiseCancellable` was created from.
    func requestCancel() {
        cancellable?.requestCancel()
    }
}

extension PromiseResult where Value: Hashable, Error: Hashable {
    public var hashValue: Int {
        switch self {
        case .value(let value):
            return value.hashValue << 2
        case .error(let error):
            return error.hashValue << 2 | 0x1
        case .cancelled:
            return 0x2
        }
    }
}
#if swift(>=4.1)
extension PromiseResult: Hashable where Value: Hashable, Error: Hashable {}

extension PromiseResult {
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
#endif

// MARK: -

/// An invalidation token that can be used to cancel callbacks registered to a `Promise`.
public struct PromiseInvalidationToken {
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
    /// `then(on:token:_:)`) will result in a cancelled promise instead if the callback would
    /// otherwise have been executed.
    ///
    /// In addition, any promises that have been registered with `requestCancelOnInvalidate(_:)`
    /// will be requested to cancel.
    public func invalidate() {
        _inner.box.invalidate()
    }
    
    /// Cancels any associated promises without invalidating the token.
    ///
    /// After invoking this method, any promises that have been registered with
    /// `requestCancelOnInvalidate(_:)` will be requested to cancel.
    public func cancelWithoutInvalidating() {
        _inner.box.cancelWithoutInvalidating()
    }
    
    /// Registers a `Promise` to be requested to cancel automatically when the token is invalidated.
    public func requestCancelOnInvalidate<V,E>(_ promise: Promise<V,E>) {
        _inner.box.requestCancelOnInvalidate(promise.cancellable)
    }
    
    /// Registers an `ObjCPromise` to be requested to cancel automatically when the token is
    /// invalidated.
    public func requestCancelOnInvalidate<V,E>(_ promise: ObjCPromise<V,E>) {
        _inner.box.requestCancelOnInvalidate(PromiseCancellable(promise.cancellable))
    }
    
    internal var generation: UInt {
        return _inner.box.generation
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
    
    public var hashValue: Int {
        return ObjectIdentifier(_inner).hashValue
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
        return true
    }
    
    public var hashValue: Int {
        return 0
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError()
    }
}

// See SR-2729
/// :nodoc:
protocol _NoErrorDecodableWorkaround : Decodable {}
/// :nodoc:
extension _NoErrorDecodableWorkaround {
    public init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Tomorrowland.NoError does not support decoding."))
    }
}
extension NoError: _NoErrorDecodableWorkaround {}

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
    
    deinit {
        if let nodePtr = CallbackNode.castPointer(callbackLinkedList) {
            CallbackNode.destroyPointer(nodePtr)
        }
    }
    
    func invalidate() {
        resetCallbacks(andIncrementGenerationBy: 1)
    }
    
    func cancelWithoutInvalidating() {
        resetCallbacks(andIncrementGenerationBy: 0)
    }
    
    func requestCancelOnInvalidate(_ cancellable: PromiseCancellable) {
        let nodePtr = UnsafeMutablePointer<CallbackNode>.allocate(capacity: 1)
        nodePtr.initialize(to: .init(next: nil, generation: 0, cancellable: cancellable))
        pushNodeOntoCallbackLinkedList(nodePtr) { (rawPtr) in
            if let nextPtr = CallbackNode.castPointer(rawPtr) {
                nodePtr.pointee.generation = nextPtr.pointee.generation
                nodePtr.pointee.next = nextPtr
            } else {
                nodePtr.pointee.generation = CallbackNode.interpretTaggedInteger(rawPtr)
                nodePtr.pointee.next = nil
            }
        }
    }
    
    internal var generation: UInt {
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
        return "<\(type(of: self)): \(address); generation=\(generation) callbackLinkedList=(\(callbackCount))>"
    }
}

internal class PromiseBox<T,E>: TWLPromiseBox, TWLCancellable {
    struct CallbackNode: NodeProtocol {
        var next: UnsafeMutablePointer<CallbackNode>?
        var callback: (PromiseResult<T,E>) -> Void
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
                context.execute { [callback] in
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
                nodePtr.pointee.callback(.cancelled)
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
                    nodePtr.pointee.callback(result)
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
    func enqueue(willPropagateCancel: Bool = true, callback: @escaping (PromiseResult<T,E>) -> Void) {
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
            callback(result)
        }
    }
}

private protocol NodeProtocol {
    var next: UnsafeMutablePointer<Self>? { get set }
}

extension NodeProtocol {
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
