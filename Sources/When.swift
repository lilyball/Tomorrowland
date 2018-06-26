//
//  When.swift
//  Tomorrowland
//
//  Created by Ballard, Kevin on 12/20/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Tomorrowland.Private

/// Waits on an array of `Promise`s and returns a `Promise` that is fulfilled with an array of the
/// resulting fulfilled values.
///
/// The value of the returned `Promise` is an array of the same length as the input array and where
/// each element in the resulting array corresponds to the same element in the input array.
///
/// If any input `Promise` is rejected, the resulting `Promise` is rejected with the same error. If
/// any input `Promise` is cancelled, the resulting `Promise` is cancelled. If multiple input
/// `Promise`s are rejected or cancelled, the first such one determines how the returned `Promise`
/// behaves.
///
/// - Parameter promises: An array of `Promise`s whose fulfilled values will be collected to fulfill
///   the returned `Promise`.
/// - Parameter qos: The QoS to use for the dispatch queues that coordinate the work. The default
///   value is `.default`.
/// - Parameter cancelOnFailure: If `true`, all input `Promise`s will be cancelled if any of them
///   are rejected or cancelled. The default value of `false` means rejecting or cancelling an input
///   `Promise` does not cancel the rest.
/// - Returns: A `Promise` that will be fulfilled with an array of the fulfilled values from each
///   input `Promise`.
public func when<Value,Error>(fulfilled promises: [Promise<Value,Error>], qos: DispatchQoS.QoSClass = .default, cancelOnFailure: Bool = false) -> Promise<[Value],Error> {
    guard !promises.isEmpty else {
        return Promise(fulfilled: [])
    }
    let cancelAllInput: TWLOneshotBlock?
    if cancelOnFailure {
        cancelAllInput = TWLOneshotBlock(block: { [cancellables=promises.map({ $0.cancellable })] in
            for cancellable in cancellables {
                cancellable.requestCancel()
            }
        })
    } else {
        cancelAllInput = nil
    }
    
    let (resultPromise, resolver) = Promise<[Value],Error>.makeWithResolver()
    let count = promises.count
    var resultBuffer = UnsafeMutablePointer<Value?>.allocate(capacity: count)
    resultBuffer.initialize(repeating: nil, count: count)
    let group = DispatchGroup()
    let context = PromiseContext(qos: qos)
    for (i, promise) in promises.enumerated() {
        group.enter()
        promise._seal.enqueue { (result) in
            context.execute {
                switch result {
                case .value(let value):
                    resultBuffer[i] = value
                case .error(let error):
                    resolver.reject(with: error)
                    cancelAllInput?.invoke()
                case .cancelled:
                    resolver.cancel()
                    cancelAllInput?.invoke()
                }
                group.leave()
            }
        }
    }
    group.notify(queue: .global(qos: qos)) {
        defer {
            resultBuffer.deinitialize(count: count)
            resultBuffer.deallocate()
        }
        var results = ContiguousArray<Value>()
        results.reserveCapacity(count)
        for value in UnsafeMutableBufferPointer(start: resultBuffer, count: count) {
            if let value = value {
                results.append(value)
            } else {
                // Must have had a rejected or cancelled promise
                return
            }
        }
        resolver.fulfill(with: Array(results))
    }
    resolver.onRequestCancel(on: .immediate) { [boxes=promises.map({ Weak($0._box) })] (resolver) in
        for box in boxes {
            box.value?.propagateCancel()
        }
    }
    return resultPromise
}

// MARK: -

