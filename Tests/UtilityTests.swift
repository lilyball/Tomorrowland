//
//  UtilityTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 12/21/17.
//  Copyright © 2017 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Tomorrowland

final class UtilityTests: XCTestCase {
    func testDelayFulfill() {
        // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        }).delay(on: .utility, 0.05)
        let expectation = XCTestExpectation(description: "promise")
        var invoked: DispatchTime?
        promise.always(on: .userInteractive, { (result) in
            invoked = .now()
            XCTAssertEqual(result, .value(42))
            expectation.fulfill()
        })
        let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(50)
        sema.signal()
        wait(for: [expectation], timeout: 1)
        if let invoked = invoked {
            XCTAssert(invoked > deadline)
        } else {
            XCTFail("Didn't retrieve invoked value")
        }
    }
    
    func testDelayReject() {
        // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.reject(with: "foo")
        }).delay(on: .utility, 0.05)
        let expectation = XCTestExpectation(description: "promise")
        var invoked: DispatchTime?
        promise.always(on: .userInteractive, { (result) in
            invoked = .now()
            XCTAssertEqual(result, .error("foo"))
            expectation.fulfill()
        })
        let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(50)
        sema.signal()
        wait(for: [expectation], timeout: 1)
        if let invoked = invoked {
            XCTAssert(invoked > deadline)
        } else {
            XCTFail("Didn't retrieve invoked value")
        }
    }
    
    func testDelayCancel() {
        // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.cancel()
        }).delay(on: .utility, 0.05)
        let expectation = XCTestExpectation(description: "promise")
        var invoked: DispatchTime?
        promise.always(on: .userInteractive, { (result) in
            invoked = .now()
            XCTAssertEqual(result, .cancelled)
            expectation.fulfill()
        })
        let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(50)
        sema.signal()
        wait(for: [expectation], timeout: 1)
        if let invoked = invoked {
            XCTAssert(invoked > deadline)
        } else {
            XCTFail("Didn't retrieve invoked value")
        }
    }
    
    func testDelayUsingImmediate() {
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        }).delay(on: .immediate, 0.05)
        let expectation = XCTestExpectation(on: .immediate, onSuccess: promise) { (x) in
            XCTAssertEqual(x, 42)
            XCTAssertTrue(Thread.isMainThread)
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testDelayPropagateCancel() {
        let expectation: XCTestExpectation
        let promise: Promise<Int,String>
        let sema = DispatchSemaphore(value: 0)
        do {
            let origPromise = Promise<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    resolver.cancel()
                })
                DispatchQueue.global(qos: .utility).async {
                    sema.wait()
                    resolver.fulfill(with: 42)
                }
            })
            expectation = XCTestExpectation(onCancel: origPromise)
            promise = origPromise.delay(on: .immediate, 0.05)
            promise.requestCancel()
            XCTAssertNil(origPromise.result) // shouldn't cancel yet
        }
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testDelayUsingOperationQueue() {
        // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
        let queue = OperationQueue()
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        }).delay(on: .operationQueue(queue), 0.05)
        let expectation = XCTestExpectation(description: "promise")
        var invoked: DispatchTime?
        promise.always(on: .immediate, { (result) in
            invoked = .now()
            XCTAssertEqual(result, .value(42))
            XCTAssertEqual(OperationQueue.current, queue)
            expectation.fulfill()
        })
        let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(50)
        sema.signal()
        wait(for: [expectation], timeout: 1)
        if let invoked = invoked {
            XCTAssert(invoked > deadline)
        } else {
            XCTFail("Didn't retrieve invoked value")
        }
    }
    
    func testDelayUsingOperationQueueHeadOfLine() {
        // This test ensures that when we delay on an operation queue, we add the operation
        // immediately, and thus it will have priority over later operations on the same queue.
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .userInitiated, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        }).delay(on: .operationQueue(queue), 0.01)
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        queue.addOperation {
            // block the queue for 50ms
            // This way the delay should be ready by the time we finish, which will allow it to run
            // before the next block.
            Thread.sleep(forTimeInterval: 0.05)
        }
        queue.addOperation {
            // block the queue for 1 second. This ensures the test will fail if the delay operation
            // is behind us.
            Thread.sleep(forTimeInterval: 1)
        }
        sema.signal()
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: -
    
    func testTimeout() {
        let queue = DispatchQueue(label: "test queue")
        
        do { // fulfill
            let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                queue.asyncAfter(deadline: .now() + 0.01) {
                    resolver.fulfill(with: 42)
                }
            }).timeout(on: .queue(queue), delay: 0.05)
            let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
            wait(for: [expectation], timeout: 1)
        }
        
        do { // reject
            let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                queue.asyncAfter(deadline: .now() + 0.01) {
                    resolver.reject(with: "error")
                }
            }).timeout(on: .queue(queue), delay: 0.05)
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                switch error {
                case .rejected(let error): XCTAssertEqual(error, "error")
                default: XCTFail("Expected PromiseTimeoutError.rejected, found \(error)")
                }
            })
            wait(for: [expectation], timeout: 1)
        }
        
        do { // timeout
            let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                queue.asyncAfter(deadline: .now() + 0.05) {
                    resolver.fulfill(with: 42)
                }
            }).timeout(on: .queue(queue), delay: 0.01)
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                switch error {
                case .timedOut: break
                default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                }
            })
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testCancelPropagationOnTimeout() {
        do { // cancel
            let cancelExpectation = XCTestExpectation(description: "promise cancelled")
            
            let expectation: XCTestExpectation
            do {
                let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        cancelExpectation.fulfill()
                        resolver.cancel()
                    })
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                        resolver.fulfill(with: 42)
                    }
                }).timeout(on: .utility, delay: 0.01)
                expectation = XCTestExpectation(onError: promise, handler: { (error) in
                    switch error {
                    case .timedOut: break
                    default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                    }
                })
            }
            wait(for: [expectation, cancelExpectation], timeout: 1)
        }
        
        do { // don't cancel
            let cancelExpectation = XCTestExpectation(description: "promise cancelled")
            cancelExpectation.isInverted = true
            
            let expectation: XCTestExpectation
            do {
                let origPromise = Promise<Int,String>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        cancelExpectation.fulfill()
                        resolver.cancel()
                    })
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                        resolver.fulfill(with: 42)
                    }
                })
                _ = origPromise.then(on: .utility, { _ in })
                let promise = origPromise.timeout(on: .utility, delay: 0.01)
                expectation = XCTestExpectation(onError: promise, handler: { (error) in
                    switch error {
                    case .timedOut: break
                    default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                    }
                })
            }
            wait(for: [expectation], timeout: 1)
            wait(for: [cancelExpectation], timeout: 0.01)
        }
    }
    
    func testTimeoutPropagateCancel() {
        let cancelExpectation = XCTestExpectation(description: "promise cancelled")
        
        let promise: Promise<Int,PromiseTimeoutError<String>>
        do {
            let origPromise = Promise<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    cancelExpectation.fulfill()
                    resolver.cancel()
                })
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    resolver.fulfill(with: 42)
                }
            })
            promise = origPromise.timeout(on: .utility, delay: 0.5)
            promise.requestCancel()
            XCTAssertNil(origPromise.result) // not yet cancelled
        }
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation, cancelExpectation], timeout: 1)
    }
    
    func testZeroDelayAlreadyResolved() {
        let promise = Promise<Int,String>.init(fulfilled: 42).timeout(on: .utility, delay: 0)
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [expectation], timeout: 1)
    }
    
    func testTimeoutUsingOperationQueue() {
        let queue = OperationQueue()
        
        let promise = Promise<Int,String>(on: .immediate, { (resolver) in
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                resolver.fulfill(with: 42)
            }
        }).timeout(on: .operationQueue(queue), delay: 0.01)
        let expectation = XCTestExpectation(on: .immediate, onError: promise, handler: { (error) in
            switch error {
            case .timedOut: break
            default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
            }
            XCTAssertEqual(OperationQueue.current, queue)
        })
        wait(for: [expectation], timeout: 1)
    }
    
    // MARK: Error variant
    
    func testErrorTimeout() {
        let queue = DispatchQueue(label: "test queue")
        
        do { // fulfill
            let promise = Promise<Int,Error>(on: .immediate, { (resolver) in
                queue.asyncAfter(deadline: .now() + 0.01) {
                    resolver.fulfill(with: 42)
                }
            }).timeout(on: .queue(queue), delay: 0.05)
            let _: Promise<Int,Error> = promise // type assertion
            let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
            wait(for: [expectation], timeout: 1)
        }
        
        do { // reject
            struct DummyError: Error {}
            let promise = Promise<Int,Error>(on: .immediate, { (resolver) in
                queue.asyncAfter(deadline: .now() + 0.01) {
                    resolver.reject(with: DummyError())
                }
            }).timeout(on: .queue(queue), delay: 0.05)
            let _: Promise<Int,Error> = promise // type assertion
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                XCTAssert(error is DummyError)
            })
            wait(for: [expectation], timeout: 1)
        }
        
        do { // timeout
            let promise = Promise<Int,Error>(on: .immediate, { (resolver) in
                queue.asyncAfter(deadline: .now() + 0.05) {
                    resolver.fulfill(with: 42)
                }
            }).timeout(on: .queue(queue), delay: 0.01)
            let _: Promise<Int,Error> = promise // type assertion
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                switch error {
                case PromiseTimeoutError<Error>.timedOut: break
                default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                }
            })
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testErrorCancelPropagationOnTimeout() {
        do { // cancel
            let cancelExpectation = XCTestExpectation(description: "promise cancelled")
            
            let expectation: XCTestExpectation
            do {
                let promise = Promise<Int,Error>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        cancelExpectation.fulfill()
                        resolver.cancel()
                    })
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                        resolver.fulfill(with: 42)
                    }
                }).timeout(on: .utility, delay: 0.01)
                let _: Promise<Int,Error> = promise // type assertion
                expectation = XCTestExpectation(onError: promise, handler: { (error) in
                    switch error {
                    case PromiseTimeoutError<Error>.timedOut: break
                    default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                    }
                })
            }
            wait(for: [expectation, cancelExpectation], timeout: 1)
        }
        
        do { // don't cancel
            let cancelExpectation = XCTestExpectation(description: "promise cancelled")
            cancelExpectation.isInverted = true
            
            let expectation: XCTestExpectation
            do {
                let origPromise = Promise<Int,Error>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        cancelExpectation.fulfill()
                        resolver.cancel()
                    })
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                        resolver.fulfill(with: 42)
                    }
                })
                _ = origPromise.then(on: .utility, { _ in })
                let promise = origPromise.timeout(on: .utility, delay: 0.01)
                let _: Promise<Int,Error> = promise // type assertion
                expectation = XCTestExpectation(onError: promise, handler: { (error) in
                    switch error {
                    case PromiseTimeoutError<Error>.timedOut: break
                    default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                    }
                })
            }
            wait(for: [expectation], timeout: 1)
            wait(for: [cancelExpectation], timeout: 0.01)
        }
    }
    
    func testErrorTimeoutPropagateCancel() {
        let cancelExpectation = XCTestExpectation(description: "promise cancelled")
        
        let promise: Promise<Int,Error>
        do {
            let origPromise = Promise<Int,Error>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    cancelExpectation.fulfill()
                    resolver.cancel()
                })
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    resolver.fulfill(with: 42)
                }
            })
            promise = origPromise.timeout(on: .utility, delay: 0.5)
            promise.requestCancel()
            XCTAssertNil(origPromise.result) // not yet cancelled
        }
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation, cancelExpectation], timeout: 1)
    }
    
    func testErrorZeroDelayAlreadyResolved() {
        let promise = Promise<Int,Error>.init(fulfilled: 42).timeout(on: .utility, delay: 0)
        let _: Promise<Int,Error> = promise // type assertion
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (x) in
            XCTAssertEqual(x, 42)
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testErrorTimeoutUsingOperationQueue() {
        let queue = OperationQueue()
        
        let promise = Promise<Int,Error>(on: .immediate, { (resolver) in
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                resolver.fulfill(with: 42)
            }
        }).timeout(on: .operationQueue(queue), delay: 0.01)
        let _: Promise<Int,Error> = promise // type assertion
        let expectation = XCTestExpectation(on: .immediate, onError: promise, handler: { (error) in
            switch error {
            case PromiseTimeoutError<Error>.timedOut: break
            default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
            }
            XCTAssertEqual(OperationQueue.current, queue)
        })
        wait(for: [expectation], timeout: 1)
    }
}
