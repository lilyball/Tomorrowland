//
//  TokenPromise.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 5/13/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

extension Promise {
    /// Returns a new `TokenPromise` that wraps the receiver.
    ///
    /// A `TokenPromise` is an adapter that allows you to call methods on the wrapped `Promise`
    /// while automatically applying the given `PromiseInvalidationToken`.
    ///
    /// - Important: `TokenPromise` automatically cancels any returned child `Promise`s when the
    ///   `PromiseInvalidationToken` is invalidated. If you do not want child `Promise`s to be
    ///   cancelled, pass the token to the `Promise` methods manually instead of using
    ///   `.withToken(_:)`. See `TokenPromise` for details.
    ///
    /// - Parameter token: The `PromiseInvalidationToken` to use when calling methods on the
    ///   receiver using the returned `TokenPromise`.
    /// - Returns: A `TokenPromise`.
    public func withToken(_ token: PromiseInvalidationToken) -> TokenPromise<Value,Error> {
        return TokenPromise(promise: self, token: token)
    }
}

/// A `Promise` adapter that automatically applies a `PromiseInvalidationToken`.
///
/// This exposes the same methods as `Promise` but it always passes a given
/// `PromiseInvalidationToken` to the underlying promise.
///
/// - Important: `TokenPromise` automatically cancels any returned child `Promise`s when the
///   `PromiseInvalidationToken` is invalidated. The only exception is `Promise`s returned from
///   `tap()` or `tap(on:_:)`, as these methods do not propagate cancellation.
///
/// A `TokenPromise` is created with the method `Promise.withToken(_:)`. The wrapped `Promise` can
/// be accessed with the `.inner` property.
///
/// ### Example
///
///     methodReturningPromise()
///         .withToken(promiseToken)
///         .then({ (value) in
///             // handle value
///         }).catch({ (error) in
///             // handle error
///         })
public struct TokenPromise<Value,Error> {
    /// The wrapped `Promise`.
    public let inner: Promise<Value,Error>
    
    /// The `PromiseInvalidationToken` to use when invoking methods on the wrapped `Promise`.
    public let token: PromiseInvalidationToken
    
    /// Returns a new `TokenPromise` that wraps the given promise.
    ///
    /// - Parameter promise: The `Promise` to wrap.
    /// - Parameter token: The `PromiseInvalidationToken` to use when invoking methods on the
    ///   `promise`.
    public init(promise: Promise<Value,Error>, token: PromiseInvalidationToken) {
        self.init(promise: promise, token: token, initial: true)
    }
    
    // MARK: Private
    
    /// This controls whether we request cancellation on child `Promise`s. Because cancellation is
    /// only ever handled at the root of a promise chain, requesting cancellation on every promise
    /// in the chain is wasteful. We use this property to ensure we only request cancellation on the
    /// immediate children, but not any grandchildren.
    private let initial: Bool
    
    private init(promise: Promise<Value,Error>, token: PromiseInvalidationToken, initial: Bool) {
        self.inner = promise
        self.token = token
        self.initial = initial
    }
    
    private func wrap<V,E>(_ promise: Promise<V,E>) -> TokenPromise<V,E> {
        if initial {
            token.requestCancelOnInvalidate(promise)
        }
        return TokenPromise<V,E>(promise: promise, token: token, initial: false)
    }
}

