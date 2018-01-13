//
//  PromiseTests.swift
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 12/12/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Tomorrowland

#if swift(>=4.1)
// For Codable test
import class Foundation.JSONEncoder
import class Foundation.JSONDecoder
import struct Foundation.Data
#endif

final class PromiseTests: XCTestCase {
    func testBasicFulfill() {
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        })
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(promise.result, .value(42))
    }
    
    func testBasicReject() {
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.reject(with: "error")
        })
        let expectation = XCTestExpectation(onError: promise, expectedError: "error")
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(promise.result, .error("error"))
    }
    
    func testBasicCancel() {
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.cancel()
        })
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
    }
    
    func testBasicResolve() {
        let promise1 = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.resolve(with: .value(42))
        })
        let expectation1 = XCTestExpectation(onSuccess: promise1, expectedValue: 42)
        let promise2 = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.resolve(with: .error("foo"))
        })
        let expectation2 = XCTestExpectation(onError: promise2, expectedError: "foo")
        let promise3 = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.resolve(with: .cancelled)
        })
        let expectation3 = XCTestExpectation(onCancel: promise3)
        wait(for: [expectation1, expectation2, expectation3], timeout: 1)
    }
    
    func testAlreadyFulfilled() {
        let promise = Promise<Int,String>(fulfilled: 42)
        XCTAssertEqual(promise.result, .value(42))
        var invoked = false
        _ = promise.then(on: .immediate) { (x) in
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
    
    func testAlreadyRejected() {
        let promise = Promise<Int,String>(rejected: "foo")
        XCTAssertEqual(promise.result, .error("foo"))
        var invoked = false
        _ = promise.catch(on: .immediate) { (x) in
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
    
    func testThenResult() {
        let promise = Promise<Int,String>(fulfilled: 42).then(on: .utility) { (x) in
            return x + 1
        }
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 43)
        wait(for: [expectation], timeout: 1)
    }
    
    func testThenReturningFulfilledPromise() {
        let innerExpectation = XCTestExpectation(description: "Inner promise success")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        }).then(on: .utility) { (x) -> Promise<String,String> in
            let newPromise = Promise<String,String>(on: .utility) { resolver in
                resolver.fulfill(with: "\(x+1)")
            }
            innerExpectation.fulfill(onSuccess: newPromise, expectedValue: "43")
            return newPromise
        }
        let outerExpectation = XCTestExpectation(onSuccess: promise, expectedValue: "43")
        wait(for: [innerExpectation, outerExpectation], timeout: 1)
    }
    
    func testThenReturningRejectedPromise() {
        let innerExpectation = XCTestExpectation(description: "Inner promise error")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        }).then(on: .utility) { (x) -> Promise<String,String> in
            let newPromise = Promise<String,String>(on: .utility) { resolver in
                resolver.reject(with: "foo")
            }
            innerExpectation.fulfill(onError: newPromise, expectedError: "foo")
            return newPromise
        }
        let outerExpectation = XCTestExpectation(onError: promise, expectedError: "foo")
        wait(for: [innerExpectation, outerExpectation], timeout: 1)
    }
    
    func testThenReturningCancelledPromise() {
        let innerExpectation = XCTestExpectation(description: "Inner promise cancelled")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        }).then(on: .utility) { (x) -> Promise<String,String> in
            let newPromise = Promise<String,String>(on: .utility) { resolver in
                resolver.cancel()
            }
            innerExpectation.fulfill(onCancel: newPromise)
            return newPromise
        }
        let outerExpectation = XCTestExpectation(onCancel: promise)
        wait(for: [innerExpectation, outerExpectation], timeout: 1)
    }
    
    func testPromiseCallbackOrder() {
        let queue = DispatchQueue(label: "test queue")
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        })
        var resolved = 0
        let expectations = (0..<10).map({ i in
            return XCTestExpectation(on: .queue(queue), onSuccess: promise, handler: { (x) in
                XCTAssertEqual(i, resolved, "callbacks invoked out of order")
                resolved += 1
                XCTAssertEqual(x, 42)
            })
        })
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testThenReturningPreFulfilledPromise() {
        let promise = Promise<Int,String>(fulfilled: 42).then(on: .immediate) { (x) in
            return Promise(fulfilled: "\(x)")
        }
        XCTAssertEqual(promise.result, .value("42"))
        var invoked = false
        _ = promise.then(on: .immediate) { (x) in
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
    
    func testCatch() {
        let expectation = XCTestExpectation(description: "catch")
        _ = Promise<Int,String>(rejected: "foo").catch(on: .utility, { (x) in
            XCTAssertEqual(x, "foo")
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testRecover() {
        let promise = Promise<Int,String>(rejected: "foo").recover(on: .utility, { (x) in
            return 42
        })
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [expectation], timeout: 1)
    }
    
    func testRecoverReturningPromise() {
        let promise = Promise<Int,String>(rejected: "foo").recover(on:. utility, { (x) in
            return Promise(rejected: true)
        })
        let expectation = XCTestExpectation(onError: promise, expectedError: true)
        wait(for: [expectation], timeout: 1)
    }
    
    func testOnCancel() {
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.cancel()
        })
        let expectation = XCTestExpectation(description: "promise cancel")
        promise.onCancel(on: .utility, {
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testAlwaysReturningThrowingPromise() {
        struct DummyError: Error {}
        let promise = Promise<Int,Int>(on: .utility, { (resolver) in
            resolver.reject(with: 42)
        }).tryAlways(on: .utility, { (result) -> Promise<String,DummyError> in
            throw DummyError()
        })
        let expectation = XCTestExpectation(onError: promise, handler: { (error) in
            XCTAssert(error is DummyError)
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testAlwaysReturningSwiftErrorThrowingPromise() {
        struct DummyError: Error {}
        let promise = Promise<Int,Int>(on: .utility, { (resolver) in
            resolver.reject(with: 42)
        }).tryAlways(on: .utility, { (result) -> Promise<String,Swift.Error> in
            throw DummyError()
        })
        let expectation = XCTestExpectation(onError: promise, handler: { (error) in
            XCTAssert(error is DummyError)
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testAlwaysReturningPromise() {
        let innerExpectation = XCTestExpectation(description: "Inner promise success")
        let promise = Promise<Int,Int>(on: .utility, { (resolver) in
            resolver.reject(with: 42)
        }).always(on: .utility, { (result) -> Promise<String,String> in
            let newPromise = Promise<String,String>(on: .utility) { resolver in
                switch result {
                case .value(let x), .error(let x):
                    resolver.fulfill(with: "\(x+1)")
                case .cancelled:
                    resolver.fulfill(with: "")
                }
            }
            innerExpectation.fulfill(onSuccess: newPromise, expectedValue: "43")
            return newPromise
        })
        let outerExpectation = XCTestExpectation(onSuccess: promise, expectedValue: "43")
        wait(for: [innerExpectation, outerExpectation], timeout: 1)
    }
    
    func testUpcast() {
        struct DummyError: Error {}
        let promise = Promise<Int,DummyError>(rejected: DummyError())
        let expectation = XCTestExpectation(onError: promise.upcast) { (error) in
            XCTAssert(error is DummyError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    // MARK: - Specializations for Error
    
    struct TestError: Error {}
    
    func testPromiseThrowingError() {
        let promise = Promise<Int,Error>(on: .utility, { (resolver) in
            throw TestError()
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testPromiseThenThrowingError() {
        let promise = Promise<Int,Error>(fulfilled: 42).tryThen(on: .utility, { (x) -> Int in
            throw TestError()
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testPromiesThenThrowableReturningPromise() {
        func handler(_ x: Int) throws -> Promise<String,Error> {
            return Promise(rejected: TestError())
        }
        let promise = Promise<Int,Error>(fulfilled: 42).tryThen(on: .utility, { (x) in
            // Don't replace this block literal with handler directly, this tests to make sure we
            // can infer the call without specifying a return type
            return try handler(x)
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testPromiesThenThrowableReturningErrorCompatiblePromise() {
        func handler(_ x: Int) throws -> Promise<String,TestError> {
            return Promise(rejected: TestError())
        }
        let promise = Promise<Int,Error>(fulfilled: 42).tryThen(on: .utility, { (x) in
            // Don't replace this block literal with handler directly, this tests to make sure we
            // can infer the call without specifying a return type
            return try handler(x)
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testPromiseRecoverThrowingError() {
        struct DummyError: Error {}
        let promise = Promise<Int,Error>(rejected: DummyError()).tryRecover(on: .utility, { (error) -> Int in
            throw TestError()
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testPromiseRecoverThrowableReturningPromise() {
        struct DummyError: Error {}
        func handler(_ error: Error) throws -> Promise<Int,Error> {
            return Promise(rejected: TestError())
        }
        let promise = Promise<Int,Error>(rejected: DummyError()).tryRecover(on: .utility, { (error) in
            // Don't replace this block literal with handler directly, this tests to make sure we
            // can infer the call without specifying a return type
            return try handler(error)
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testPromiseRecoverThrowableReturningErrorCompatiblePromise() {
        struct DummyError: Error {}
        func handler(_ error: Error) throws -> Promise<Int,TestError> {
            return Promise(rejected: TestError())
        }
        let promise = Promise<Int,Error>(rejected: DummyError()).tryRecover(on: .utility, { (error) in
            // Don't replace this block literal with handler directly, this tests to make sure we
            // can infer the call without specifying a return type
            return try handler(error)
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    // MARK: -
    
    func testPromiseContexts() {
        var expectations: [XCTestExpectation] = []
        let mainExpectation = XCTestExpectation(description: "main context")
        _ = Promise<Int,String>(on: .main, { (resolver) in
            XCTAssertTrue(Thread.isMainThread)
            mainExpectation.fulfill()
            resolver.fulfill(with: 42)
        })
        expectations.append(mainExpectation)
        let bgContexts: [PromiseContext] = [.background, .utility, .default, .userInitiated, .userInteractive]
        expectations.append(contentsOf: bgContexts.map({ context in
            let expectation = XCTestExpectation(description: "\(context) context")
            _ = Promise<Int,String>(on: context, { (resolver) in
                XCTAssertFalse(Thread.isMainThread)
                expectation.fulfill()
                resolver.fulfill(with: 42)
            })
            return expectation
        }))
        do {
            let queue = DispatchQueue(label: "test queue")
            queue.setSpecific(key: testQueueKey, value: "foo")
            let expectation = XCTestExpectation(description: ".queue context")
            _ = Promise<Int,String>(on: .queue(queue), { (resolver) in
                XCTAssertEqual(DispatchQueue.getSpecific(key: testQueueKey), "foo", "test queue key")
                expectation.fulfill()
                resolver.fulfill(with: 42)
            })
            expectations.append(expectation)
        }
        do {
            let queue = OperationQueue()
            queue.name = "test queue"
            let expectation = XCTestExpectation(description: ".operationQueue context")
            _ = Promise<Int,String>(on: .operationQueue(queue), { (resolver) in
                XCTAssertEqual(OperationQueue.current, queue, "operation queue")
                expectation.fulfill()
                resolver.fulfill(with: 42)
            })
            expectations.append(expectation)
        }
        var invoked = false
        _ = Promise<Int,String>(on: .immediate, { (resolver) in
            invoked = true
            resolver.fulfill(with: 42)
        })
        XCTAssertTrue(invoked)
        wait(for: expectations, timeout: 3)
    }
    
    func testAutoPromiseContext() {
        let promise = Promise<Int,String>(fulfilled: 42)
        let expectationMain = XCTestExpectation(description: "main queue")
        DispatchQueue.main.async {
            expectationMain.fulfill(on: .auto, onSuccess: promise, handler: { (_) in
                XCTAssertTrue(Thread.isMainThread)
            })
        }
        let expectationBG = XCTestExpectation(description: "background queue")
        DispatchQueue.global().async {
            expectationBG.fulfill(on: .auto, onSuccess: promise, handler: { (_) in
                XCTAssertFalse(Thread.isMainThread)
            })
        }
        wait(for: [expectationMain, expectationBG], timeout: 1)
    }
    
    func testInvalidationTokenNoInvalidate() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let token = PromiseInvalidationToken()
        let expectation = XCTestExpectation(description: "promise success")
        _ = promise.then(on: .utility, token: token) { (x) in
            XCTAssertEqual(x, 42)
            expectation.fulfill()
        }
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenInvalidate() {
        let sema = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "test queue")
        let token = PromiseInvalidationToken()
        do {
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                sema.wait()
                resolver.fulfill(with: 42)
            })
            let expectation = XCTestExpectation(description: "promise resolved")
            _ = promise.then(on: .queue(queue), token: token, { (x) in
                XCTFail("invalidated callback invoked")
            }).always(on: .queue(queue), { (_) in
                expectation.fulfill()
            })
            token.invalidate()
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // Test reuse
        do {
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                sema.wait()
                resolver.fulfill(with: 44)
            })
            let expectation = XCTestExpectation(description: "promise resolved")
            _ = promise.then(on: .queue(queue), token: token, { (x) in
                XCTFail("invalidated callback invoked")
            }).always(on: .queue(queue), { (_) in
                expectation.fulfill()
            })
            token.invalidate()
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testInvalidationTokenInvalidateChainSuccess() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let token = PromiseInvalidationToken()
        let chainPromise = promise.then(on: .utility, token: token, { (x) in
            XCTFail("invalidated callback invoked")
        })
        let expectation = XCTestExpectation(onCancel: chainPromise)
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenInvalidateChainError() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.reject(with: "foo")
        })
        let token = PromiseInvalidationToken()
        let chainPromise = promise.then(on: .utility, token: token, { (x) in
            XCTFail("invalidated callback invoked")
        })
        let expectation = XCTestExpectation(onError: chainPromise, expectedError: "foo")
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenMultiplePromises() {
        let sema = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "test queue")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let token = PromiseInvalidationToken()
        let expectations = (1...3).map({ x -> XCTestExpectation in
            let expectation = XCTestExpectation(description: "chain promise \(x)")
            promise.then(on: .queue(queue), token: token, { (x) in
                XCTFail("invalidated callback invoked")
            }).always(on: .queue(queue), { _ in
                expectation.fulfill()
            })
            return expectation
        })
        let expectation = XCTestExpectation(description: "non-invalidated chain promise")
        _ = promise.then(on: .queue(queue), { (x) in
            XCTAssertEqual(x, 42)
            expectation.fulfill()
        })
        token.invalidate()
        sema.signal()
        wait(for: expectations + [expectation], timeout: 1)
    }
    
    func testResolvingFulfilledPromise() {
        // Resolving a promise that has already been fulfilled does nothing
        let expectation = XCTestExpectation(description: "promise")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
            resolver.fulfill(with: 43)
            resolver.reject(with: "error")
            resolver.cancel()
            expectation.fulfill()
        })
        let expectation2 = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [expectation, expectation2], timeout: 1)
        // now that the promise is resolved, check again to make sure the value is the same
        XCTAssertEqual(promise.result, .value(42))
    }
    
    func testResolvingRejectedPromise() {
        // Resolving a promise that has already been rejected does nothing
        let expectation = XCTestExpectation(description: "promise")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.reject(with: "error")
            resolver.reject(with: "foobar")
            resolver.fulfill(with: 43)
            resolver.cancel()
            expectation.fulfill()
        })
        let expectation2 = XCTestExpectation(onError: promise, expectedError: "error")
        wait(for: [expectation, expectation2], timeout: 1)
        // now that the promise is resolved, check again to make sure the value is the same
        XCTAssertEqual(promise.result, .error("error"))
    }
    
    func testResolvingCancelledPromise() {
        // Resolving a promise that has already been cancelled does nothing
        let expectation = XCTestExpectation(description: "promise")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.cancel()
            resolver.cancel()
            resolver.reject(with: "foobar")
            resolver.fulfill(with: 43)
            expectation.fulfill()
        })
        let expectation2 = XCTestExpectation(onCancel: promise)
        wait(for: [expectation, expectation2], timeout: 1)
        // now that the promise is resolved, check again to make sure the value is the same
        XCTAssertEqual(promise.result, .cancelled)
    }
    
    func testRequestCancel() {
        let expectation = XCTestExpectation(description: "onRequestCancel")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.onRequestCancel(on: .utility, { (resolver) in
                expectation.fulfill()
                resolver.cancel()
            })
        })
        let expectation2 = XCTestExpectation(onCancel: promise)
        DispatchQueue.global().async {
            promise.requestCancel()
        }
        wait(for: [expectation, expectation2], timeout: 1)
    }
    
    func testMultipleOnRequestCancel() {
        let queue = DispatchQueue(label: "test queue")
        let expectations = (1...3).map({ XCTestExpectation(description: "onRequestCancel \($0)")} )
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            var resolved = 0
            for (i, expectation) in expectations.enumerated() {
                resolver.onRequestCancel(on: .queue(queue), { (resolver) in
                    XCTAssertEqual(resolved, i)
                    resolved += 1
                    expectation.fulfill()
                    resolver.cancel()
                })
            }
            sema.signal()
        })
        DispatchQueue.global().async {
            sema.wait()
            promise.requestCancel()
        }
        wait(for: expectations, timeout: 1)
    }
    
    func testOnRequestCancelAfterCancelled() {
        let sema = DispatchSemaphore(value: 0)
        let expectation = XCTestExpectation(description: "promise")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            var invoked = false
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
                invoked = true
            })
            XCTAssertTrue(invoked)
            expectation.fulfill()
        })
        DispatchQueue.global().async {
            promise.requestCancel()
            sema.signal()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testLeavingPromiseUnresolvedTriggersCancel() {
        let queue = DispatchQueue(label: "test queue")
        let expectations = (1...3).map({ XCTestExpectation(description: "promise \($0) cancel") })
        do {
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                // don't resolve
            })
            for expectation in expectations {
                expectation.fulfill(on: .queue(queue), onCancel: promise)
            }
        }
        wait(for: expectations, timeout: 1, enforceOrder: true)
    }
    
    func testCancellingOuterPromiseCancelsInnerPromise() {
        let innerExpectation = XCTestExpectation(description: "inner promise")
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(fulfilled: 42)
            .then(on: .immediate, { (x) -> Promise<String,String> in
                let innerPromise = Promise<String,String>(on: .utility, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        resolver.cancel()
                    })
                    sema.wait()
                    resolver.fulfill(with: "\(x + 1)")
                })
                innerExpectation.fulfill(onCancel: innerPromise)
                return innerPromise
            })
        let outerExpectation = XCTestExpectation(onCancel: promise)
        promise.requestCancel()
        sema.signal()
        wait(for: [outerExpectation, innerExpectation], timeout: 1)
    }
    
    func testIgnoringCancel() {
        let innerExpectation = XCTestExpectation(description: "inner promise")
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(fulfilled: 42)
            .then(on: .immediate, { (x) -> Promise<String,String> in
                let innerPromise = Promise<String,String>(on: .utility, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        XCTFail("inner promise was cancelled")
                        resolver.cancel()
                    })
                    sema.wait()
                    resolver.fulfill(with: "\(x + 1)")
                }).ignoringCancel()
                innerExpectation.fulfill(onSuccess: innerPromise, expectedValue: "43")
                return innerPromise
            })
        let outerExpectation = XCTestExpectation(onSuccess: promise, expectedValue: "43")
        promise.requestCancel()
        sema.signal()
        wait(for: [outerExpectation, innerExpectation], timeout: 1)
    }
    
    func testChainedMainContextCallbacks() {
        class RunloopObserver {
            var invoked = false
            private var _observer: CFRunLoopObserver?
            
            init() {
                _observer = nil
                _observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, 0, { [weak self] (observer, activity) in
                    self?.invoked = true
                })
                CFRunLoopAddObserver(RunLoop.main.getCFRunLoop(), _observer, CFRunLoopMode.commonModes)
            }
            
            deinit {
                if let observer = _observer {
                    _observer = nil
                    CFRunLoopObserverInvalidate(observer)
                }
            }
        }
        
        // When chaining callbacks on the main context, they should all invoke within the same
        // runloop pass.
        do {
            let expectation = XCTestExpectation(description: "done")
            DispatchQueue.main.async { // tests should be on the main queue already, but just in case
                let observer = RunloopObserver()
                var initialDelayed = false
                // Ensure order is preserved. This really only applies to the catch/recover pair
                var order = 0
                Promise<Int,String>(on: .main, { (resolver) in
                    XCTAssertTrue(initialDelayed) // this block shouldn't be immediate
                    observer.invoked = false
                    resolver.fulfill(with: 42)
                }).then(on: .main, { (x) -> Void in
                    XCTAssertFalse(observer.invoked, "then callback was delayed")
                    XCTAssertEqual(order, 0)
                    order += 1
                    observer.invoked = false
                }).then(on: .main, { (x) -> Int in
                    XCTAssertFalse(observer.invoked, "second then callback was delayed")
                    XCTAssertEqual(order, 1)
                    order += 1
                    observer.invoked = false
                    return 43
                }).then(on: .main, { (x) -> Promise<Int,String> in
                    XCTAssertFalse(observer.invoked, "third then callback was delayed")
                    XCTAssertEqual(order, 2)
                    order += 1
                    observer.invoked = false
                    return Promise(rejected: "error")
                }).catch(on: .main, { (x) in
                    XCTAssertFalse(observer.invoked, "catch callback was delayed")
                    XCTAssertEqual(order, 3)
                    order += 1
                    observer.invoked = false
                }).recover(on: .main, { (x) in
                    XCTAssertFalse(observer.invoked, "recover callback was delayed")
                    XCTAssertEqual(order, 4)
                    order += 1
                    observer.invoked = false
                    return 42
                }).always(on: .main, { (x) -> Promise<Int,String> in
                    XCTAssertFalse(observer.invoked, "always callback was delayed")
                    XCTAssertEqual(order, 5)
                    order += 1
                    observer.invoked = false
                    return Promise.init(fulfilled: 42)
                }).always(on: .main, { (x) -> Void in
                    XCTAssertFalse(observer.invoked, "second always callback was delayed")
                    XCTAssertEqual(order, 6)
                    expectation.fulfill()
                })
                initialDelayed = true
            }
            wait(for: [expectation], timeout: 1)
        }
        
        // Chaining callbacks on .queue(.main) shouldn't have this behavior.
        do {
            let expectation = XCTestExpectation(description: "done")
            DispatchQueue.main.async {
                let observer = RunloopObserver()
                var initialDelayed = false
                Promise<Int,String>(on: .queue(.main), { (resolver) in
                    XCTAssertTrue(initialDelayed) // this block shouldn't be immediate
                    observer.invoked = false
                    resolver.fulfill(with: 42)
                }).then(on: .queue(.main), { (x) -> Int in
                    XCTAssertTrue(observer.invoked, "then callback wasn't delayed")
                    observer.invoked = false
                    return x+1
                }).then(on: .queue(.main), { (x) -> Promise<Int,String> in
                    XCTAssertTrue(observer.invoked, "second then callback wasn't delayed")
                    observer.invoked = false
                    return Promise(rejected: "error")
                }).catch(on: .queue(.main), { (x) in
                    XCTAssertTrue(observer.invoked, "catch callback wasn't delayed")
                    observer.invoked = false
                }).recover(on: .queue(.main), { (x) in
                    XCTAssertTrue(observer.invoked, "recover callback wasn't delayed")
                    observer.invoked = false
                    return 42
                }).always(on: .queue(.main), { (x) in
                    XCTAssertTrue(observer.invoked, "always callback wasn't delayed")
                    expectation.fulfill()
                })
                initialDelayed = true
            }
            wait(for: [expectation], timeout: 1)
        }
        
        // Chaining between .main and .queue(.main) should also not have this behavior
        do {
            let expectation = XCTestExpectation(description: "done")
            DispatchQueue.main.async {
                let observer = RunloopObserver()
                Promise<Int,String>(on: .main, { (resolver) in
                    observer.invoked = false
                    resolver.fulfill(with: 42)
                }).then(on: .main, { (x) -> Int in
                    XCTAssertFalse(observer.invoked, "then callback was delayed")
                    observer.invoked = false
                    return x+1
                }).then(on: .queue(.main), { (x) -> Int in
                    XCTAssertTrue(observer.invoked, "second then callback wasn't delayed")
                    observer.invoked = false
                    return x+1
                }).then(on: .main, { (x) -> Int in
                    XCTAssertTrue(observer.invoked, "third then callback wasn't delayed")
                    observer.invoked = false
                    return x+1
                }).always(on: .queue(.main), { (x) in
                    XCTAssertTrue(observer.invoked, "always callback wasn't delayed")
                    expectation.fulfill()
                })
            }
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testChainedMainContextCallbacksArentImmediate() {
        // Ensure that chained main context callbacks aren't treated as .immediate but instead wait
        // until the existing work actually finished.
        let expectation = XCTestExpectation(description: "done")
        var finishedWork = false
        _ = Promise<Int,String>(on: .main, { (resolver) in
            resolver.fulfill(with: 42)
            finishedWork = true
        }).then(on: .main, { (x) in
            XCTAssertTrue(finishedWork)
        }).always(on: .main, { (result) in
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testResolverHandleCallback() {
        let promise1 = StdPromise<Int>(on: .utility, { (resolver) in
            resolver.handleCallback()(42, nil)
        })
        let expectation1 = XCTestExpectation(onSuccess: promise1, expectedValue: 42)
        struct DummyError: Error {}
        let promise2 = StdPromise<Int>(on: .utility, { (resolver) in
            resolver.handleCallback()(nil, DummyError())
        })
        let expectation2 = XCTestExpectation(onError: promise2, handler: { (error) in
            XCTAssert(error is DummyError)
        })
        let promise3 = StdPromise<Int>(on: .utility, { (resolver) in
            resolver.handleCallback()(42, DummyError())
        })
        let expectation3 = XCTestExpectation(onSuccess: promise3, expectedValue: 42)
        let promise4 = StdPromise<Int>(on: .utility, { (resolver) in
            resolver.handleCallback()(nil, nil)
        })
        let expectation4 = XCTestExpectation(onError: promise4, handler: { (error) in
            switch error {
            case PromiseCallbackError.apiMismatch: break
            default: XCTFail("Expected PromiseCallbackError.apiMismatch, found \(error)")
            }
        })
        let promise5 = StdPromise<Int>(on: .utility, { (resolver) in
            resolver.handleCallback(isCancelError: { $0 is DummyError })(nil, DummyError())
        })
        let expectation5 = XCTestExpectation(onCancel: promise5)
        wait(for: [expectation1, expectation2, expectation3, expectation4, expectation5], timeout: 1)
    }
}

final class PromiseResultTests: XCTestCase {
    func testValue() {
        XCTAssertEqual(PromiseResult<Int,String>.value(42).value, 42)
        XCTAssertNil(PromiseResult<Int,String>.error("wat").value)
        XCTAssertNil(PromiseResult<Int,String>.cancelled.value)
    }
    
    func testError() {
        XCTAssertNil(PromiseResult<Int,String>.value(42).error)
        XCTAssertEqual(PromiseResult<Int,String>.error("wat").error, "wat")
        XCTAssertNil(PromiseResult<Int,String>.cancelled.error)
    }
    
    func testIsCancelled() {
        XCTAssertFalse(PromiseResult<Int,String>.value(42).isCancelled)
        XCTAssertFalse(PromiseResult<Int,String>.error("wat").isCancelled)
        XCTAssertTrue(PromiseResult<Int,String>.cancelled.isCancelled)
    }
    
    func testMap() {
        XCTAssertEqual(PromiseResult<Int,String>.value(42).map({ $0 + 1 }), .value(43))
        XCTAssertEqual(PromiseResult<Int,String>.error("wat").map({ $0 + 1 }), .error("wat"))
        XCTAssertEqual(PromiseResult<Int,String>.cancelled.map({ $0 + 1 }), .cancelled)
    }
    
    func testMapError() {
        XCTAssertEqual(PromiseResult<Int,String>.value(42).mapError({ $0 + "bar" }), .value(42))
        XCTAssertEqual(PromiseResult<Int,String>.error("foo").mapError({ $0 + "bar" }), .error("foobar"))
        XCTAssertEqual(PromiseResult<Int,String>.cancelled.mapError({ $0 + "bar" }), .cancelled)
    }
    
    func testFlatMap() {
        XCTAssertEqual(PromiseResult<Int,String>.value(42).flatMap({ PromiseResult<String,String>.value("\($0)") }), .value("42"))
        XCTAssertEqual(PromiseResult<Int,String>.error("wat").flatMap({ PromiseResult<String,String>.value("\($0)") }), .error("wat"))
        XCTAssertEqual(PromiseResult<Int,String>.cancelled.flatMap({ PromiseResult<String,String>.value("\($0)") }), .cancelled)
    }
    
    func testFlatMapError() {
        XCTAssertEqual(PromiseResult<Int,String>.value(42).flatMapError({ PromiseResult<Int,Int>.error($0.count) }), .value(42))
        XCTAssertEqual(PromiseResult<Int,String>.error("foo").flatMapError({ PromiseResult<Int,Int>.error($0.count) }), .error(3))
        XCTAssertEqual(PromiseResult<Int,String>.cancelled.flatMapError({ PromiseResult<Int,Int>.error($0.count) }), .cancelled)
    }
    
    #if swift(>=4.1)
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        do {
            let result = PromiseResult<Int,String>.value(42)
            let data = try encoder.encode(result)
            let decoded = try decoder.decode(PromiseResult<Int,String>.self, from: data)
            XCTAssertEqual(decoded, result)
        }
        do {
            let result = PromiseResult<Int,String>.error("wat")
            let data = try encoder.encode(result)
            let decoded = try decoder.decode(PromiseResult<Int,String>.self, from: data)
            XCTAssertEqual(decoded, result)
        }
        do {
            let result = PromiseResult<Int,String>.cancelled
            let data = try encoder.encode(result)
            let decoded = try decoder.decode(PromiseResult<Int,String>.self, from: data)
            XCTAssertEqual(decoded, result)
        }
    }
    #endif
}

private let testQueueKey = DispatchSpecificKey<String>()
