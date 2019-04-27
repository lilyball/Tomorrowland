//
//  Deprecations.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 2/16/19.
//  Copyright © 2019 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import typealias Foundation.TimeInterval

public extension Promise {
    @available(*, deprecated, renamed: "init(with:)")
    init(result: PromiseResult<Value,Error>) {
        self.init(with: result)
    }
    
    @available(*, deprecated, renamed: "init(on:with:after:)")
    init(on context: PromiseContext = .auto, result: PromiseResult<Value,Error>, after delay: TimeInterval) {
        self.init(on: context, with: result, after: delay)
    }
}

// MARK: - Great API Rename

public extension Promise {
    @available(*, unavailable, renamed: "map(on:token:_:)")
    func then<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) -> U) -> Promise<U,Error> {
        return self.map(on: context, token: token, onSuccess)
    }
    
    @available(*, unavailable, renamed: "flatMap(on:token:_:)")
    func then<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) -> Promise<U,Error>) -> Promise<U,Error> {
        return self.flatMap(on: context, token: token, onSuccess)
    }
    
    @available(*, unavailable, renamed: "flatMapError(on:token:_:)")
    func recover<E>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) -> Promise<Value,E>) -> Promise<Value,E> {
        return self.flatMapError(on: context, token: token, onError)
    }
    
    @available(*, unavailable, renamed: "flatMapResult(on:token:_:)")
    func always<T,E>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Promise<T,E>) -> Promise<T,E> {
        return self.flatMapResult(on: context, token: token, onComplete)
    }
    
    @available(*, unavailable, renamed: "tryFlatMapResult(on:token:_:)")
    func tryAlways<T,E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,E>) -> Promise<T,Swift.Error> {
        return self.tryFlatMapResult(on: context, token: token, onComplete)
    }
    
    #if !compiler(>=5)
    @available(*, unavailable, renamed: "tryFlatMapResult(on:token:_:)")
    func tryAlways<T>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,Swift.Error>) -> Promise<T,Swift.Error> {
        return self.tryFlatMapResult(on: context, token: token, onComplete)
    }
    #endif
}

public extension Promise where Error == Swift.Error {
    @available(*, unavailable, renamed: "tryMap(on:token:_:)")
    func tryThen<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> U) -> Promise<U,Error> {
        return self.tryMap(on: context, token: token, onSuccess)
    }
    
    #if !compiler(>=5)
    @available(*, unavailable, renamed: "tryFlatMap(on:token:_:)")
    func tryThen<U>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Promise<U,Error>) -> Promise<U,Error> {
        return self.tryFlatMap(on: context, token: token, onSuccess)
    }
    #endif
    
    @available(*, unavailable, renamed: "tryFlatMap(on:token:_:)")
    func tryThen<U,E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onSuccess: @escaping (Value) throws -> Promise<U,E>) -> Promise<U,Error> {
        return self.tryFlatMap(on: context, token: token, onSuccess)
    }
    
    #if !compiler(>=5)
    @available(*, unavailable, renamed: "tryFlatMapError(on:token:_:)")
    func tryRecover(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Promise<Value,Error>) -> Promise<Value,Error> {
        return self.tryFlatMapError(on: context, token: token, onError)
    }
    #endif
    
    @available(*, unavailable, renamed: "tryFlatMapError(on:token:_:)")
    func tryRecover<E: Swift.Error>(on context: PromiseContext = .auto, token: PromiseInvalidationToken? = nil, _ onError: @escaping (Error) throws -> Promise<Value,E>) -> Promise<Value,Error> {
        return self.tryFlatMapError(on: context, token: token, onError)
    }
}

public extension TokenPromise {
    @available(*, unavailable, renamed: "map(on:_:)")
    func then<U>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) -> U) -> TokenPromise<U,Error> {
        return self.map(on: context, onSuccess)
    }
    
    @available(*, unavailable, renamed: "flatMap(on:_:)")
    func then<U>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) -> Promise<U,Error>) -> TokenPromise<U,Error> {
        return self.flatMap(on: context, onSuccess)
    }
    
    @available(*, unavailable, renamed: "flatMapError(on:_:)")
    func recover<E>(on context: PromiseContext = .auto, _ onError: @escaping (Error) -> Promise<Value,E>) -> TokenPromise<Value,E> {
        return self.flatMapError(on: context, onError)
    }
    
    @available(*, unavailable, renamed: "flatMapResult(on:_:)")
    func always<T,E>(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Promise<T,E>) -> TokenPromise<T,E> {
        return self.flatMapResult(on: context, onComplete)
    }
    
    @available(*, unavailable, renamed: "tryFlatMapResult(on:_:)")
    func tryAlways<T,E: Swift.Error>(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,E>) -> TokenPromise<T,Swift.Error> {
        return self.tryFlatMapResult(on: context, onComplete)
    }
    
    #if !compiler(>=5)
    @available(*, unavailable, renamed: "tryFlatMapResult(on:_:)")
    func tryAlways<T>(on context: PromiseContext = .auto, _ onComplete: @escaping (PromiseResult<Value,Error>) throws -> Promise<T,Swift.Error>) -> TokenPromise<T,Swift.Error> {
        return self.tryFlatMapResult(on: context, onComplete)
    }
    #endif
}

public extension TokenPromise where Error == Swift.Error {
    @available(*, unavailable, renamed: "tryMap(on:_:)")
    func tryThen<U>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) throws -> U) -> TokenPromise<U,Error> {
        return self.tryMap(on: context, onSuccess)
    }
    
    #if !compiler(>=5)
    @available(*, unavailable, renamed: "tryFlatMap(on:_:)")
    func tryThen<U>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) throws -> Promise<U,Error>) -> TokenPromise<U,Error> {
        return self.tryFlatMap(on: context, onSuccess)
    }
    #endif
    
    @available(*, unavailable, renamed: "tryFlatMap(on:_:)")
    func tryThen<U,E: Swift.Error>(on context: PromiseContext = .auto, _ onSuccess: @escaping (Value) throws -> Promise<U,E>) -> TokenPromise<U,Error> {
        return self.tryFlatMap(on: context, onSuccess)
    }
    
    #if !compiler(>=5)
    @available(*, unavailable, renamed: "tryFlatMapError(on:_:)")
    func tryRecover(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> Promise<Value,Error>) -> TokenPromise<Value,Error> {
        return self.tryFlatMapError(on: context, onError)
    }
    #endif
    
    @available(*, unavailable, renamed: "tryFlatMapError(on:_:)")
    func tryRecover<E: Swift.Error>(on context: PromiseContext = .auto, _ onError: @escaping (Error) throws -> Promise<Value,E>) -> TokenPromise<Value,Error> {
        return self.tryFlatMapError(on: context, onError)
    }
}
