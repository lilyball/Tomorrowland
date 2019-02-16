//
//  Bridging.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 1/4/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import class Foundation.NSError

extension Promise where Value: AnyObject, Error: AnyObject {
    public init(_ promise: ObjCPromise<Value,Error>) {
        self.init(on: .immediate) { (resolver) in
            promise.inspect(on: .immediate, { (value, error) in
                if let value = value {
                    resolver.fulfill(with: value)
                } else if let error = error {
                    resolver.reject(with: error)
                } else {
                    resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { [weak promise] (_) in
                promise?.requestCancel()
            })
        }
    }
    
    public func objc() -> ObjCPromise<Value,Error> {
        return ObjCPromise<Value,Error>(on: .immediate) { [cancellable] (resolver) in
            self.always(on: .immediate, { (result) in
                switch result {
                case .value(let value): resolver.fulfill(with: value)
                case .error(let error): resolver.reject(with: error)
                case .cancelled: resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { (_) in
                cancellable.requestCancel()
            })
        }
    }
}

extension Promise {
    public init<T,E>(bridging promise: ObjCPromise<T,E>, mapValue: @escaping (T) -> Value, mapError: @escaping (E) -> Error) {
        self.init(on: .immediate) { (resolver) in
            promise.inspect(on: .immediate, { (value, error) in
                if let value = value {
                    resolver.fulfill(with: mapValue(value))
                } else if let error = error {
                    resolver.reject(with: mapError(error))
                } else {
                    resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { [weak promise] (_) in
                promise?.requestCancel()
            })
        }
    }
    
    public func objc<T: AnyObject, E: AnyObject>(mapValue: @escaping (Value) -> T, mapError: @escaping (Error) -> E) -> ObjCPromise<T,E> {
        return ObjCPromise<T,E>(on: .immediate) { [cancellable] (resolver) in
            self.always(on: .immediate, { (result) in
                switch result {
                case .value(let value): resolver.fulfill(with: mapValue(value))
                case .error(let error): resolver.reject(with: mapError(error))
                case .cancelled: resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { (_) in
                cancellable.requestCancel()
            })
        }
    }
    
    public func objc<T: AnyObject>(mapValue: @escaping (Value) throws -> T, mapError: @escaping (Error) throws -> Swift.Error) -> ObjCPromise<T,NSError> {
        return ObjCPromise<T,NSError>(on: .immediate) { [cancellable] (resolver) in
            self.always(on: .immediate, { (result) in
                do {
                    switch result {
                    case .value(let value): resolver.fulfill(with: try mapValue(value))
                    case .error(let error): resolver.reject(with: try mapError(error) as NSError)
                    case .cancelled: resolver.cancel()
                    }
                } catch {
                    resolver.reject(with: error as NSError)
                }
            })
            resolver.onRequestCancel(on: .immediate, { (_) in
                cancellable.requestCancel()
            })
        }
    }
}

extension Promise where Value: AnyObject {
    public init<E>(bridging promise: ObjCPromise<Value,E>, mapError: @escaping (E) -> Error) {
        self.init(on: .immediate) { (resolver) in
            promise.inspect(on: .immediate, { (value, error) in
                if let value = value {
                    resolver.fulfill(with: value)
                } else if let error = error {
                    resolver.reject(with: mapError(error))
                } else {
                    resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { [weak promise] (_) in
                promise?.requestCancel()
            })
        }
    }
    
    public func objc<E: AnyObject>(mapError: @escaping (Error) -> E) -> ObjCPromise<Value,E> {
        return ObjCPromise<Value,E>(on: .immediate) { [cancellable] (resolver) in
            self.always(on: .immediate, { (result) in
                switch result {
                case .value(let value): resolver.fulfill(with: value)
                case .error(let error): resolver.reject(with: mapError(error))
                case .cancelled: resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { (_) in
                cancellable.requestCancel()
            })
        }
    }
    
    public func objc(mapError: @escaping (Error) throws -> Swift.Error) -> ObjCPromise<Value,NSError> {
        return objc(mapError: { (err) -> NSError in
            do {
                return try mapError(err) as NSError
            } catch {
                return error as NSError
            }
        })
    }
}

extension Promise where Error: AnyObject {
    public init<T>(bridging promise: ObjCPromise<T,Error>, mapValue: @escaping (T) -> Value) {
        self.init(on: .immediate) { (resolver) in
            promise.inspect(on: .immediate, { (value, error) in
                if let value = value {
                    resolver.fulfill(with: mapValue(value))
                } else if let error = error {
                    resolver.reject(with: error)
                } else {
                    resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { [weak promise] (_) in
                promise?.requestCancel()
            })
        }
    }
    
    public func objc<T: AnyObject>(mapValue: @escaping (Value) -> T) -> ObjCPromise<T,Error> {
        return ObjCPromise<T,Error>(on: .immediate) { [cancellable] (resolver) in
            self.always(on: .immediate, { (result) in
                switch result {
                case .value(let value): resolver.fulfill(with: mapValue(value))
                case .error(let error): resolver.reject(with: error)
                case .cancelled: resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { (_) in
                cancellable.requestCancel()
            })
        }
    }
}

extension Promise where Error == Swift.Error {
    public init<T,E>(bridging promise: ObjCPromise<T,E>, mapValue: @escaping (T) throws -> Value, mapError: @escaping (E) throws -> Error) {
        self.init(on: .immediate) { (resolver) in
            promise.inspect(on: .immediate, { (value, error) in
                do {
                    if let value = value {
                        resolver.fulfill(with: try mapValue(value))
                    } else if let error = error {
                        resolver.reject(with: try mapError(error))
                    } else {
                        resolver.cancel()
                    }
                } catch {
                    resolver.reject(with: error)
                }
            })
            resolver.onRequestCancel(on: .immediate, { [weak promise] (_) in
                promise?.requestCancel()
            })
        }
    }
    
    public init<T>(bridging promise: ObjCPromise<T,NSError>, mapValue: @escaping (T) throws -> Value) {
        self.init(on: .immediate) { (resolver) in
            promise.inspect(on: .immediate, { (value, error) in
                do {
                    if let value = value {
                        resolver.fulfill(with: try mapValue(value))
                    } else if let error = error {
                        resolver.reject(with: error)
                    } else {
                        resolver.cancel()
                    }
                } catch {
                    resolver.reject(with: error)
                }
            })
            resolver.onRequestCancel(on: .immediate, { [weak promise] (_) in
                promise?.requestCancel()
            })
        }
    }
    
    public func objc<T: AnyObject>(mapValue: @escaping (Value) throws -> T) -> ObjCPromise<T,NSError> {
        return ObjCPromise<T,NSError>(on: .immediate) { [cancellable] (resolver) in
            self.always(on: .immediate, { (result) in
                do {
                    switch result {
                    case .value(let value): resolver.fulfill(with: try mapValue(value))
                    case .error(let error): resolver.reject(with: error as NSError)
                    case .cancelled: resolver.cancel()
                    }
                } catch {
                    resolver.reject(with: error as NSError)
                }
            })
            resolver.onRequestCancel(on: .immediate, { (_) in
                cancellable.requestCancel()
            })
        }
    }
}

extension Promise where Value: AnyObject, Error == Swift.Error {
    public init(bridging promise: ObjCPromise<Value,NSError>) {
        self.init(on: .immediate) { (resolver) in
            promise.inspect(on: .immediate, { (value, error) in
                if let value = value {
                    resolver.fulfill(with: value)
                } else if let error = error {
                    resolver.reject(with: error)
                } else {
                    resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { [weak promise] (_) in
                promise?.requestCancel()
            })
        }
    }
    
    public func objc() -> ObjCPromise<Value,NSError> {
        return ObjCPromise<Value,NSError>(on: .immediate) { [cancellable] (resolver) in
            self.always(on: .immediate, { (result) in
                switch result {
                case .value(let value): resolver.fulfill(with: value)
                case .error(let error): resolver.reject(with: error as NSError)
                case .cancelled: resolver.cancel()
                }
            })
            resolver.onRequestCancel(on: .immediate, { (_) in
                cancellable.requestCancel()
            })
        }
    }
}
