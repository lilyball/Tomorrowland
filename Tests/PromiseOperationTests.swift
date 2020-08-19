//
//  PromiseOperationTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 8/18/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Tomorrowland

final class PromiseOperationTests: XCTestCase {
    func testOperationResolvesOnStart() {
        let op = PromiseOperation<Int,String>(on: .immediate, { (resolver) in
            resolver.fulfill(with: 42)
        })
        let promise = op.promise
        XCTAssertNil(promise.result)
        op.start()
        XCTAssertEqual(promise.result, .value(42))
    }
    
    func testOperationLifecycle() {
        let sema = DispatchSemaphore(value: 0)
        let op = PromiseOperation<Int,String>(on: .default, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        })
        XCTAssertFalse(op.isExecuting)
        XCTAssertFalse(op.isFinished)
        op.start()
        XCTAssertTrue(op.isExecuting)
        XCTAssertFalse(op.isFinished)
        let expectation = XCTestExpectation(on: .immediate, onSuccess: op.promise) { _ in
            // When the promise is resolved, the operation should already be in its finished state
            XCTAssertFalse(op.isExecuting)
            XCTAssertTrue(op.isFinished)
        }
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testOperationPromiseCancelsOnDeinit() {
        XCTContext.runActivity(named: "Deinit without running handler") { _ in
            var op = Optional(PromiseOperation<Int,String>(on: .immediate, { (resolver) in
                XCTFail("invoked unexpectedly")
            }))
            let promise = op!.promise
            XCTAssertNil(promise.result)
            op = nil
            XCTAssertEqual(promise.result, .cancelled)
        }
        
        XCTContext.runActivity(named: "Deinit while handler is running") { _ in
            // If the handler is running, it shouldn't request cancel
            let sema = DispatchSemaphore(value: 0)
            var op = Optional(PromiseOperation<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate) { (_) in
                    XCTFail("Resolver requested to cancel")
                }
                DispatchQueue.global().async {
                    sema.wait()
                    resolver.fulfill(with: 42)
                }
            }))
            let promise = op!.promise
            op!.start()
            XCTAssertNil(promise.result)
            op = nil
            XCTAssertNil(promise.result)
            sema.signal()
            wait(for: [XCTestExpectation(onSuccess: promise, expectedValue: 42)], timeout: 1)
        }
    }
    
    func testOperationReturnsSamePromise() {
        let op = PromiseOperation<Int,String>(on: .immediate, { (resolver) in
            resolver.fulfill(with: 42)
        })
        let promise1 = op.promise
        let promise2 = op.promise
        XCTAssertEqual(promise1, promise2)
    }
    
    func testOperationCancelWillCancelPromise() {
        XCTContext.runActivity(named: "Cancelling while operation is executing") { _ in
            let sema = DispatchSemaphore(value: 0)
            let requestCancelExpectation = XCTestExpectation(description: "onRequestCancel")
            let op = PromiseOperation<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    requestCancelExpectation.fulfill()
                    resolver.cancel()
                })
                DispatchQueue.global().async {
                    sema.wait()
                    resolver.fulfill(with: 42)
                }
            })
            op.start()
            XCTAssertNil(op.promise.result)
            op.cancel()
            sema.signal()
            let cancelExpectation = XCTestExpectation(on: .immediate, onCancel: op.promise)
            wait(for: [requestCancelExpectation, cancelExpectation], timeout: 0)
        }
        
        XCTContext.runActivity(named: "Cancelling before operation starts") { _ in
            let op = PromiseOperation<Int,String>(on: .immediate, { (resolver) in
                XCTFail("This shouldn't be invoked")
            })
            // Cancel the operation now without it having started
            op.cancel()
            // The promise won't be cancelled until the operation itself moves to finished.
            XCTAssertNil(op.promise.result)
            // Start the operation so it can cancel itself
            op.start()
            XCTAssertEqual(op.promise.result, .cancelled)
        }
    }
    
    func testOperationPromiseCancelWillCancelOperation() {
        XCTContext.runActivity(named: "Cancelling while operation is executing") { _ in
            let sema = DispatchSemaphore(value: 0)
            let op = PromiseOperation<Int,String>(on: .default, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    resolver.cancel()
                })
                sema.wait()
                resolver.fulfill(with: 42)
            })
            op.start()
            XCTAssertFalse(op.isCancelled)
            op.promise.requestCancel()
            XCTAssertTrue(op.isCancelled)
            sema.signal()
        }
        
        XCTContext.runActivity(named: "Cancelling before operation starts") { _ in
            let op = PromiseOperation<Int,String>(on: .immediate, { (resolver) in
                XCTFail("This shouldn't be invoked")
            })
            // Cancel the promise now without it having started
            op.promise.requestCancel()
            // The operation will be cancelled
            XCTAssertTrue(op.isCancelled)
            // But the promise won't have resolved yet
            XCTAssertNil(op.promise.result)
            // Start the promise now so the promise can get resolved
            op.start()
            XCTAssertEqual(op.promise.result, .cancelled)
        }
    }
    
    func testOperationDropsCallbackAfterInvocation() {
        let dropExpectation = XCTestExpectation(description: "callback dropped")
        let notDroppedExpectation = XCTestExpectation(description: "callback not yet dropped")
        notDroppedExpectation.isInverted = true
        var dropSpy: DropSpy? = DropSpy(onDrop: {
            dropExpectation.fulfill()
            notDroppedExpectation.fulfill()
        })
        let op = PromiseOperation<Int,String>(on: .immediate, { [dropSpy] (resolver) in
            withExtendedLifetime(dropSpy, {
                resolver.fulfill(with: 42)
            })
        })
        dropSpy = nil
        wait(for: [notDroppedExpectation], timeout: 0) // ensure DropSpy is held by op
        op.start()
        withExtendedLifetime(op) {
            wait(for: [dropExpectation], timeout: 0)
        }
    }
    
    func testOperationUsingNowOr() {
        // .nowOr doesn't ever run now when used with PromiseOperation
        let expectation = XCTestExpectation()
        let op = PromiseOperation<Int,String>(on: .nowOr(.queue(TestQueue.two)), { (resolver) in
            TestQueue.assert(on: .two)
            expectation.fulfill()
        })
        op.start()
        wait(for: [expectation], timeout: 1)
    }
    
    func testOperationUsingNowOrStartedOnNowOr() {
        // .nowOr shouldn't run now even if the operation is started from a .nowOr context
        let expectation = XCTestExpectation()
        let op = PromiseOperation<Int,String>(on: .nowOr(.queue(TestQueue.two)), { (resolver) in
            TestQueue.assert(on: .two)
            expectation.fulfill()
        })
        TestQueue.one.async {
            _ = Promise<Int,String>(fulfilled: 42).then(on: .nowOr(.queue(TestQueue.two)), { (_) in
                TestQueue.assert(on: .one) // This runs now
                op.start()
            })
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testOperationImmediateWithStart() {
        let op = PromiseOperation<Int,String>(on: .immediate, { (resolver) in
            TestQueue.assert(on: .one)
            resolver.fulfill(with: 123)
        })
        TestQueue.one.async {
            op.start()
        }
        let expectation = XCTestExpectation(onSuccess: op.promise, expectedValue: 123)
        wait(for: [expectation], timeout: 1)
    }
    
    func testOperationImmediateOnQueue() {
        let queue = OperationQueue()
        let op = PromiseOperation<Int,String>(on: .immediate, { (resolver) in
            XCTAssertEqual(OperationQueue.current, queue)
            resolver.fulfill(with: 321)
        })
        queue.addOperation(op)
        let expectation = XCTestExpectation(onSuccess: op.promise, expectedValue: 321)
        wait(for: [expectation], timeout: 1)
    }
    
    func testOperationStaysOnQueueUntilResolved() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let sema = DispatchSemaphore(value: 0)
        let sema2 = DispatchSemaphore(value: 0)
        let op = PromiseOperation<Int,String>(on: .default, { (resolver) in
            sema2.signal() // Signal that we're in the block
            DispatchQueue.global().async { // Just for good measure
                sema2.signal() // Signal that we're in the async queue
                sema.wait()
                resolver.fulfill(with: 42)
            }
        })
        queue.addOperation(op)
        let expectation = XCTestExpectation(description: "Next block finished")
        let invertExpectation = XCTestExpectation(description: "Next block finished")
        invertExpectation.isInverted = true
        let op2 = BlockOperation {
            invertExpectation.fulfill()
            expectation.fulfill()
        }
        op2.addDependency(op) // just for good measure
        queue.addOperation(op2)
        sema2.wait() // wait for the operation to have entered its callback
        XCTAssertFalse(op.isFinished)
        sema2.wait() // wait for the operation to have entered the async queue too
        XCTAssertFalse(op.isFinished)
        wait(for: [invertExpectation], timeout: 0) // Ensure op2 hasn't run yet
        XCTAssertEqual(queue.operations, [op, op2]) // Also for good measure
        sema.signal() // Let the operation finish
        wait(for: [XCTestExpectation(onSuccess: op.promise, expectedValue: 42), expectation], timeout: 1)
        // Double-check state for good measure
        XCTAssertTrue(op.isFinished)
        XCTAssertTrue(op2.isFinished)
        XCTAssertEqual(queue.operations, [])
    }
    
    func testOperationFinishesWhenCancelled() {
        XCTContext.runActivity(named: "Cancelled before executing") { _ in
            let queue = OperationQueue()
            let op = PromiseOperation<Int,String>(on: .immediate) { (resolver) in
                XCTFail("Unexpected execution")
            }
            let op2 = BlockOperation {
                op.cancel()
            }
            op.addDependency(op2)
            queue.addOperation(op)
            queue.addOperation(op2)
            op2.waitUntilFinished()
            wait(for: [XCTestExpectation(onCancel: op.promise)], timeout: 1)
            XCTAssertFalse(op.isExecuting)
            XCTAssertTrue(op.isFinished)
            XCTAssertEqual(queue.operations, [])
        }
        
        XCTContext.runActivity(named: "Cancelled while executing") { (resolver) in
            let queue = OperationQueue()
            let sema = DispatchSemaphore(value: 0)
            let sema2 = DispatchSemaphore(value: 0)
            let cancelExpectation = XCTestExpectation(description: "Cancel requested")
            let op = PromiseOperation<Int,String>(on: .immediate) { (resolver) in
                resolver.onRequestCancel(on: .immediate) { (resolver) in
                    cancelExpectation.fulfill()
                    resolver.cancel()
                }
                DispatchQueue.global().async {
                    sema.wait()
                    resolver.fulfill(with: 42)
                }
                sema2.signal()
            }
            queue.addOperation(op)
            sema2.wait()
            op.cancel()
            sema.signal()
            wait(for: [cancelExpectation, XCTestExpectation(onCancel: op.promise)], timeout: 1)
        }
    }
    
    func testCallingStartMultipleTimes() {
        // Calling start multiple times should do nothing
        let handlerExpectation = XCTestExpectation(description: "handler invoked")
        handlerExpectation.expectedFulfillmentCount = 1
        handlerExpectation.assertForOverFulfill = true
        let sema = DispatchSemaphore(value: 0)
        let op = PromiseOperation<Int,String>(on: .immediate) { (resolver) in
            handlerExpectation.fulfill()
            DispatchQueue.global().async {
                sema.wait()
                resolver.fulfill(with: 42)
            }
        }
        op.start()
        op.start()
        op.start()
        sema.signal()
        op.start()
        wait(for: [handlerExpectation, XCTestExpectation(onSuccess: op.promise, expectedValue: 42)], timeout: 1)
    }
}

private class DropSpy {
    let callback: () -> Void
    init(onDrop: @escaping () -> Void) {
        callback = onDrop
    }
    deinit {
        callback()
    }
}