extension TokenPromise {
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will resolve to the same value as the receiver. You may safely
    ///   ignore this value.
    ///
    /// - SeeAlso: `Promise.then(on:token:_:)`.
    public func then(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) -> Void) -> TokenPromise<Value,Error> {
        return wrap(inner.then(on: context, token: token, onSuccess))
    }
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be fulfilled with the return value of `onSuccess`. If the
    ///   receiver is rejected or cancelled, the returned promise will also be rejected or
    ///   cancelled.
    ///
    /// - SeeAlso: `Promise.map(on:token:_:)`.
    public func map<U>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) -> U) -> TokenPromise<U,Error> {
        return wrap(inner.map(on: context, token: token, onSuccess))
    }
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`. If the receiver is rejected or cancelled, the returned promise will also be
    ///   rejected or cancelled.
    ///
    /// - SeeAlso: `Promise.flatMap(on:token:_:)`.
    public func flatMap<U>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) -> Promise<U,Error>) -> TokenPromise<U,Error> {
        return wrap(inner.flatMap(on: context, token: token, onSuccess))
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// This method (or `always`) should be used to terminate a promise chain.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will resolve to the same value as the receiver. You may safely
    ///   ignore this value.
    ///
    /// - SeeAlso: `Promise.catch(on:token:_:)`
    @discardableResult
    public func `catch`(on context: PromiseContext = .auto, _ onError: @escaping (Error) -> Void) -> TokenPromise<Value,Error> {
        return wrap(inner.catch(on: context, token: token, onError))
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be fulfilled with the return value of `onError`. If the
    ///   receiver is fulfilled or cancelled, the returned promise will also be fulfilled or
    ///   cancelled.
    ///
    /// - SeeAlso: `Promise.recover(on:token:_:)`.
    public func recover(on context: PromiseContext = .auto, _ onError: @escaping (Error) -> Value) -> TokenPromise<Value,NoError> {
        return wrap(inner.recover(on: context, token: token, onError))
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be rejected with the return value of `onError`. If the
    ///   receiver is fulfilled or cancelled, the returned promise will also be fulfilled or
    ///   cancelled.
    ///
    /// - SeeAlso: `Promise.mapError(on:token:_:)`.
    public func mapError<E>(on context: PromiseContext = .auto, _ onError: @escaping (Error) -> E) -> TokenPromise<Value,E> {
        return wrap(inner.mapError(on: context, onError))
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`. If the receiver is fulfilled or cancelled, the returned promise will also be
    ///   fulfilled or cancelled.
    ///
    /// - SeeAlso: `Promise.flatMapError(on:token:_:)`.
    public func flatMapError<E>(on context: PromiseContext = .auto, _ onError: @escaping (Error) -> Promise<Value,E>) -> TokenPromise<Value,E> {
        return wrap(inner.flatMapError(on: context, token: token, onError))
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be rejected with the return value of `onError`, or is
    ///   rejected if `onError` throws an error. If the receiver is fulfilled or cancelled, the
    ///   returned promise will also be fulfilled or cancelled.
    public func tryMapError<E: Swift.Error>(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> E) -> TokenPromise<Value,Swift.Error> {
        return wrap(inner.tryMapError(on: context, token: token, onError))
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`, or is rejected if `onError` throws an error. If the receiver is fulfilled or
    ///   cancelled, the returned promise will also be fulfilled or cancelled.
    public func tryFlatMapError<E: Swift.Error>(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> Promise<Value,E>) -> TokenPromise<Value,Swift.Error> {
        return wrap(inner.tryFlatMapError(on: context, token: token, onError))
    }
    
    #if !compiler(>=5) // Swift 5 compiler makes the Swift.Error existential conform to itself
    /// Registers a callback that is invoked when the promise is rejected.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be rejected with the return value of `onError`, or is
    ///   rejected if `onError` throws an error. If the receiver is fulfilled or cancelled, the
    ///   returned promise will also be fulfilled or cancelled.
    public func tryMapError(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> Swift.Error) -> TokenPromise<Value,Swift.Error> {
        return wrap(inner.tryMapError(on: context, token: token, onError))
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`, or is rejected if `onError` throws an error. If the receiver is fulfilled or
    ///   cancelled, the returned promise will also be fulfilled or cancelled.
    public func tryFlatMapError(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> Promise<Value,Swift.Error>) -> TokenPromise<Value,Swift.Error> {
        return wrap(inner.tryFlatMapError(on: context, token: token, onError))
    }
    #endif
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onComplete: The callback that is invoked with the promise's value.
    /// - Returns: A new promise that will resolve to the same value as the receiver. You may safely
    ///   ignore this value.
    ///
    /// - SeeAlso: `Promise.always(on:token:_:)`
    @discardableResult
    public func always(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) -> TokenPromise<Value,Error> {
        return wrap(inner.always(on: context, token: token, onComplete))
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new result.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new result, which the returned promise will adopt the value of.
    /// - Returns: A new promise that adopts the result returned by `onComplete`.
    ///
    /// - SeeAlso: `Promise.mapResult(on:token:_:)`
    public func mapResult<T,E>(on context: PromiseContext = .auto, onComplete: @escaping (PromiseResult<Value,Error>) -> PromiseResult<T,E>) -> TokenPromise<T,E> {
        return wrap(inner.mapResult(on: context, token: token, onComplete))
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new promise that adopts the same value that the promise returned by
    ///   `onComplete` does.
    ///
    /// - SeeAlso: `Promise.flatMapResult(on:token:_:)`
    public func flatMapResult<T,E>(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Promise<T,E>) -> TokenPromise<T,E> {
        return wrap(inner.flatMapResult(on: context, token: token, onComplete))
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new result.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new result, which the returned promise will adopt the value of.
    /// - Returns: A new promise that adopts the result returned by `onComplete`, or is rejected if
    ///   `onComplete` throws an error.
    public func tryMapResult<T,E: Swift.Error>(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> PromiseResult<T,E>) -> TokenPromise<T,Swift.Error> {
        return wrap(inner.tryMapResult(on: context, token: token, onComplete))
    }
    
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new `TokenPromise` that adopts the same value that the promise returned by
    ///   `onComplete` does, or is rejected if `onComplete` throws an error.
    ///
    /// - SeeAlso: `Promise.tryFlatMapResult(on:token:_:)`
    public func tryFlatMapResult<T,E: Swift.Error>(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,E>) -> TokenPromise<T,Swift.Error> {
        return wrap(inner.tryFlatMapResult(on: context, token: token, onComplete))
    }
    
    #if !compiler(>=5) // Swift 5 compiler makes the Swift.Error existential conform to itself
    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new result.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new result, which the returned promise will adopt the value of.
    /// - Returns: A new promise that adopts the result returned by `onComplete`, or is rejected if
    ///   `onComplete` throws an error.
    public func tryMapResult<T>(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> PromiseResult<T,Swift.Error>) -> TokenPromise<T,Swift.Error> {
        return wrap(inner.tryMapResult(on: context, token: token, onComplete))
    }

    /// Registers a callback that will be invoked with the promise result, no matter what it is, and
    /// returns a new promise to wait on.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onComplete: The callback that is invoked with the promise's value. This callback
    ///   returns a new promise, which the returned promise will adopt the value of.
    /// - Returns: A new `TokenPromise` that adopts the same value that the promise returned by
    ///   `onComplete` does, or is rejected if `onComplete` throws an error.
    ///
    /// - SeeAlso: `Promise.tryFlatMapResult(on:token:_:)`
    public func tryFlatMapResult<T>(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,Swift.Error>) -> TokenPromise<T,Swift.Error> {
        return wrap(inner.tryFlatMapResult(on: context, token: token, onComplete))
    }
    #endif
    
    /// Registers a callback that will be invoked when the promise is resolved without affecting behavior.
    ///
    /// This is similar to an `always` callback except it doesn't create a new `Promise` and instead
    /// returns its receiver. This means it won't delay any chained callbacks and it won't affect
    /// automatic cancellation propagation behavior.
    ///
    /// This is similar to `tap().always(on:_:)` except it can be inserted into any promise chain
    /// without affecting the chain.
    ///
    /// - Note: This method is intended for inserting into the middle of a promise chain without
    ///   affecting existing behavior (in particular, cancellation propagation). If you are not
    ///   inserting this into the middle of a promise chain, you probably want to use `then(on:_:)`,
    ///   `map(on:_:)`, `catch(on:_:)`, or `always(on:_:)` instead.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onComplete: The callback that is invoked with the promise's value.
    /// - Returns: The receiver.
    ///
    /// - SeeAlso: `Promise.tap(on:token:_:)`
    @discardableResult
    public func tap(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) -> TokenPromise<Value,Error> {
        return TokenPromise(promise: inner.tap(on: context, token: token, onComplete), token: token, initial: false)
    }
    
    /// Returns a new `TokenPromise` that adopts the result of the receiver without affecting its
    /// behavior.
    ///
    /// The returned `TokenPromise` will always resolve with the same value that its receiver does,
    /// but it won't affect the timing of any of the receiver's other observers and it won't affect
    /// automatic cancellation propagation behavior.
    ///
    /// `tap().always(on:_:)` behaves the same as `tap(on:_:)` except it returns a `TokenPromise`
    /// wrapping a new `Promise` whereas `tap(on:_:)` returns the receiver and can be inserted into
    /// any promise chain without affecting the chain.
    ///
    /// - Note: This method is intended for inserting into the middle of a promise chain without
    ///   affecting existing behavior (in particular, cancellation propagation). If you are not
    ///   inserting this into the middle of a promise chain, you probably want to use `then(on:_:)`,
    ///   `map(on:_:)`, `catch(on:_:)`, or `always(on:_:)` instead.
    ///
    /// - Returns: A new `TokenPromise` that adopts the same result as the receiver. Requesting the
    ///   new wrapped `Promise` to cancel does nothing.
    ///
    /// - SeeAlso: `Promise.tap()`
    public func tap() -> TokenPromise<Value,Error> {
        return TokenPromise(promise: inner.tap(), token: token, initial: false)
    }
    
    /// Registers a callback that will be invoked when the promise is cancelled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onCancel: The callback that is invoked when the promise is cancelled.
    /// - Returns: A new promise that will resolve to the same value as the receiver. You may safely
    ///   ignore this value.
    ///
    /// - SeeAlso: `Promise.onCancel(on:token:_:)`
    @discardableResult
    public func onCancel(on context: PromiseContext = .auto, _ onCancel: @escaping () -> Void) -> TokenPromise<Value,Error> {
        return wrap(inner.onCancel(on: context, token: token, onCancel))
    }
    
    // MARK: -
    
    /// Passes the `TokenPromise` to a block and then returns the `TokenPromise` for further
    /// chaining.
    ///
    /// This method exists to make it easy to add multiple children to the same `Promise` in a
    /// promise chain.
    ///
    /// - Note: Having multiple children on a single `Promise` can interfere with automatic
    ///   cancellation propagation. You may want to use `tap(on:_:)` or `tap()` for your sibling
    ///   children if you're returning the result of the promise chain to a caller that may wish to
    ///   cancel the chain.
    ///
    /// Example:
    ///
    ///     return urlSession.dataTaskAsPromise(for: url)
    ///         .withToken(promiseToken)
    ///         .fork({ $0.tap().then(on: .main, { analytics.recordNetworkLoad($0.response, for: url) }) })
    ///         .tryMap(on: .utility, { try JSONDecoder().decode(Model.self, from: $0.data) })
    public func fork(_ handler: (TokenPromise) throws -> Void) rethrows -> TokenPromise {
        try handler(self)
        return self
    }
    
    /// Returns a new `TokenPromise` that adopts the value of the receiver but ignores cancel
    /// requests.
    ///
    /// This is primarily useful when returning a nested promise in a callback handler in order to
    /// unlink cancellation of the outer promise with the inner one. It can also be used to stop
    /// propagating cancel requests up the chain, e.g. if you want to implement something similar to
    /// `tap(on:token:_:)`.
    ///
    /// - Note: This is similar to `tap()` except it prevents the parent promise from being
    ///   automatically cancelled due to cancel propagation from any observer.
    ///
    /// - Note: The returned `TokenPromise` will still be cancelled if its parent promise is
    ///   cancelled.
    ///
    /// - SeeAlso: `Promise.ignoringCancel()`
    public func ignoringCancel() -> TokenPromise<Value,Error> {
        return TokenPromise(promise: inner.ignoringCancel(), token: token, initial: false)
    }
    
    @available(*, unavailable, message: "Invalidate the associated token or use the .promise property instead.")
    public func requestCancel() {
        inner.requestCancel()
    }
    
    @available(*, unavailable, message: "TokenPromise already requests cancellation when its associated token is invalidated.")
    @discardableResult
    public func requestCancelOnInvalidate(_ token: PromiseInvalidationToken) -> TokenPromise<Value,Error> {
        token.requestCancelOnInvalidate(inner)
        return self
    }
}

// MARK: TokenPromise<_,Swift.Error>

extension TokenPromise where Error == Swift.Error {
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will resolve to the same value as the receiver, or rejected if
    ///   `onSuccess` throws an error. If the receiver is rejected or cancelled, the returned
    ///   promise will also be rejected or cancelled.
    public func tryThen(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) throws -> Void) -> TokenPromise<Value,Error> {
        return wrap(inner.tryThen(on: context, token: token, onSuccess))
    }
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be fulfilled with the return value of `onSuccess`, or
    ///   rejected if `onSuccess` throws an error. If the receiver is rejected or cancelled, the
    ///   returned promise will also be rejected or cancelled.
    ///
    /// - SeeAlso: `Promise.tryMap(on:token:_:)`
    public func tryMap<U>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) throws -> U) -> TokenPromise<U,Error> {
        return wrap(inner.tryMap(on: context, token: token, onSuccess))
    }
    
    #if !compiler(>=5) // Swift 5 compiler makes the Swift.Error existential conform to itself
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`, or rejected if `onSuccess` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    ///
    /// - SeeAlso: `Promise.tryFlatMap(on:token:_:)`
    public func tryFlatMap<U>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) throws -> Promise<U,Error>) -> TokenPromise<U,Error> {
        return wrap(inner.tryFlatMap(on: context, token: token, onSuccess))
    }
    #endif
    
    /// Registers a callback that is invoked when the promise is fulfilled.
    ///
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onSuccess: The callback that is invoked with the fulfilled value.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onSuccess`, or rejected if `onSuccess` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    ///
    /// - SeeAlso: `Promise.tryFlatMap(on:token:_:)`
    public func tryFlatMap<U,E: Swift.Error>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) throws -> Promise<U,E>) -> TokenPromise<U,Error> {
        return wrap(inner.tryFlatMap(on: context, token: token, onSuccess))
    }
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be fulfilled with the return value of `onError`, or
    ///   rejected if `onError` throws an error. If the receiver is rejected or cancelled, the
    ///   returned promise will also be rejected or cancelled.
    ///
    /// - SeeAlso: `Promise.tryRecover(on:token:_:)`
    public func tryRecover(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> Value) ->
        TokenPromise<Value,Error> {
            return wrap(inner.tryRecover(on: context, token: token, onError))
    }
    
    #if !compiler(>=5) // Swift 5 compiler makes the Swift.Error existential conform to itself
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`, or rejected if `onError` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    ///
    /// - SeeAlso: `Promise.tryFlatMapError(on:token:_:)`
    public func tryFlatMapError(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> Promise<Value,Error>) -> TokenPromise<Value,Error> {
        return wrap(inner.tryFlatMapError(on: context, token: token, onError))
    }
    #endif
    
    /// Registers a callback that is invoked when the promise is rejected.
    ///
    /// Unlike `catch(on:_:)` this callback can recover from the error and return a new value.
    //
    /// - Parameter context: The context to invoke the callback on. If not provided, defaults to
    ///   `.auto`, which evaluates to `.main` when invoked on the main thread, otherwise `.default`.
    /// - Parameter onError: The callback that is invoked with the rejected error.
    /// - Returns: A new promise that will be eventually resolved using the promise returned from
    ///   `onError`, or rejected if `onError` throws an error. If the receiver is rejected or
    ///   cancelled, the returned promise will also be rejected or cancelled.
    ///
    /// - SeeAlso: `Promise.tryFlatMapError(on:token:_:)`
    public func tryFlatMapError<E: Swift.Error>(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> Promise<Value,E>) -> TokenPromise<Value,Error> {
        return wrap(inner.tryFlatMapError(on: context, token: token, onError))
    }
}

// MARK: Equatable

extension TokenPromise: Equatable {
    /// Two `TokenPromise`s compare as equal if they represent the same promise.
    ///
    /// Two distinct `TokenPromise`s that are resolved to the same value compare as unequal.
    public static func ==(lhs: TokenPromise, rhs: TokenPromise) -> Bool {
        // Ignore the `initial` property; it's not visible to callers, and if we have two
        // `TokenPromise`s that are otherwise identical then the one with `initial == true` is just
        // going to do unnecessary work if it cancels returned promises anyway.
        return (lhs.inner, lhs.token) == (rhs.inner, rhs.token)
    }
}
