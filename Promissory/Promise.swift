//
//  Promise.swift
//  Promissory
//
//  Created by Kevin Ballard on 12/12/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import Promissory.Private
import Dispatch

/// The context in which a Promise body or callback is evaluated.
///
/// Most of these values correspond with Dispatch QoS classes.
public enum PromiseContext {
    /// Execute on the main queue.
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
    /// - Important: This is rarely what you want and great care should be taken when using it.
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
    
    internal func execute(_ f: @escaping @convention(block) () -> Void) {
        switch self {
        case .main:
            DispatchQueue.main.async(execute: f)
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
}

/// A `Promise` is a construct that will eventually hold a value or error, and can invoke callbacks
/// when that happens.
///
/// Example usage:
///
///     Promise(on: .utility) { resolver in
///         let value = try someLongComputation()
///         resolver.fulfill(value)
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
    public struct Resolver {
        fileprivate let _box: PromiseBox<Value,Error>
        
        fileprivate init(box: PromiseBox<Value,Error>) {
            _box = box
        }
        
        /// Fulfills the promise with the given value.
        ///
        /// If the promise has already been resolved or cancelled, this does nothing.
        public func fulfill(_ value: Value) {
            _box.resolveOrCancel(with: .value(value))
        }
        
        /// Rejects the promise with the given error.
        ///
        /// If the promise has already been resolved or cancelled, this does nothing.
        public func reject(_ error: Error) {
            _box.resolveOrCancel(with: .error(error))
        }
        
        /// Cancels the promise.
        ///
        /// If the promise has already been resolved or cancelled, this does nothing.
        public func cancel() {
            _box.resolveOrCancel(with: .cancelled)
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
            }) == PMSLinkedListSwapFailed {
                nodePtr.deinitialize()
                nodePtr.deallocate(capacity: 1)
                switch _box.unfencedState {
                case .cancelling, .cancelled:
                    context.execute {
                        callback(self)
                    }
                case .empty, .resolving, .resolved:
                    break
                }
            }
        }
    }
    
    /// Returns the result of the promise.
    ///
    /// Once this value becomes non-`nil` it will never change.
    public var result: PromiseResult<Value,Error>? {
        return _box.result
    }
    
    private let _box: PromiseBox<Value,Error>
    
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
        _box = PromiseBox()
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
        _box = PromiseBox()
    }
    
    /// Returns a `Promise` that is already fulfilled with the given value.
    public init(fulfilled value: Value) {
        _box = PromiseBox(result: .value(value))
    }
    
    /// Returns a `Promise` that is already rejected with the given error.
    public init(rejected error: Error) {
        _box = PromiseBox(result: .error(error))
    }
    
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
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    resolver.fulfill(onSuccess(value))
                case .error(let error):
                    resolver.reject(error)
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
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
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    let nextPromise = onSuccess(value)
                    nextPromise.pipe(to: resolver)
                case .error(let error):
                    resolver.reject(error)
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
        return promise
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// This method (or `always`) should be used to terminate a promise chain.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onError` from being invoked. If the promise is
    ///   fulfilled and the token is invalidated, the returned promise will be cancelled.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    public func `catch`(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Void) {
        _box.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value, .cancelled: break
            case .error(let error):
                guard generation == token?.generation else { return }
                context.execute {
                    onError(error)
                }
            }
        }
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
    /// - Returns: A new promise that will be fulfilled with the return value of `onError`. If the
    ///   receiver is rejected or cancelled, the returned promise will also be rejected or
    ///   cancelled.
    public func recover(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Value) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    resolver.fulfill(value)
                case .error(let error):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    resolver.fulfill(onError(error))
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
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
    ///   `onError`. If the receiver is rejected or cancelled, the returned promise will also be
    ///   rejected or cancelled.
    public func recover<E>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Promise<Value,E>) -> Promise<Value,E> {
        let (promise, resolver) = Promise<Value,E>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    resolver.fulfill(value)
                case .error(let error):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    let nextPromise = onError(error)
                    nextPromise.pipe(to: resolver)
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
        return promise
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter token: An optional `PromiseInvalidatonToken`. If provided, calling
    ///   `invalidate()` on the token will prevent `onComplete` from being invoked.
    /// - Parameter onComplete: The callback that is invoked with the promise's value.
    /// - Returns: The same promise this method was invoked on.
    @discardableResult
    public func always(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) -> Promise<Value,Error> {
        _box.enqueue { [generation=token?.generation] (result) in
            guard generation == token?.generation else { return }
            context.execute {
                onComplete(result)
            }
        }
        return self
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
        _box.enqueue { [generation=token?.generation] (result) in
            guard generation == token?.generation else {
                resolver.cancel()
                return
            }
            let nextPromise = onComplete(result)
            nextPromise.pipe(to: resolver)
        }
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
    public func always<T,E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,E>) -> Promise<T,Swift.Error> {
        let (promise, resolver) = Promise<T,Swift.Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            guard generation == token?.generation else {
                resolver.cancel()
                return
            }
            do {
                let nextPromise = try onComplete(result)
                nextPromise.pipe(to: resolver)
            } catch {
                resolver.reject(error)
            }
        }
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
    public func always<T>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,Swift.Error>) -> Promise<T,Swift.Error> {
        let (promise, resolver) = Promise<T,Swift.Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            guard generation == token?.generation else {
                resolver.cancel()
                return
            }
            do {
                let nextPromise = try onComplete(result)
                nextPromise.pipe(to: resolver)
            } catch {
                resolver.reject(error)
            }
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
    /// - Returns: The same promise this method was invoked on.
    public func onCancel(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onCancel: @escaping () -> Void) {
        _box.enqueue { [generation=token?.generation] (result) in
            switch result {
            case .value, .error: break
            case .cancelled:
                guard generation == token?.generation else { return }
                context.execute(onCancel)
            }
        }
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
    
    private func pipe(to resolver: Promise<Value,Error>.Resolver) {
        _box.enqueue { (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(value)
            case .error(let error):
                resolver.reject(error)
            case .cancelled:
                resolver.cancel()
            }
        }
    }
}

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
        _box.enqueue { (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(value)
            case .error(let error):
                resolver.reject(error)
            case .cancelled:
                resolver.cancel()
            }
        }
    }
}

