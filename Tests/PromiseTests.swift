//
//  PromiseTests.swift
//  TomorrowlandTests
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

import XCTest
import Tomorrowland

// For Codable test
import class Foundation.JSONEncoder
import class Foundation.JSONDecoder
import struct Foundation.Data

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
    
    #if compiler(>=5)
    func testBasicResolveWithSwiftResult() {
        let promise1 = Promise<Int,Error>(on: .utility, { (resolver) in
            resolver.resolve(with: .success(42))
        })
        let expectation1 = XCTestExpectation(onSuccess: promise1, expectedValue: 42)
        enum MyError: Error, Equatable { case foo }
        let promise2 = Promise<Int,MyError>(on: .utility, { (resolver) in
            resolver.resolve(with: .failure(MyError.foo))
        })
        let expectation2 = XCTestExpectation(onError: promise2, expectedError: MyError.foo)
        wait(for: [expectation1, expectation2], timeout: 1)
    }
    #endif
    
    func testResolveWithPromise() {
        let expectations = [
            XCTestExpectation(onSuccess: Promise<Int,String>(on: .utility, { (resolver) in
                resolver.resolve(with: Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: 42)
                }))
            }), expectedValue: 42),
            XCTestExpectation(onError: Promise<Int,String>(on: .default, { (resolver) in
                resolver.resolve(with: Promise(on: .default, { (resolver) in
                    resolver.reject(with: "foo")
                }))
            }), expectedError: "foo"),
            XCTestExpectation(onCancel: Promise<Int,String>(on: .default, { (resolver) in
                resolver.resolve(with: Promise(on: .default, { (resolver) in
                    resolver.cancel()
                }))
            }))
        ]
        wait(for: expectations, timeout: 1)
    }
    
    func testResolveWithPromiseAlreadyResolved() {
        let (promise, resolver) = Promise<Int,String>.makeWithResolver()
        let currentThread = Thread.current
        let expectation = XCTestExpectation(description: "promise resolution")
        promise.always(on: .immediate, { (result) in
            XCTAssert(Thread.current == currentThread, "Promise resolved on another thread")
            XCTAssertEqual(result, .value(42))
            expectation.fulfill()
        })
        resolver.resolve(with: Promise(fulfilled: 42))
        wait(for: [expectation], timeout: 0)
    }
    
    func testResolveWithPromiseCancelPropagation() {
        let sema = DispatchSemaphore(value: 0)
        let innerCancelExpectation = XCTestExpectation(description: "inner promise cancelled")
        let promise = Promise<Int,String>(on: .immediate, { (resolver) in
            resolver.resolve(with: Promise(on: .default, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    resolver.cancel()
                    innerCancelExpectation.fulfill()
                })
                sema.wait()
                resolver.fulfill(with: 42)
            }))
        })
        let outerCancelExpectation = XCTestExpectation(onCancel: promise)
        XCTAssertNil(promise.result)
        promise.requestCancel()
        sema.signal()
        wait(for: [innerCancelExpectation, outerCancelExpectation], timeout: 1)
        XCTAssertEqual(promise.result, .cancelled)
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
    
    func testAlreadyFulfilledWithResult() {
        let promise = Promise<Int,String>(with: .value(42))
        XCTAssertEqual(promise.result, .value(42))
        var invoked = false
        _ = promise.then(on: .immediate) { (x) in
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
    
    func testAlreadyRejectedWithResult() {
        let promise = Promise<Int,String>(with: .error("foo"))
        XCTAssertEqual(promise.result, .error("foo"))
        var invoked = false
        _ = promise.catch(on: .immediate) { (x) in
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
    
    func testAlreadyCancelledWithResult() {
        let promise = Promise<Int,String>(with: .cancelled)
        XCTAssertEqual(promise.result, .cancelled)
        var invoked = false
        _ = promise.onCancel(on: .immediate) {
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
    
    #if compiler(>=5)
    func testAlreadyFulfilledWithSwiftResult() {
        enum MyError: Error, Equatable { case foo }
        let promise = Promise<Int,MyError>(with: .success(42))
        XCTAssertEqual(promise.result, .value(42))
        var invoked = false
        _ = promise.then(on: .immediate) { (x) in
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
    
    func testAlreadyRejectedWithSwiftResult() {
        enum MyError: Error, Equatable { case foo }
        let promise = Promise<Int,MyError>(with: .failure(MyError.foo))
        XCTAssertEqual(promise.result, .error(MyError.foo))
        var invoked = false
        _ = promise.catch(on: .immediate) { (x) in
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
    #endif
    
    func testThen() {
        let thenExpectation = XCTestExpectation(description: "then handler invoked")
        let promise = Promise<Int,String>(fulfilled: 42).then(on: .utility) { (x) in
            XCTAssertEqual(x, 42)
            thenExpectation.fulfill()
        }
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [thenExpectation, expectation], timeout: 1)
    }
    
    func checkThenSingleExpressionElidingReturnValue() {
        // If the closure passed to then() is a single-expression closure that evaluates to a
        // non-Void value, this was getting mapped to the deprecated version instead of throwing
        // away the return value. Adding an explicit `-> ()` type signature suppressed this, but
        // shouldn't have been necessary. This code ensures the ideal code evaluates properly.
        // If it doesn't, the compiler will throw an error.
        let dummy: ((Int) -> Void)? = { _ in }
        let promise = Promise<Int,String>(fulfilled: 42).then({ dummy?($0) })
        let _: Promise<Int,String> = promise
    }
    
    func testThenReturnsDistinctPromise() {
        // Ensure `then` always returns a distinct promise. This is important so cancelling the
        // result of `then` doesn't necessarily cancel the original promise.
        let promise = Promise<Int,String>(fulfilled: 42)
        let promise2 = promise.then(on: .immediate, { _ in })
        XCTAssertNotEqual(promise, promise2)
    }
    
    func testMap() {
        let promise = Promise<Int,String>(fulfilled: 42).map(on: .utility) { (x) in
            return x + 1
        }
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 43)
        wait(for: [expectation], timeout: 1)
    }
    
    func testFlatMapReturningFulfilled() {
        let innerExpectation = XCTestExpectation(description: "Inner promise success")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        }).flatMap(on: .utility) { (x) -> Promise<String,String> in
            let newPromise = Promise<String,String>(on: .utility) { resolver in
                resolver.fulfill(with: "\(x+1)")
            }
            innerExpectation.fulfill(onSuccess: newPromise, expectedValue: "43")
            return newPromise
        }
        let outerExpectation = XCTestExpectation(onSuccess: promise, expectedValue: "43")
        wait(for: [innerExpectation, outerExpectation], timeout: 1)
    }
    
    func testFlatMapReturningRejected() {
        let innerExpectation = XCTestExpectation(description: "Inner promise error")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        }).flatMap(on: .utility) { (x) -> Promise<String,String> in
            let newPromise = Promise<String,String>(on: .utility) { resolver in
                resolver.reject(with: "foo")
            }
            innerExpectation.fulfill(onError: newPromise, expectedError: "foo")
            return newPromise
        }
        let outerExpectation = XCTestExpectation(onError: promise, expectedError: "foo")
        wait(for: [innerExpectation, outerExpectation], timeout: 1)
    }
    
    func testFlatMapReturningCancelled() {
        let innerExpectation = XCTestExpectation(description: "Inner promise cancelled")
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        }).flatMap(on: .utility) { (x) -> Promise<String,String> in
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
    
    func testFlatMapReturningPreFulfilled() {
        let promise = Promise<Int,String>(fulfilled: 42).flatMap(on: .immediate) { (x) in
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
    
    func testMapError() {
        let promise = Promise<Int,String>(rejected: "foo").mapError(on: .default, { (x) in
            return 123
        })
        let expectation = XCTestExpectation(onError: promise, expectedError: 123)
        wait(for: [expectation], timeout: 1)
    }
    
    func testFlatMapError() {
        let promise = Promise<Int,String>(rejected: "foo").flatMapError(on: .utility, { (x) in
            return Promise(rejected: true)
        })
        let expectation = XCTestExpectation(onError: promise, expectedError: true)
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryMapErrorThrowing() {
        struct DummyError: Error {}
        let promise = Promise<Int,Int>(on: .utility, { (resolver) in
            resolver.reject(with: 42)
        }).tryMapError(on: .default, { (x) -> Error in
            throw DummyError()
        })
        let expectation = XCTestExpectation(onError: promise, handler: { (error) in
            XCTAssert(error is DummyError)
        })
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
    
    func testAlways() {
        let expectation = XCTestExpectation(description: "promise resolver")
        Promise<String,Int>(on: .utility, { (resolver) in
            resolver.reject(with: 42)
        }).always(on: .utility, { (result) -> Void in
            switch result {
            case .value(let value):
                XCTFail("unexpected promise fulfill with \(value), expected rejection with 42")
            case .error(let error):
                XCTAssertEqual(error, 42)
            case .cancelled:
                XCTFail("unexpected promise cancel, expected rejection with 42")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testAlwaysReturnsDistinctPromise() {
        // Ensure `always` always returns a distinct promise. This is important so cancelling the
        // result of `always` doesn't necessarily cancel the original promise.
        let promise = Promise<Int,String>(fulfilled: 42)
        let promise2 = promise.always(on: .immediate, { _ in })
        XCTAssertNotEqual(promise, promise2)
    }
    
    func testMapResult() {
        let promise = Promise<Int,String>(on: .default, { (resolver) in
            resolver.reject(with: "foo")
        }).mapResult(on: .default, { (result) -> PromiseResult<String,Int> in
            switch result {
            case .value(let x): return .error(x+1)
            case .error(let x): return .value("\(x)bar")
            case .cancelled: return .value("cancel")
            }
        })
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: "foobar")
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryFlatMapResultThrowing() {
        struct DummyError: Error {}
        let promise = Promise<Int,Int>(on: .utility, { (resolver) in
            resolver.reject(with: 42)
        }).tryFlatMapResult(on: .utility, { (result) -> Promise<String,DummyError> in
            throw DummyError()
        })
        let expectation = XCTestExpectation(onError: promise, handler: { (error) in
            XCTAssert(error is DummyError)
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryFlatMapResultWithSwiftErrorThrowing() {
        struct DummyError: Error {}
        let promise = Promise<Int,Int>(on: .utility, { (resolver) in
            resolver.reject(with: 42)
        }).tryFlatMapResult(on: .utility, { (result) -> Promise<String,Swift.Error> in
            throw DummyError()
        })
        let expectation = XCTestExpectation(onError: promise, handler: { (error) in
            XCTAssert(error is DummyError)
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testFlatMapResult() {
        let innerExpectation = XCTestExpectation(description: "Inner promise success")
        let promise = Promise<Int,Int>(on: .utility, { (resolver) in
            resolver.reject(with: 42)
        }).flatMapResult(on: .utility, { (result) -> Promise<String,String> in
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
    
    // MARK: -
    
    func testPropagatingCancellation() {
        let requestExpectation = XCTestExpectation(description: "Cancel requested on root")
        let childExpectation = XCTestExpectation(description: "Cancel requested on child")
        let notYetExpectation = XCTestExpectation(description: "Cancel requested on child too early")
        notYetExpectation.isInverted = true
        let childPromise: Promise<Int,String>
        do { // scope rootPromise
            let rootPromise = Promise<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate) { (_) in // retain resolver to keep the promise alive until cancelled
                    requestExpectation.fulfill()
                    resolver.cancel()
                }
            })
            var blockChildPromise: Promise<Int,String>?
            childPromise = rootPromise.propagatingCancellation(on: .immediate, cancelRequested: { (promise) in
                XCTAssertEqual(promise, blockChildPromise, "Promise passed to cancelRequested isn't the same as what was returned")
                // Note: We can only wait on an expectation once, so we trigger multiple here for testing at different points.
                childExpectation.fulfill()
                notYetExpectation.fulfill()
            })
            blockChildPromise = childPromise
        }
        let promise1 = childPromise.then(on: .immediate, { _ in })
        let promise2 = childPromise.then(on: .immediate, { _ in })
        promise1.requestCancel()
        guard XCTWaiter(delegate: self).wait(for: [notYetExpectation], timeout: 0) == .completed else {
            XCTFail("Cancel requested on child too early")
            return
        }
        let cancelExpectations = [promise1, promise2].map({ XCTestExpectation(on: .immediate, onCancel: $0) })
        promise2.requestCancel()
        // Everything was marked as immediate, so all cancellation should have happened immediately.
        wait(for: [childExpectation, requestExpectation] + cancelExpectations, timeout: 0, enforceOrder: true)
        
        // Adding new children at this point causes no problems, they're just insta-cancelled.
        let promise3 = childPromise.then(on: .immediate, { _ in })
        XCTAssertEqual(promise3.result, .cancelled)
        
        withExtendedLifetime(childPromise) {} // Ensure childPromise lives to this point
    }
    
    func testPropagatingCancellationNoChildren() {
        let sema = DispatchSemaphore(value: 0)
        let requestExpectation = XCTestExpectation(description: "Cancel requested on root")
        requestExpectation.isInverted = true
        let childExpectation = XCTestExpectation(description: "Cancel requested on child")
        childExpectation.isInverted = true
        let resolvedExpectation = XCTestExpectation(description: "Child promise resolved")
        resolvedExpectation.isInverted = true
        do { // scope childPromise
            let childPromise: Promise<Int,String>
            do { // scope rootPromise
                let rootPromise = Promise<Int,String>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate) { (resolver) in
                        requestExpectation.fulfill()
                        resolver.cancel()
                    }
                    DispatchQueue.global(qos: .utility).async {
                        sema.wait()
                        resolver.fulfill(with: 42)
                    }
                })
                childPromise = rootPromise.propagatingCancellation(on: .immediate, cancelRequested: { _ in
                    childExpectation.fulfill()
                })
            }
            childPromise.tap().always(on: .immediate, { _ in
                resolvedExpectation.fulfill()
            })
        }
        // At this point childPromise and rootPromise are gone, and all callbacks are .immediate.
        // If cancellation was going to propagate, it would have done so already.
        wait(for: [requestExpectation, childExpectation, resolvedExpectation], timeout: 0)
        sema.signal()
    }
    
    func testPropagatingCancelManualRequestCancel() {
        // requestCancel() should behave the same as cancellation propagation with respect to running the callback
        let childExpectation = XCTestExpectation(description: "Cancel requested on child")
        let notYetExpectation = XCTestExpectation(description: "Cancel requested on child too early")
        notYetExpectation.isInverted = true
        let childPromise: Promise<Int,String>
        do { // scope rootPromise
            let rootPromise = Promise<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate) { (_) in // retain resolver to keep the promise alive until cancelled
                    resolver.cancel()
                }
            })
            childPromise = rootPromise.propagatingCancellation(on: .immediate, cancelRequested: { _ in
                // Note: We can only wait on an expectation once, so we trigger multiple here for testing at different points.
                childExpectation.fulfill()
                notYetExpectation.fulfill()
            })
        }
        guard XCTWaiter(delegate: self).wait(for: [notYetExpectation], timeout: 0) == .completed else {
            XCTFail("Cancel requested on child too early")
            return
        }
        childPromise.requestCancel()
        wait(for: [childExpectation], timeout: 0)
    }
    
    func testPropagatingCancellationAsyncCallback() {
        // Test that using an asynchronous cancelRequested callback works as expected.
        let childExpectation = XCTestExpectation(description: "Cancel requested on child")
        let childPromise: Promise<Int,String>
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        do { // scope rootPromise
            let rootPromise = Promise<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { _ in // retain resolver
                    resolver.cancel()
                })
            })
            childPromise = rootPromise.propagatingCancellation(on: .operationQueue(queue), cancelRequested: { _ in
                XCTAssertEqual(OperationQueue.current, queue)
                childExpectation.fulfill()
            })
        }
        childPromise.then(on: .immediate, { _ in }).requestCancel()
        // cancel should already be enqueued on the queue at this point. No need for a timeout
        queue.waitUntilAllOperationsAreFinished()
        wait(for: [childExpectation], timeout: 0)
    }
    
    func testPropagatingCancellationFulfilled() {
        // Just a quick test to ensure propagatingCancellation actually resolves properly too
        let sema = DispatchSemaphore(value: 0)
        let rootPromise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let childPromise = rootPromise.propagatingCancellation(on: .immediate, cancelRequested: { _ in
            XCTFail("Unexpected cancellation")
        })
        let expectation1 = XCTestExpectation(on: .immediate, onSuccess: childPromise, expectedValue: 42)
        expectation1.isInverted = true
        wait(for: [expectation1], timeout: 0)
        let expectation2 = XCTestExpectation(onSuccess: childPromise, expectedValue: 42)
        sema.signal()
        wait(for: [expectation2], timeout: 1)
    }
    
    func testPropagatingCancellationOtherChildrenOfRoot() {
        // Ensure cancellation propagation doesn't ignore other children of the root promise
        let sema = DispatchSemaphore(value: 0)
        let rootPromiseCancelExpectation = XCTestExpectation(description: "Cancel requested on root promise")
        rootPromiseCancelExpectation.isInverted = true
        let childExpectation = XCTestExpectation(description: "Cancel requested on child")
        let child2Expectation: XCTestExpectation
        let notYetExpectation = XCTestExpectation(description: "Child 2 promise resolved too early")
        notYetExpectation.isInverted = true
        let childPromise: Promise<Int,String>
        do { // scope rootPromise
            let rootPromise = Promise<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate) { (resolver) in
                    rootPromiseCancelExpectation.fulfill()
                    resolver.cancel()
                }
                DispatchQueue.global(qos: .utility).async {
                    sema.wait()
                    resolver.fulfill(with: 42)
                }
            })
            childPromise = rootPromise.propagatingCancellation(on: .immediate, cancelRequested: { _ in
                childExpectation.fulfill()
            })
            let child2Promise = rootPromise.then(on: .immediate, { _ in })
            child2Expectation = XCTestExpectation(on: .immediate, onSuccess: child2Promise, expectedValue: 42)
            child2Promise.tap().always(on: .immediate, { _ in
                notYetExpectation.fulfill()
            })
        }
        childPromise.then(on: .immediate, { _ in }).requestCancel()
        wait(for: [notYetExpectation, childExpectation], timeout: 0)
        sema.signal()
        wait(for: [rootPromiseCancelExpectation, child2Expectation], timeout: 1)
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
    
    func testTryThenReturnsDistinctPromise() {
        // Ensure `tryThen` always returns a distinct promise. This is important so cancelling the
        // result of `tryThen` doesn't necessarily cancel the original promise.
        let promise = Promise<Int,Error>(fulfilled: 42)
        let promise2 = promise.tryThen(on: .immediate, { _ in })
        XCTAssertNotEqual(promise, promise2)
    }
    
    func testTryThen() {
        let callbackExpectation = XCTestExpectation(description: "then handler invoked")
        let promise = Promise<Int,Error>(fulfilled: 42).tryThen(on: .default, { (x) in
            XCTAssertEqual(x, 42)
            callbackExpectation.fulfill()
        })
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [callbackExpectation, expectation], timeout: 1)
    }
    
    func testTryThenThrowing() {
        let promise = Promise<Int,Error>(fulfilled: 42).tryThen(on: .utility, { (x) in
            XCTAssertEqual(x, 42)
            throw TestError()
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryMapThrowing() {
        let promise = Promise<Int,Error>(fulfilled: 42).tryMap(on: .utility, { (x) -> Int in
            throw TestError()
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryFlatMapWithSwiftError() {
        func handler(_ x: Int) throws -> Promise<String,Error> {
            return Promise(rejected: TestError())
        }
        let promise = Promise<Int,Error>(fulfilled: 42).tryFlatMap(on: .utility, { (x) in
            // Don't replace this block literal with handler directly, this tests to make sure we
            // can infer the call without specifying a return type
            return try handler(x)
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryFlatMap() {
        func handler(_ x: Int) throws -> Promise<String,TestError> {
            return Promise(rejected: TestError())
        }
        let promise = Promise<Int,Error>(fulfilled: 42).tryFlatMap(on: .utility, { (x) in
            // Don't replace this block literal with handler directly, this tests to make sure we
            // can infer the call without specifying a return type
            return try handler(x)
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryRecoverThrowing() {
        struct DummyError: Error {}
        let promise = Promise<Int,Error>(rejected: DummyError()).tryRecover(on: .utility, { (error) -> Int in
            throw TestError()
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryFlatMapErrorWithSwiftError() {
        struct DummyError: Error {}
        func handler(_ error: Error) throws -> Promise<Int,Error> {
            return Promise(rejected: TestError())
        }
        let promise = Promise<Int,Error>(rejected: DummyError()).tryFlatMapError(on: .utility, { (error) in
            // Don't replace this block literal with handler directly, this tests to make sure we
            // can infer the call without specifying a return type
            return try handler(error)
        })
        let expectation = XCTestExpectation(onError: promise) { (error) in
            XCTAssert(error is TestError)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testTryFlatMapError() {
        struct DummyError: Error {}
        func handler(_ error: Error) throws -> Promise<Int,TestError> {
            return Promise(rejected: TestError())
        }
        let promise = Promise<Int,Error>(rejected: DummyError()).tryFlatMapError(on: .utility, { (error) in
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
    
    // MARK: - Invalidation Tokens
    
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
        let chainPromise = promise.map(on: .utility, token: token, { (x) in
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
        let chainPromise = promise.map(on: .utility, token: token, { (x) in
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
    
    func testInvalidationTokenRequestCancelOnInvalidate() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let expectation = XCTestExpectation(onCancel: promise)
        let token = PromiseInvalidationToken()
        token.requestCancelOnInvalidate(promise)
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenNoInvalidateOnDeinit() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        do {
            let token = PromiseInvalidationToken(invalidateOnDeinit: false)
            token.requestCancelOnInvalidate(promise)
        }
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenInvalidateOnDeinit() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let expectation = XCTestExpectation(onCancel: promise)
        do {
            let token = PromiseInvalidationToken()
            token.requestCancelOnInvalidate(promise)
        }
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenNotRetained() {
        // Ensure that passing a token to a callback doesn't retain the token
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let expectation = XCTestExpectation(description: "promise resolved")
        do {
            let token = PromiseInvalidationToken()
            promise.then(on: .immediate, token: token, { _ in
                XCTFail("token did not deinit when expected")
            }).always(on: .immediate, { _ in
                expectation.fulfill()
            })
        }
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenCancelWithoutInvalidating() {
        let sema = DispatchSemaphore(value: 0)
        let token = PromiseInvalidationToken(invalidateOnDeinit: false)
        let expectation = XCTestExpectation(description: "promise cancelled")
        Promise<Int,String>(on: .utility, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            sema.wait()
            resolver.fulfill(with: 42)
        }).onCancel(on: .utility, token: token, {
            expectation.fulfill()
        }).requestCancelOnInvalidate(token)
        token.cancelWithoutInvalidating()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenNodeCleanup() throws {
        // This test depends on the formatting of the token's debug description
        func nodeCount(from token: PromiseInvalidationToken) throws -> Int {
            let desc = String(reflecting: token)
            guard let prefixRange = desc.range(of: "callbackLinkedList=("),
                let spaceIdx = desc[prefixRange.upperBound...].unicodeScalars.firstIndex(of: " "),
                let nodeCount = Int(desc[prefixRange.upperBound..<spaceIdx])
                else {
                    struct CantGetNodeCount: Error {}
                    throw CantGetNodeCount()
            }
            return nodeCount
        }
        
        do {
            let token = PromiseInvalidationToken()
            for _ in 0..<100 {
                _ = Promise<Int,String>(fulfilled: 42).requestCancelOnInvalidate(token)
            }
            // 1 node for the final promise
            XCTAssertEqual(try nodeCount(from: token), 1)
        }
        
        do {
            // This time hold onto a node in the middle
            let token = PromiseInvalidationToken()
            for _ in 0..<50 {
                _ = Promise<Int,String>(fulfilled: 42).requestCancelOnInvalidate(token)
            }
            let middlePromise = Promise<Int,String>(fulfilled: 42).requestCancelOnInvalidate(token)
            for _ in 0..<50 {
                _ = Promise<Int,String>(fulfilled: 42).requestCancelOnInvalidate(token)
            }
            try withExtendedLifetime(middlePromise) {
                // 1 node for middlePromise, 1 node for the final promise
                XCTAssertEqual(try nodeCount(from: token), 2)
            }
        }
        
        do {
            // This time keep each previous promise alive when we make the new one
            let token = PromiseInvalidationToken()
            var lastPromise: Promise<Int,String>?
            for _ in 0..<100 {
                let nextPromise = Promise<Int,String>(fulfilled: 42).requestCancelOnInvalidate(token)
                lastPromise = nextPromise
            }
            _ = lastPromise // suppress "never read" warning
            lastPromise = nil
            // 100 nodes because nothing could be cleaned up as each new promise was pushed on
            XCTAssertEqual(try nodeCount(from: token), 100)
            // Now that we've let the final promise die, try pushing one more on and it should clean them all up
            _ = Promise<Int,String>(fulfilled: 42).requestCancelOnInvalidate(token)
            // 1 node for the brand new promise, everything else was cleaned up
            XCTAssertEqual(try nodeCount(from: token), 1)
        }
    }
    
    func testInvalidationTokenChainInvalidationFrom() {
        let sema = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "test queue")
        let token = PromiseInvalidationToken(invalidateOnDeinit: false)
        let subToken = PromiseInvalidationToken(invalidateOnDeinit: false)
        subToken.chainInvalidation(from: token)
        do {
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                sema.wait()
                resolver.fulfill(with: 42)
            })
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.then(on: .queue(queue), token: subToken, { (x) in
                XCTFail("invalidated callback invoked")
            }).always(on: .queue(queue), { (_) in
                expectation.fulfill()
            })
            token.invalidate()
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        // Ensure the chain is still intact
        do {
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                sema.wait()
                resolver.fulfill(with: 42)
            })
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.then(on: .queue(queue), token: subToken, { (x) in
                XCTFail("invalidated callback invoked; the chained invalidation was not permanent")
            }).always(on: .queue(queue), { (_) in
                expectation.fulfill()
            })
            token.invalidate()
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        // Ensure adding a second token to the chain will cancel both of them
        do {
            let subToken2 = PromiseInvalidationToken(invalidateOnDeinit: false)
            subToken2.chainInvalidation(from: token)
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                sema.wait()
                resolver.fulfill(with: 42)
            })
            let expectation = XCTestExpectation(description: "subToken promise resolved")
            promise.then(on: .queue(queue), token: subToken, { (x) in
                XCTFail("invalidated callback invoked")
            }).always(on: .queue(queue), { (_) in
                expectation.fulfill()
            })
            let expectation2 = XCTestExpectation(description: "subToken2 promise resolved")
            promise.then(on: .queue(queue), token: subToken2, { (x) in
                XCTFail("invalidated callback invoked")
            }).always(on: .queue(queue), { (_) in
                expectation2.fulfill()
            })
            token.invalidate()
            sema.signal()
            wait(for: [expectation, expectation2], timeout: 1)
        }
    }
    
    func testInvalidationTokenChainInvalidationFromIncludingCancelWithoutInvalidate() {
        let sema = DispatchSemaphore(value: 0)
        let token = PromiseInvalidationToken(invalidateOnDeinit: false)
        do { // propagating cancel without invalidate
            let subToken = PromiseInvalidationToken(invalidateOnDeinit: false)
            subToken.chainInvalidation(from: token)
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    resolver.cancel()
                })
                sema.wait()
                resolver.fulfill(with: 42)
            }).requestCancelOnInvalidate(subToken)
            let expectation = XCTestExpectation(onCancel: promise)
            token.cancelWithoutInvalidating()
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        do { // without propagating cancel without invalidate
            let subToken = PromiseInvalidationToken(invalidateOnDeinit: false)
            subToken.chainInvalidation(from: token, includingCancelWithoutInvalidating: false)
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    XCTFail("cancel requested")
                    resolver.cancel()
                })
                sema.wait()
                resolver.fulfill(with: 42)
            }).requestCancelOnInvalidate(subToken)
            let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
            token.cancelWithoutInvalidating()
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testInvalidationTokenChainInvalidationFromDoesNotRetain() {
        // Ensure that `chainInvalidation(from:)` does not retain the tokens in either direction.
        let sema = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "test queue")
        do { // child is not retained
            let token = PromiseInvalidationToken(invalidateOnDeinit: false)
            var promise = Promise<Int,String>(on: .utility, { (resolver) in
                sema.wait()
                resolver.fulfill(with: 42)
            })
            do {
                let subToken = PromiseInvalidationToken(invalidateOnDeinit: true)
                subToken.chainInvalidation(from: token)
                promise = promise.then(on: .queue(queue), token: subToken, { (x) in
                    XCTFail("invalidated callback invoked")
                })
            } // subToken deinited, thus invalidated
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.always(on: .queue(queue), { (_) in
                expectation.fulfill()
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        do { // parent is not retained
            let subToken = PromiseInvalidationToken(invalidateOnDeinit: false)
            var promise = Promise<Int,String>(on: .utility, { (resolver) in
                sema.wait()
                resolver.fulfill(with: 42)
            })
            do {
                let token = PromiseInvalidationToken(invalidateOnDeinit: true)
                subToken.chainInvalidation(from: token)
                promise = promise.then(on: .queue(queue), token: token, { (x) in
                    XCTFail("invalidated callback invoked")
                })
            } // token deinited, thus invalidated
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.always(on: .queue(queue), { (_) in
                expectation.fulfill()
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testInvalidationTokenChainInvalidationFromSelf() {
        // Ask a token to chain invalidation from itself just to ensure this doesn't trigger an
        // infinite loop.
        let token = PromiseInvalidationToken()
        token.chainInvalidation(from: token)
        token.invalidate()
    }
    
    func testInvalidationTokenChainNodeCleanup() throws {
        // This test depends on the formatting of the token's debug description
        func nodeCount(from token: PromiseInvalidationToken) throws -> Int {
            let desc = String(reflecting: token)
            guard let prefixRange = desc.range(of: "tokenChainLinkedList=("),
                let spaceIdx = desc[prefixRange.upperBound...].unicodeScalars.firstIndex(of: " "),
                let nodeCount = Int(desc[prefixRange.upperBound..<spaceIdx])
                else {
                    struct CantGetNodeCount: Error {}
                    throw CantGetNodeCount()
            }
            return nodeCount
        }
        
        do {
            let token = PromiseInvalidationToken()
            for _ in 0..<100 {
                PromiseInvalidationToken(invalidateOnDeinit: false).chainInvalidation(from: token)
            }
            // 1 node for the final chained token
            XCTAssertEqual(try nodeCount(from: token), 1)
        }
        
        do {
            // This time hold onto a node in the middle
            let token = PromiseInvalidationToken()
            for _ in 0..<50 {
                PromiseInvalidationToken(invalidateOnDeinit: false).chainInvalidation(from: token)
            }
            let middleToken = PromiseInvalidationToken()
            middleToken.chainInvalidation(from: token)
            for _ in 0..<50 {
                PromiseInvalidationToken(invalidateOnDeinit: false).chainInvalidation(from: token)
            }
            try withExtendedLifetime(middleToken) {
                // 1 node for middle token, 1 node for final token
                XCTAssertEqual(try nodeCount(from: token), 2)
            }
        }
        
        do {
            // This keeps each previous token alive when we make the new one
            let token = PromiseInvalidationToken()
            var lastToken: PromiseInvalidationToken?
            for _ in 0..<100 {
                let nextToken = PromiseInvalidationToken(invalidateOnDeinit: false)
                nextToken.chainInvalidation(from: token)
                lastToken = nextToken
            }
            _ = lastToken // suppress "never read" warning
            lastToken = nil
            // 100 nodes because nothing could be cleaned up as each new token was pushed on
            XCTAssertEqual(try nodeCount(from: token), 100)
            // Now that we've let the final token die, try pushing one more on and it should clean them all up
            PromiseInvalidationToken(invalidateOnDeinit: false).chainInvalidation(from: token)
            // 1 node for the brand new token, everything else was cleaned up
            XCTAssertEqual(try nodeCount(from: token), 1)
        }
    }
    
    // MARK: -
    
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
            .flatMap(on: .immediate, { (x) -> Promise<String,String> in
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
            .flatMap(on: .immediate, { (x) -> Promise<String,String> in
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
                // Ensure order is preserved. This really only applies to the catch/flatMapError pair
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
                }).map(on: .main, { (x) -> Int in
                    XCTAssertFalse(observer.invoked, "second then callback was delayed")
                    XCTAssertEqual(order, 1)
                    order += 1
                    observer.invoked = false
                    return 43
                }).flatMap(on: .main, { (x) -> Promise<Int,String> in
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
                    XCTAssertFalse(observer.invoked, "flatMapError callback was delayed")
                    XCTAssertEqual(order, 4)
                    order += 1
                    observer.invoked = false
                    return 42
                }).flatMapResult(on: .main, { (x) -> Promise<Int,String> in
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
                }).map(on: .queue(.main), { (x) -> Int in
                    XCTAssertTrue(observer.invoked, "then callback wasn't delayed")
                    observer.invoked = false
                    return x+1
                }).flatMap(on: .queue(.main), { (x) -> Promise<Int,String> in
                    XCTAssertTrue(observer.invoked, "second then callback wasn't delayed")
                    observer.invoked = false
                    return Promise(rejected: "error")
                }).catch(on: .queue(.main), { (x) in
                    XCTAssertTrue(observer.invoked, "catch callback wasn't delayed")
                    observer.invoked = false
                }).recover(on: .queue(.main), { (x) in
                    XCTAssertTrue(observer.invoked, "flatMapError callback wasn't delayed")
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
                }).map(on: .main, { (x) -> Int in
                    XCTAssertFalse(observer.invoked, "then callback was delayed")
                    observer.invoked = false
                    return x+1
                }).map(on: .queue(.main), { (x) -> Int in
                    XCTAssertTrue(observer.invoked, "second then callback wasn't delayed")
                    observer.invoked = false
                    return x+1
                }).map(on: .main, { (x) -> Int in
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
    
    func testChainedMainContextCallbacksReleaseBeforeNextOneBegins() {
        // Ensure that when we chain main context callbacks, we release each block before invoking
        // the next one.
        let (promise, resolver) = Promise<Int,String>.makeWithResolver()
        let firstExpectation = XCTestExpectation(description: "first block released")
        let secondExpectation = XCTestExpectation(description: "second block executed")
        _ = promise.then(on: .main, { [spy=DeinitSpy(fulfilling: firstExpectation)] _ in
            withExtendedLifetime(spy) {} // ensure spy isn't optimized away
        }).then(on: .main, { _ in
            self.wait(for: [firstExpectation], timeout: 0)
            secondExpectation.fulfill()
        })
        DispatchQueue.global(qos: .default).async {
            resolver.fulfill(with: 42)
        }
        wait(for: [secondExpectation], timeout: 1)
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
    
    func testObservationCallbackReleasedWhenPromiseResolved() {
        let (promise, resolver) = Promise<Int,String>.makeWithResolver()
        weak var weakObject: NSObject?
        do {
            let object = NSObject()
            weakObject = object
            _ = promise.then(on: .immediate, { (x) in
                withExtendedLifetime(object, {})
            })
        }
        XCTAssertNotNil(weakObject)
        resolver.fulfill(with: 42)
        XCTAssertNil(weakObject)
    }
    
    func testObservationCallbackReleasedWhenPromiseCancelled() {
        let (promise, resolver) = Promise<Int,String>.makeWithResolver()
        weak var weakObject: NSObject?
        do {
            let object = NSObject()
            weakObject = object
            _ = promise.then(on: .immediate, { (x) in
                withExtendedLifetime(object, {})
            })
        }
        XCTAssertNotNil(weakObject)
        resolver.cancel()
        XCTAssertNil(weakObject)
    }
    
    func testOnCancelCallbackReleasedWhenPromiseResolved() {
        let (_, resolver) = Promise<Int,String>.makeWithResolver()
        weak var weakObject: NSObject?
        do {
            let object = NSObject()
            weakObject = object
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                withExtendedLifetime(object, {})
            })
        }
        XCTAssertNotNil(weakObject)
        resolver.fulfill(with: 42)
        XCTAssertNil(weakObject)
    }
    
    func testOnCancelCallbackReleasedWhenPromiseRequestedCancel() {
        let (promise, resolver) = Promise<Int,String>.makeWithResolver()
        weak var weakObject: NSObject?
        do {
            let object = NSObject()
            weakObject = object
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                withExtendedLifetime(object, {})
                resolver.cancel()
            })
        }
        XCTAssertNotNil(weakObject)
        promise.requestCancel()
        XCTAssertNil(weakObject)
    }
    
    func testThenCallbackDeinited() {
        // We're doing special things with callback lifetimes, so let's just make sure we aren't
        // leaking it.
        do {
            // When it executes
            let (promise, resolver) = Promise<Int,String>.makeWithResolver()
            let notYet = XCTestExpectation(description: "spy deinited")
            notYet.isInverted = true
            let expectation = XCTestExpectation(description: "then block deinited")
            _ = promise.then(on: .main, { [spy=DeinitSpy(onDeinit: { notYet.fulfill(); expectation.fulfill() })] _ in
                self.wait(for: [notYet], timeout: 0) // sanity check to make sure the spy is alive
                withExtendedLifetime(spy) {} // ensure we don't optimize away the spy
            })
            resolver.fulfill(with: 42)
            wait(for: [expectation], timeout: 1)
        }
        do {
            // When it doesn't execute
            let (promise, resolver) = Promise<Int,String>.makeWithResolver()
            let notYet = XCTestExpectation(description: "spy deinited")
            notYet.isInverted = true
            let expectation = XCTestExpectation(description: "then block deinited")
            _ = promise.then(on: .main, { [spy=DeinitSpy(onDeinit: { notYet.fulfill(); expectation.fulfill() })] _ in
                self.wait(for: [notYet], timeout: 0) // sanity check to make sure the spy is alive
                withExtendedLifetime(spy) {} // ensure we don't optimize away the spy
            })
            resolver.reject(with: "foobar")
            wait(for: [expectation], timeout: 1)
        }
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
    
    #if compiler(>=5)
    func testInitWithSwiftResult() {
        enum MyError: Error, Equatable { case foo }
        XCTAssertEqual(PromiseResult(Result<Int,MyError>.success(42)), PromiseResult.value(42))
        XCTAssertEqual(PromiseResult(Result<Int,MyError>.failure(.foo)), PromiseResult.error(.foo))
    }
    #endif
    
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
}

private let testQueueKey = DispatchSpecificKey<String>()
