//
//  PromiseUtilities.swift
//  Promissory
//
//  Created by Ballard, Kevin on 12/20/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import Promissory.Private

/// Waits on an array of `Promise`s and returns a `Promise` that is fulfilled with an array of the
/// resulting values.
///
/// The value of the returned `Promise` is an array of the same length as the input array and where
/// each element in the resulting array corresponds to the same element in the input array.
///
/// If any input `Promise` is rejected, the resulting `Promise` is rejected with the same error. If
/// any input `Promise` is cancelled, the resulting `Promise` is cancelled. If multiple input
/// `Promise`s are rejected or cancelled, the first such one determines how the resulting `Promise`
/// behaves.
///
/// - Parameter promises: An array of `Promise`s whose values will be collected to fulfill the
///   returned `Promise`.
/// - Parameter qos: The QoS to use for the dispatch queues that coordinate the work. The default
///   value is `.default`.
/// - Parameter cancelOnFailure: The default value of `true` means all input `Promise`s will be
///   cancelled if any of them are rejected or cancelled. If `false`, rejecting or cancelling an
///   input `Promise` does not cancel the rest.
/// - Returns: A `Promise` that will be fulfilled with an array of the fulfilled values from each
///   input `Promise`.
public func when<Value,Error>(fulfilled promises: [Promise<Value,Error>], qos: DispatchQoS.QoSClass = .default, cancelOnFailure: Bool = true) -> Promise<[Value],Error> {
    guard !promises.isEmpty else {
        return Promise(fulfilled: [])
    }
    let cancelAllInput: PMSOneshotBlock?
    if cancelOnFailure {
        cancelAllInput = PMSOneshotBlock(block: {
            for promise in promises {
                promise.requestCancel()
            }
        })
    } else {
        cancelAllInput = nil
    }
    
    let (resultPromise, resolver) = Promise<[Value],Error>.makeWithResolver()
    let count = promises.count
    var resultBuffer = UnsafeMutablePointer<Value?>.allocate(capacity: count)
    resultBuffer.initialize(to: nil, count: count)
    let group = DispatchGroup()
    for (i, promise) in promises.enumerated() {
        group.enter()
        promise.always(on: PromiseContext(qos: qos), { (result) in
            switch result {
            case .value(let value):
                resultBuffer[i] = value
                break
            case .error(let error):
                resolver.reject(error)
                cancelAllInput?.invoke()
            case .cancelled:
                resolver.cancel()
                cancelAllInput?.invoke()
            }
            group.leave()
        })
    }
    group.notify(queue: DispatchQueue.global(qos: qos)) {
        defer {
            resultBuffer.deinitialize(count: count)
            resultBuffer.deallocate(capacity: count)
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
        resolver.fulfill(Array(results))
    }
    return resultPromise
}