extension Promise where Error == Swift.Error {
    /// Returns a new `Promise` that will be resolved using the given block.
    ///
    /// - Parameter context: The context to execute the handler on.
    /// - Parameter handler: A block that is executed in order to fulfill the promise. If the block
    ///   throws an error the promise will be rejected (unless it was already resolved first).
    /// - Parameter resolver: The `Resolver` used to resolve the promise.
    public init(on context: PromiseContext, _ handler: @escaping (_ resolver: Resolver) throws -> Void) {
        _box = PromiseBox()
        let resolver = Resolver(box: _box)
        context.execute {
            do {
                try handler(resolver)
            } catch {
                resolver.reject(error)
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
    public func then<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> U) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    do {
                        resolver.fulfill(try onSuccess(value))
                    } catch {
                        resolver.reject(error)
                    }
                case .error(let error):
                    resolver.reject(error)
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
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
    public func then<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Promise<U,Error>) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    do {
                        let nextPromise = try onSuccess(value)
                        nextPromise.pipe(to: resolver)
                    } catch {
                        resolver.reject(error)
                    }
                case .error(let error):
                    resolver.reject(error)
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
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
    public func then<U,E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Promise<U,E>) -> Promise<U,Error> {
        let (promise, resolver) = Promise<U,Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    do {
                        let nextPromise = try onSuccess(value)
                        nextPromise.pipe(to: resolver)
                    } catch {
                        resolver.reject(error)
                    }
                case .error(let error):
                    resolver.reject(error)
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
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
    public func recover(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Value) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    resolver.fulfill(value)
                case .error(let error):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    do {
                        resolver.fulfill(try onError(error))
                    } catch {
                        resolver.reject(error)
                    }
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
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
    public func recover(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Promise<Value,Error>) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    resolver.fulfill(value)
                case .error(let error):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    do {
                        let nextPromise = try onError(error)
                        nextPromise.pipe(to: resolver)
                    } catch {
                        resolver.reject(error)
                    }
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
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
    public func recover<E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Promise<Value,E>) -> Promise<Value,Error> {
        let (promise, resolver) = Promise<Value,Error>.makeWithResolver()
        _box.enqueue { [generation=token?.generation] (result) in
            context.execute {
                switch result {
                case .value(let value):
                    resolver.fulfill(value)
                case .error(let error):
                    guard generation == token?.generation else {
                        resolver.cancel()
                        break
                    }
                    do {
                        let nextPromise = try onError(error)
                        nextPromise.pipe(to: resolver)
                    } catch {
                        resolver.reject(error)
                    }
                case .cancelled:
                    resolver.cancel()
                }
            }
        }
        return promise
    }
}

extension Promise: Equatable {
    /// Two `Promsie`s compare as equal if they represent the same promise.
    ///
    /// Two distinct `Promise`s that are resolved to the same value compare as unequal.
    public static func ==(lhs: Promise, rhs: Promise) -> Bool {
        return lhs._box === rhs._box
    }
}

/// The result of a resolved promise.
public enum PromiseResult<Value,Error> {
    /// The value the promise was fulfilled with.
    case value(Value)
    /// The error the promise was rejected with.
    case error(Error)
    /// The promise was cancelled.
    case cancelled
}