/// Waits on a tuple of `Promise`s and returns a `Promise` that is fulfilled with a tuple of the
/// resulting values.
///
/// The value of the returned `Promise` is an tuple where each element in the resulting tuple
/// corresponds to the same element in the input tuple.
///
/// If any input `Promise` is rejected, the resulting `Promise` is rejected with the same error. If
/// any input `Promise` is cancelled, the resulting `Promise` is cancelled. If multiple input
/// `Promise`s are rejected or cancelled, the first such one determines how the resulting `Promise`
/// behaves.
///
/// - Parameter a: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter b: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter c: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter d: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter e: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter f: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter qos: The QoS to use for the dispatch queues that coordinate the work. The default
///   value is `.default`.
/// - Parameter cancelOnFailure: If `true`, all input `Promise`s will be cancelled if any of them
///   are rejected or cancelled. The default value of `false` means rejecting or cancelling an input
///   `Promise` does not cancel the rest.
/// - Returns: A `Promise` that will be fulfilled with an array of the fulfilled values from each
///   input `Promise`.
public func when<Value1,Value2,Value3,Value4,Value5,Value6,Error>(fulfilled a: Promise<Value1,Error>,
                                                                  _ b: Promise<Value2,Error>,
                                                                  _ c: Promise<Value3,Error>,
                                                                  _ d: Promise<Value4,Error>,
                                                                  _ e: Promise<Value5,Error>,
                                                                  _ f: Promise<Value6,Error>,
                                                                  qos: DispatchQoS.QoSClass = .default,
                                                                  cancelOnFailure: Bool = false)
    -> Promise<(Value1,Value2,Value3,Value4,Value5,Value6),Error>
{
    let cancelAllInput: TWLOneshotBlock?
    if cancelOnFailure {
        cancelAllInput = TWLOneshotBlock(block: { [a=a.cancellable, b=b.cancellable, c=c.cancellable, d=d.cancellable, e=e.cancellable, f=f.cancellable] in
            a.requestCancel()
            b.requestCancel()
            c.requestCancel()
            d.requestCancel()
            e.requestCancel()
            f.requestCancel()
        })
    } else {
        cancelAllInput = nil
    }
    
    let (resultPromise, resolver) = Promise<(Value1,Value2,Value3,Value4,Value5,Value6),Error>.makeWithResolver()
    var (aResult, bResult, cResult, dResult, eResult, fResult): (Value1?, Value2?, Value3?, Value4?, Value5?, Value6?)
    let group = DispatchGroup()
    
    /// Like `promise.tap` except it registers a propagateCancel observer
    func tap<Value>(_ promise: Promise<Value,Error>, on context: PromiseContext, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) {
        promise._seal.enqueue { (result) in
            context.execute {
                onComplete(result)
            }
        }
    }
    
    let context = PromiseContext(qos: qos)
    group.enter()
    tap(a, on: context, { resolver.handleResult($0, output: &aResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(b, on: context, { resolver.handleResult($0, output: &bResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(c, on: context, { resolver.handleResult($0, output: &cResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(d, on: context, { resolver.handleResult($0, output: &dResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(e, on: context, { resolver.handleResult($0, output: &eResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(f, on: context, { resolver.handleResult($0, output: &fResult, cancelAllInput: cancelAllInput); group.leave() })
    
    group.notify(queue: .global(qos: qos)) {
        guard let a = aResult, let b = bResult, let c = cResult, let d = dResult, let e = eResult, let f = fResult else {
            // Must have had a rejected or cancelled promise
            return
        }
        resolver.fulfill(with: (a,b,c,d,e,f))
    }
    resolver.onRequestCancel(on: .immediate, {
        [weak boxA=a._box, weak boxB=b._box, weak boxC=c._box, weak boxD=d._box, weak boxE=e._box, weak boxF=f._box]
        (resolver) in
        boxA?.propagateCancel()
        boxB?.propagateCancel()
        boxC?.propagateCancel()
        boxD?.propagateCancel()
        boxE?.propagateCancel()
        boxF?.propagateCancel()
    })
    return resultPromise
}

/// Waits on a tuple of `Promise`s and returns a `Promise` that is fulfilled with a tuple of the
/// resulting values.
///
/// The value of the returned `Promise` is an tuple where each element in the resulting tuple
/// corresponds to the same element in the input tuple.
///
/// If any input `Promise` is rejected, the resulting `Promise` is rejected with the same error. If
/// any input `Promise` is cancelled, the resulting `Promise` is cancelled. If multiple input
/// `Promise`s are rejected or cancelled, the first such one determines how the resulting `Promise`
/// behaves.
///
/// - Parameter a: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter b: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter c: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter d: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter e: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter qos: The QoS to use for the dispatch queues that coordinate the work. The default
///   value is `.default`.
/// - Parameter cancelOnFailure: If `true`, all input `Promise`s will be cancelled if any of them
///   are rejected or cancelled. The default value of `false` means rejecting or cancelling an input
///   `Promise` does not cancel the rest.
/// - Returns: A `Promise` that will be fulfilled with an array of the fulfilled values from each
///   input `Promise`.
public func when<Value1,Value2,Value3,Value4,Value5,Error>(fulfilled a: Promise<Value1,Error>,
                                                           _ b: Promise<Value2,Error>,
                                                           _ c: Promise<Value3,Error>,
                                                           _ d: Promise<Value4,Error>,
                                                           _ e: Promise<Value5,Error>,
                                                           qos: DispatchQoS.QoSClass = .default,
                                                           cancelOnFailure: Bool = false)
    -> Promise<(Value1,Value2,Value3,Value4,Value5),Error>
{
    // NB: copy&paste of 6-element version
    let cancelAllInput: TWLOneshotBlock?
    if cancelOnFailure {
        cancelAllInput = TWLOneshotBlock(block: { [a=a.cancellable, b=b.cancellable, c=c.cancellable, d=d.cancellable, e=e.cancellable] in
            a.requestCancel()
            b.requestCancel()
            c.requestCancel()
            d.requestCancel()
            e.requestCancel()
        })
    } else {
        cancelAllInput = nil
    }
    
    let (resultPromise, resolver) = Promise<(Value1,Value2,Value3,Value4,Value5),Error>.makeWithResolver()
    var (aResult, bResult, cResult, dResult, eResult): (Value1?, Value2?, Value3?, Value4?, Value5?)
    let group = DispatchGroup()
    
    /// Like `promise.tap` except it registers a propagateCancel observer
    func tap<Value>(_ promise: Promise<Value,Error>, on context: PromiseContext, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) {
        promise._seal.enqueue { (result) in
            context.execute {
                onComplete(result)
            }
        }
    }
    
    let context = PromiseContext(qos: qos)
    group.enter()
    tap(a, on: context, { resolver.handleResult($0, output: &aResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(b, on: context, { resolver.handleResult($0, output: &bResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(c, on: context, { resolver.handleResult($0, output: &cResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(d, on: context, { resolver.handleResult($0, output: &dResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(e, on: context, { resolver.handleResult($0, output: &eResult, cancelAllInput: cancelAllInput); group.leave() })
    
    group.notify(queue: .global(qos: qos)) {
        guard let a = aResult, let b = bResult, let c = cResult, let d = dResult, let e = eResult else {
            // Must have had a rejected or cancelled promise
            return
        }
        resolver.fulfill(with: (a,b,c,d,e))
    }
    resolver.onRequestCancel(on: .immediate, {
        [weak boxA=a._box, weak boxB=b._box, weak boxC=c._box, weak boxD=d._box, weak boxE=e._box]
        (resolver) in
        boxA?.propagateCancel()
        boxB?.propagateCancel()
        boxC?.propagateCancel()
        boxD?.propagateCancel()
        boxE?.propagateCancel()
    })
    return resultPromise
}

/// Waits on a tuple of `Promise`s and returns a `Promise` that is fulfilled with a tuple of the
/// resulting values.
///
/// The value of the returned `Promise` is an tuple where each element in the resulting tuple
/// corresponds to the same element in the input tuple.
///
/// If any input `Promise` is rejected, the resulting `Promise` is rejected with the same error. If
/// any input `Promise` is cancelled, the resulting `Promise` is cancelled. If multiple input
/// `Promise`s are rejected or cancelled, the first such one determines how the resulting `Promise`
/// behaves.
///
/// - Parameter a: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter b: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter c: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter d: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter qos: The QoS to use for the dispatch queues that coordinate the work. The default
///   value is `.default`.
/// - Parameter cancelOnFailure: If `true`, all input `Promise`s will be cancelled if any of them
///   are rejected or cancelled. The default value of `false` means rejecting or cancelling an input
///   `Promise` does not cancel the rest.
/// - Returns: A `Promise` that will be fulfilled with an array of the fulfilled values from each
///   input `Promise`.
public func when<Value1,Value2,Value3,Value4,Error>(fulfilled a: Promise<Value1,Error>,
                                                    _ b: Promise<Value2,Error>,
                                                    _ c: Promise<Value3,Error>,
                                                    _ d: Promise<Value4,Error>,
                                                    qos: DispatchQoS.QoSClass = .default,
                                                    cancelOnFailure: Bool = false)
    -> Promise<(Value1,Value2,Value3,Value4),Error>
{
    // NB: copy&paste of 6-element version
    let cancelAllInput: TWLOneshotBlock?
    if cancelOnFailure {
        cancelAllInput = TWLOneshotBlock(block: { [a=a.cancellable, b=b.cancellable, c=c.cancellable, d=d.cancellable] in
            a.requestCancel()
            b.requestCancel()
            c.requestCancel()
            d.requestCancel()
        })
    } else {
        cancelAllInput = nil
    }
    
    let (resultPromise, resolver) = Promise<(Value1,Value2,Value3,Value4),Error>.makeWithResolver()
    var (aResult, bResult, cResult, dResult): (Value1?, Value2?, Value3?, Value4?)
    let group = DispatchGroup()
    
    /// Like `promise.tap` except it registers a propagateCancel observer
    func tap<Value>(_ promise: Promise<Value,Error>, on context: PromiseContext, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) {
        promise._seal.enqueue { (result) in
            context.execute {
                onComplete(result)
            }
        }
    }
    
    let context = PromiseContext(qos: qos)
    group.enter()
    tap(a, on: context, { resolver.handleResult($0, output: &aResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(b, on: context, { resolver.handleResult($0, output: &bResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(c, on: context, { resolver.handleResult($0, output: &cResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(d, on: context, { resolver.handleResult($0, output: &dResult, cancelAllInput: cancelAllInput); group.leave() })
    
    group.notify(queue: .global(qos: qos)) {
        guard let a = aResult, let b = bResult, let c = cResult, let d = dResult else {
            // Must have had a rejected or cancelled promise
            return
        }
        resolver.fulfill(with: (a,b,c,d))
    }
    resolver.onRequestCancel(on: .immediate, {
        [weak boxA=a._box, weak boxB=b._box, weak boxC=c._box, weak boxD=d._box]
        (resolver) in
        boxA?.propagateCancel()
        boxB?.propagateCancel()
        boxC?.propagateCancel()
        boxD?.propagateCancel()
    })
    return resultPromise
}

/// Waits on a tuple of `Promise`s and returns a `Promise` that is fulfilled with a tuple of the
/// resulting values.
///
/// The value of the returned `Promise` is an tuple where each element in the resulting tuple
/// corresponds to the same element in the input tuple.
///
/// If any input `Promise` is rejected, the resulting `Promise` is rejected with the same error. If
/// any input `Promise` is cancelled, the resulting `Promise` is cancelled. If multiple input
/// `Promise`s are rejected or cancelled, the first such one determines how the resulting `Promise`
/// behaves.
///
/// - Parameter a: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter b: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter c: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter qos: The QoS to use for the dispatch queues that coordinate the work. The default
///   value is `.default`.
/// - Parameter cancelOnFailure: If `true`, all input `Promise`s will be cancelled if any of them
///   are rejected or cancelled. The default value of `false` means rejecting or cancelling an input
///   `Promise` does not cancel the rest.
/// - Returns: A `Promise` that will be fulfilled with an array of the fulfilled values from each
///   input `Promise`.
public func when<Value1,Value2,Value3,Error>(fulfilled a: Promise<Value1,Error>,
                                             _ b: Promise<Value2,Error>,
                                             _ c: Promise<Value3,Error>,
                                             qos: DispatchQoS.QoSClass = .default,
                                             cancelOnFailure: Bool = false)
    -> Promise<(Value1,Value2,Value3),Error>
{
    // NB: copy&paste of 6-element version
    let cancelAllInput: TWLOneshotBlock?
    if cancelOnFailure {
        cancelAllInput = TWLOneshotBlock(block: { [a=a.cancellable, b=b.cancellable, c=c.cancellable] in
            a.requestCancel()
            b.requestCancel()
            c.requestCancel()
        })
    } else {
        cancelAllInput = nil
    }
    
    let (resultPromise, resolver) = Promise<(Value1,Value2,Value3),Error>.makeWithResolver()
    var (aResult, bResult, cResult): (Value1?, Value2?, Value3?)
    let group = DispatchGroup()
    
    /// Like `promise.tap` except it registers a propagateCancel observer
    func tap<Value>(_ promise: Promise<Value,Error>, on context: PromiseContext, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) {
        promise._seal.enqueue { (result) in
            context.execute {
                onComplete(result)
            }
        }
    }
    
    let context = PromiseContext(qos: qos)
    group.enter()
    tap(a, on: context, { resolver.handleResult($0, output: &aResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(b, on: context, { resolver.handleResult($0, output: &bResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(c, on: context, { resolver.handleResult($0, output: &cResult, cancelAllInput: cancelAllInput); group.leave() })
    
    group.notify(queue: .global(qos: qos)) {
        guard let a = aResult, let b = bResult, let c = cResult else {
            // Must have had a rejected or cancelled promise
            return
        }
        resolver.fulfill(with: (a,b,c))
    }
    resolver.onRequestCancel(on: .immediate, {
        [weak boxA=a._box, weak boxB=b._box, weak boxC=c._box]
        (resolver) in
        boxA?.propagateCancel()
        boxB?.propagateCancel()
        boxC?.propagateCancel()
    })
    return resultPromise
}

/// Waits on a tuple of `Promise`s and returns a `Promise` that is fulfilled with a tuple of the
/// resulting values.
///
/// The value of the returned `Promise` is an tuple where each element in the resulting tuple
/// corresponds to the same element in the input tuple.
///
/// If any input `Promise` is rejected, the resulting `Promise` is rejected with the same error. If
/// any input `Promise` is cancelled, the resulting `Promise` is cancelled. If multiple input
/// `Promise`s are rejected or cancelled, the first such one determines how the resulting `Promise`
/// behaves.
///
/// - Parameter a: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter b: A `Promise` whose value is included in the resulting `Promise`.
/// - Parameter qos: The QoS to use for the dispatch queues that coordinate the work. The default
///   value is `.default`.
/// - Parameter cancelOnFailure: If `true`, all input `Promise`s will be cancelled if any of them
///   are rejected or cancelled. The default value of `false` means rejecting or cancelling an input
///   `Promise` does not cancel the rest.
/// - Returns: A `Promise` that will be fulfilled with an array of the fulfilled values from each
///   input `Promise`.
public func when<Value1,Value2,Error>(fulfilled a: Promise<Value1,Error>,
                                      _ b: Promise<Value2,Error>,
                                      qos: DispatchQoS.QoSClass = .default,
                                      cancelOnFailure: Bool = false)
    -> Promise<(Value1,Value2),Error>
{
    // NB: copy&paste of 6-element version
    let cancelAllInput: TWLOneshotBlock?
    if cancelOnFailure {
        cancelAllInput = TWLOneshotBlock(block: { [a=a.cancellable, b=b.cancellable] in
            a.requestCancel()
            b.requestCancel()
        })
    } else {
        cancelAllInput = nil
    }
    
    let (resultPromise, resolver) = Promise<(Value1,Value2),Error>.makeWithResolver()
    var (aResult, bResult): (Value1?, Value2?)
    let group = DispatchGroup()
    
    /// Like `promise.tap` except it registers a propagateCancel observer
    func tap<Value>(_ promise: Promise<Value,Error>, on context: PromiseContext, _ onComplete: @escaping (PromiseResult<Value,Error>) -> Void) {
        promise._seal.enqueue { (result) in
            context.execute {
                onComplete(result)
            }
        }
    }
    
    let context = PromiseContext(qos: qos)
    group.enter()
    tap(a, on: context, { resolver.handleResult($0, output: &aResult, cancelAllInput: cancelAllInput); group.leave() })
    group.enter()
    tap(b, on: context, { resolver.handleResult($0, output: &bResult, cancelAllInput: cancelAllInput); group.leave() })
    
    group.notify(queue: .global(qos: qos)) {
        guard let a = aResult, let b = bResult else {
            // Must have had a rejected or cancelled promise
            return
        }
        resolver.fulfill(with: (a,b))
    }
    resolver.onRequestCancel(on: .immediate, {
        [weak boxA=a._box, weak boxB=b._box]
        (resolver) in
        boxA?.propagateCancel()
        boxB?.propagateCancel()
    })
    return resultPromise
}

private extension Promise.Resolver {
    @inline(__always)
    func handleResult<Value>(_ result: PromiseResult<Value,Error>, output: inout Value?, cancelAllInput: TWLOneshotBlock?) {
        switch result {
        case .value(let value):
            output = value
        case .error(let error):
            reject(with: error)
            cancelAllInput?.invoke()
        case .cancelled:
            cancel()
            cancelAllInput?.invoke()
        }
    }
}

// MARK: -

/// Returns a `Promise` that is resolved with the result of the first resolved input `Promise`.
///
/// The first input `Promise` that is either fulfilled or rejected causes the resulting `Promise` to
/// be fulfilled or rejected. An input `Promise` that is cancelled is ignored. If all input
/// `Promise`s are cancelled, the resulting `Promise` is cancelled.
///
/// - Parameter promises: An array of `Promise`s.
/// - Parameter cancelRemaining: If `true`, all remaining input `Promise`s will be cancelled as soon
///   as the first one is resolved. The default value of `false` means resolving an input `Promise`
///   does not cancel the rest.
/// - Returns: A `Promise` that will be resolved with the value or error from the first fulfilled or
///   rejected input `Promise`.
public func when<Value,Error>(first promises: [Promise<Value,Error>], cancelRemaining: Bool = false) -> Promise<Value,Error> {
    guard !promises.isEmpty else {
        return Promise(on: .immediate, { $0.cancel() })
    }
    let cancelAllInput: TWLOneshotBlock?
    if cancelRemaining {
        cancelAllInput = TWLOneshotBlock(block: { [cancellables=promises.map({ $0.cancellable })] in
            for cancellable in cancellables {
                cancellable.requestCancel()
            }
        })
    } else {
        cancelAllInput = nil
    }

    let (newPromise, resolver) = Promise<Value,Error>.makeWithResolver()
    let group = DispatchGroup()
    for promise in promises {
        group.enter()
        promise._seal.enqueue { (result) in
            switch result {
            case .value(let value):
                resolver.fulfill(with: value)
                cancelAllInput?.invoke()
            case .error(let error):
                resolver.reject(with: error)
                cancelAllInput?.invoke()
            case .cancelled:
                break
            }
            group.leave()
        }
    }
    group.notify(queue: .global(qos: .utility)) {
        resolver.cancel()
    }
    resolver.onRequestCancel(on: .immediate) { [boxes=promises.map({ Weak($0._box) })] (resolver) in
        for box in boxes {
            box.value?.propagateCancel()
        }
    }
    return newPromise
}

// MARK: - Private

private struct Weak<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
}
