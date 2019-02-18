//
//  CancelTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 12/22/17.
//  Copyright © 2017 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Tomorrowland

final class CancelTests: XCTestCase {
    func testRequestCancelOnInvalidate() {
        let (promise, sema) = StdPromise.makeCancellablePromise(value: 2)
        let token = PromiseInvalidationToken()
        token.requestCancelOnInvalidate(promise)
        let expectation = XCTestExpectation(onCancel: promise)
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testRequestCancelOnInvalidateMultipleBlocks() {
        let token = PromiseInvalidationToken()
        let expectationsAndSemas = (1...5).map({ x -> (XCTestExpectation, DispatchSemaphore) in
            let (promise, sema) = StdPromise.makeCancellablePromise(value: 2)
            token.requestCancelOnInvalidate(promise)
            return (XCTestExpectation(onCancel: promise), sema)
        })
        token.invalidate()
        for sema in expectationsAndSemas.map({ $0.1 }) {
            sema.signal()
        }
        wait(for: expectationsAndSemas.map({ $0.0 }), timeout: 1)
    }
    
    func testPromiseRequestCancelOnInvalidate() {
        let (promise, sema) = StdPromise.makeCancellablePromise(value: 2)
        let token = PromiseInvalidationToken()
        promise.requestCancelOnInvalidate(token)
        let expectation = XCTestExpectation(onCancel: promise)
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testPropagateCancelThen() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
            let promise2 = promise.then(on: .utility, { (x) in
                XCTFail("callback invoked")
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelThenCancelAfterSeal() {
        // Ensure cancelling after the promise is sealed works as well.
        // We're just going to test it on this one type instead of on all.
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        let promise2: Promise<Int,String>
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
            promise2 = promise.then(on: .utility, { (x) in
                XCTFail("callback invoked")
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        }
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelThenDontCancelIfMoreObservers() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        let promise2: Promise<Int,String>
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
            promise2 = promise.then(on: .utility, { (x) in
                XCTFail("callback invoked")
            })
            let promise3 = promise.then(on: .utility, { (x) in
                XCTFail("callback invoked")
            })
            // Note: promise2 isn't cancelled here because requestCancel on a registered callback
            // promise doesn't actually cancel it, it just propagates the cancel request upwards.
            // The promise is only cancelled if its parent promise is cancelled.
            expectations = [XCTestExpectation(onError: promise, expectedError: "foo"),
                            XCTestExpectation(onError: promise2, expectedError: "foo"),
                            XCTestExpectation(onError: promise3, expectedError: "foo")]
        }
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelThenCancelAfterAllObservers() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        let promise2: Promise<Int,String>
        let promise3: Promise<Int,String>
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
            promise2 = promise.then(on: .utility, { (x) in
                XCTFail("callback invoked")
            })
            promise3 = promise.then(on: .immediate, { (x) in
                XCTFail("callback invoked")
            })
            expectations = [XCTestExpectation(onCancel: promise),
                            XCTestExpectation(onCancel: promise2),
                            XCTestExpectation(onCancel: promise3)]
        }
        promise2.requestCancel()
        // if promise cancelled then it should have propagated to promise3 already
        XCTAssertNil(promise3.result)
        promise3.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelNoCancelWithNoObservers() {
        let expectation: XCTestExpectation
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
            expectation = XCTestExpectation(onError: promise, expectedError: "foo")
        }
        // promise has gone away, but won't have cancelled
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testPropagateCancelMap() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
            let promise2 = promise.map(on: .utility, { (x) -> Int in
                XCTFail("callback invoked")
                return 42
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelFlatMap() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
            let promise2 = promise.flatMap(on: .utility, { (x) -> Promise<String,String> in
                XCTFail("callback invoked")
                return Promise(fulfilled: "foo")
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropgateCancelCatch() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let promise2 = promise.catch(on: .utility, { (error) in
                XCTFail("callback invoked")
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelRecover() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let promise2 = promise.recover(on: .utility, { (error) in
                XCTFail("callback invoked")
                return 42
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelMapError() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let promise2 = promise.mapError(on: .utility, { (error) -> Int in
                XCTFail("callback invoked")
                return 42
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelFlatMapError() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let promise2 = promise.flatMapError(on: .utility, { (error) -> Promise<Int,String> in
                XCTFail("callback invoked")
                return Promise(fulfilled: 42)
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryMapErrorThrowing() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            struct DummyError: Error {}
            let promise2 = promise.tryMapError(on: .default, { (error) -> DummyError in
                XCTFail("callback invoked")
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelAlways() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let alwaysExpectation = XCTestExpectation(description: "always handler")
            let promise2 = promise.always(on: .default, { (result) in
                XCTAssertEqual(result, .cancelled)
                alwaysExpectation.fulfill()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2), alwaysExpectation]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelMapResult() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let promise2 = promise.mapResult(on: .utility, { (result) -> PromiseResult<String,Int> in
                XCTAssertEqual(result, .cancelled)
                return .value("foo")
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onSuccess: promise2, handler: { _ in })]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelFlatMapResult() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let promise2 = promise.flatMapResult(on: .utility, { (result) -> Promise<String,Int> in
                XCTAssertEqual(result, .cancelled)
                return Promise(fulfilled: "foo")
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onSuccess: promise2, handler: { _ in })]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelOnCancel() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let cancelExpectation = XCTestExpectation(description: "onCancel")
            let promise2 = promise.onCancel(on: .utility, {
                cancelExpectation.fulfill()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2), cancelExpectation]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryFlatMapResultThrowing() {
        struct DummyError: Swift.Error {}
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let promise2 = promise.tryFlatMapResult(on: .utility, { (result) -> Promise<String,DummyError> in
                XCTAssertEqual(result, .cancelled)
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onError: promise2, handler: { _ in })]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryFlatMapResultWithSwiftErrorThrowing() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: Promise<Int,String>
            (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
            let promise2 = promise.tryFlatMapResult(on: .utility, { (result) -> Promise<String,Swift.Error> in
                XCTAssertEqual(result, .cancelled)
                struct DummyError: Swift.Error {}
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onError: promise2, handler: { _ in })]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryThenThrowing() {
        struct DummyError: Swift.Error {}
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: StdPromise<Int>
            (promise, sema) = StdPromise<Int>.makeCancellablePromise(error: DummyError())
            let promise2 = promise.tryThen(on: .default, { (_) in
                XCTFail("callback invoked")
                struct DummyError: Swift.Error {}
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryMapThrowing() {
        struct DummyError: Swift.Error {}
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: StdPromise<Int>
            (promise, sema) = StdPromise<Int>.makeCancellablePromise(error: DummyError())
            let promise2 = promise.tryMap(on: .utility, { (_) -> String in
                XCTFail("callback invoked")
                struct DummyError: Swift.Error {}
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryFlatMapWithSwiftErrorThrowing() {
        struct DummyError: Swift.Error {}
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: StdPromise<Int>
            (promise, sema) = StdPromise<Int>.makeCancellablePromise(error: DummyError())
            let promise2 = promise.tryFlatMap(on: .utility, { (_) -> StdPromise<String> in
                XCTFail("callback invoked")
                struct DummyError: Swift.Error {}
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryFlatMapThrowing() {
        struct DummyError: Swift.Error {}
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: StdPromise<Int>
            (promise, sema) = StdPromise<Int>.makeCancellablePromise(error: DummyError())
            let promise2 = promise.tryFlatMap(on: .utility, { (_) -> Promise<Int,DummyError> in
                XCTFail("callback invoked")
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryRecoverThrowing() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: StdPromise<Int>
            (promise, sema) = StdPromise<Int>.makeCancellablePromise(value: 2)
            let promise2 = promise.tryRecover(on: .utility, { (_) -> Int in
                XCTFail("callback invoked")
                struct DummyError: Swift.Error {}
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryFlatMapErrorWithSwiftErrorThrowing() {
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: StdPromise<Int>
            (promise, sema) = StdPromise<Int>.makeCancellablePromise(value: 2)
            let promise2 = promise.tryFlatMapError(on: .utility, { (_) -> StdPromise<Int> in
                XCTFail("callback invoked")
                struct DummyError: Swift.Error {}
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelTryFlatMapErrorThrowing() {
        struct DummyError: Swift.Error {}
        let expectations: [XCTestExpectation]
        let sema: DispatchSemaphore
        do {
            let promise: StdPromise<Int>
            (promise, sema) = StdPromise<Int>.makeCancellablePromise(value: 2)
            let promise2 = promise.tryFlatMapError(on: .utility, { (_) -> Promise<Int,DummyError> in
                XCTFail("callback invoked")
                throw DummyError()
            })
            expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testPropagateCancelDelayedPromise() {
        let expectations: [XCTestExpectation]
        let sema = DispatchSemaphore(value: 0)
        do {
            let delayedPromise = DelayedPromise<Int,String>(on: .utility, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    resolver.cancel()
                })
                sema.wait()
                resolver.reject(with: "foo")
            })
            let promise2 = delayedPromise.promise.then(on: .utility, { (x) in
                XCTFail("callback invoked")
            })
            expectations = [XCTestExpectation(onCancel: delayedPromise.promise), XCTestExpectation(onCancel: promise2)]
            promise2.requestCancel()
        }
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
}

private extension Promise {
    static func makeCancellablePromise(value: Value) -> (Promise, DispatchSemaphore) {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Value,Error>(on: .immediate, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            DispatchQueue.global(qos: .utility).async {
                sema.wait()
                resolver.fulfill(with: value)
            }
        })
        return (promise, sema)
    }
    
    static func makeCancellablePromise(error: Error) -> (Promise, DispatchSemaphore) {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Value,Error>(on: .immediate, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            DispatchQueue.global(qos: .utility).async {
                sema.wait()
                resolver.reject(with: error)
            }
        })
        return (promise, sema)
    }
}