extension PromiseResult where Value: Equatable, Error: Equatable {
    public static func ==(lhs: PromiseResult, rhs: PromiseResult) -> Bool {
        switch (lhs, rhs) {
        case let (.value(a), .value(b)) where a == b: return true
        case let (.error(a), .error(b)) where a == b: return true
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
    
    public static func !=(lhs: PromiseResult, rhs: PromiseResult) -> Bool {
        return !(lhs == rhs)
    }
}
#if swift(>=4.1)
    extension PromiseResult: Equatable where Value: Equatable, Error: Equatable {}
#else
    public func ==<T,E>(lhs: PromiseResult<T,E>?, rhs: PromiseResult<T,E>?) -> Bool
        where T: Equatable, E: Equatable
    {
        switch (lhs, rhs) {
        case let (a?, b?): return a == b
        case (nil, _?), (_?, nil): return false
        case (nil, nil): return true
        }
    }
    
    public func !=<T,E>(lhs: PromiseResult<T,E>?, rhs: PromiseResult<T,E>?) -> Bool
        where T: Equatable, E: Equatable
    {
        return !(lhs == rhs)
    }
#endif

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
#endif

// FIXME: (Swift 4.1) Implement Codable if Value and Error conform to it

/// An invalidation token that can be used to cancel callbacks registered to a `Promise`.
public struct PromiseInvalidationToken {
    private let _box = PMSPromiseInvalidationTokenBox()
    
    public init() {}
    
    /// After invoking this method, all `Promise` callbacks registered with this token will be
    /// suppressed. Any callbacks whose return value is used for a subsequent promise (e.g. with
    /// `then(on:token:_:)` will result in a cancelled promise instead if the callback would otherwise
    /// have been executed.
    public func invalidate() {
        _box.incrementGeneration()
    }
    
    internal var generation: UInt64 {
        return _box.generation
    }
}

// MARK: -

private class PromiseBox<T,E>: PMSPromiseBox {
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
                    case .empty:
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
        issueDeinitFence()
        if var nodePtr = CallbackNode.castPointer(swapCallbackLinkedList(with: PMSLinkedListSwapFailed, linkBlock: nil)) {
            // If we actually have a callback list, we must not have been resolved, so attempt to cancel.
            // NB: No need to actually transition to the cancelled state first, if anyone still had
            // a reference to us to look at that, we wouldn't be in deinit.
            nodePtr = CallbackNode.reverseList(nodePtr)
            defer { CallbackNode.destroyPointer(nodePtr) }
            for nodePtr in sequence(first: nodePtr, next: { $0.pointee.next }) {
                nodePtr.pointee.callback(.cancelled)
            }
        }
        if let nodePtr = RequestCancelNode.castPointer(swapRequestCancelLinkedList(with: PMSLinkedListSwapFailed, linkBlock: nil)) {
            RequestCancelNode.destroyPointer(nodePtr)
        }
        _value = nil // make sure this is destroyed after the fence
    }
    
    /// Returns the result of the promise.
    ///
    /// Once this value becomes non-`nil` it will never change.
    var result: PromiseResult<T,E>? {
        switch state {
        case .empty, .resolving, .cancelling: return nil
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
            if var nodePtr = RequestCancelNode.castPointer(swapRequestCancelLinkedList(with: PMSLinkedListSwapFailed, linkBlock: nil)) {
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
            if let nodePtr = RequestCancelNode.castPointer(swapRequestCancelLinkedList(with: PMSLinkedListSwapFailed, linkBlock: nil)) {
                RequestCancelNode.destroyPointer(nodePtr)
            }
            if var nodePtr = CallbackNode.castPointer(swapCallbackLinkedList(with: PMSLinkedListSwapFailed, linkBlock: nil)) {
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
    
    /// Enqueues a callback onto the callback list.
    ///
    /// If the callback list has already been consumed, the callback is executed immediately.
    func enqueue(callback: @escaping (PromiseResult<T,E>) -> Void) {
        let nodePtr = UnsafeMutablePointer<PromiseBox<T,E>.CallbackNode>.allocate(capacity: 1)
        nodePtr.initialize(to: .init(next: nil, callback: callback))
        if swapCallbackLinkedList(with: UnsafeMutableRawPointer(nodePtr), linkBlock: { (nextPtr) in
            nodePtr.pointee.next = nextPtr?.assumingMemoryBound(to: PromiseBox<T,E>.CallbackNode.self)
        }) == PMSLinkedListSwapFailed {
            nodePtr.deinitialize()
            nodePtr.deallocate(capacity: 1)
            guard let result = result else {
                fatalError("Callback list empty but state isn't actually resolved")
            }
            callback(result)
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
}

private protocol NodeProtocol {
    var next: UnsafeMutablePointer<Self>? { get set }
}

extension NodeProtocol {
    static func castPointer(_ pointer: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<Self>? {
        guard let pointer = pointer, pointer != PMSLinkedListSwapFailed else { return nil }
        return pointer.assumingMemoryBound(to: self)
    }
    
    /// Destroys the linked list.
    ///
    /// - Precondition: The pointer must be initialized.
    /// - Postcondition: The pointer points to deinitialized memory.
    static func destroyPointer(_ pointer: UnsafeMutablePointer<Self>) {
        var nextPointer = pointer.pointee.next
        pointer.deinitialize()
        while let next = nextPointer {
            nextPointer = next.pointee.next
            next.deinitialize()
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

private func replace<T>(_ slot: inout T, with value: T) -> T {
    var value = value
    swap(&slot, &value)
    return value
}
