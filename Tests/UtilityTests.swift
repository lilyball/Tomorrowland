//
//  UtilityTests.swift
//  TomorrowlandTests
//
//  Created by Ballard, Kevin on 12/21/17.
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
    
    func testCancelOnTimeout() {
        do { // cancel
            let cancelExpectation = XCTestExpectation(description: "promise cancelled")
            
            let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    cancelExpectation.fulfill()
                    resolver.cancel()
                })
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    resolver.fulfill(with: 42)
                }
            }).timeout(on: .utility, delay: 0.01, cancelOnTimeout: true)
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                switch error {
                case .timedOut: break
                default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                }
            })
            wait(for: [expectation, cancelExpectation], timeout: 1)
        }
        
        do { // don't cancel
            let cancelExpectation = XCTestExpectation(description: "promise cancelled")
            cancelExpectation.isInverted = true
            
            let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    cancelExpectation.fulfill()
                    resolver.cancel()
                })
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    resolver.fulfill(with: 42)
                }
            }).timeout(on: .utility, delay: 0.01, cancelOnTimeout: false)
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                switch error {
                case .timedOut: break
                default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                }
            })
            wait(for: [expectation], timeout: 1)
            wait(for: [cancelExpectation], timeout: 0.01)
        }
    }
    
    func testLinkCancel() {
        let cancelExpectation = XCTestExpectation(description: "promise cancelled")
        
        let promise = Promise<Int,String>(on: .immediate, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                cancelExpectation.fulfill()
                resolver.cancel()
            })
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                resolver.fulfill(with: 42)
            }
        }).timeout(on: .utility, delay: 0.5)
        let expectation = XCTestExpectation(onCancel: promise)
        promise.requestCancel()
        wait(for: [expectation, cancelExpectation], timeout: 1)
    }
    
    func testZeroDelayAlreadyResolved() {
        let promise = Promise<Int,String>.init(fulfilled: 42).timeout(on: .utility, delay: 0)
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (x) in
            XCTAssertEqual(x, 42)
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
    
    func testErrorCancelOnTimeout() {
        do { // cancel
            let cancelExpectation = XCTestExpectation(description: "promise cancelled")
            
            let promise = Promise<Int,Error>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    cancelExpectation.fulfill()
                    resolver.cancel()
                })
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    resolver.fulfill(with: 42)
                }
            }).timeout(on: .utility, delay: 0.01, cancelOnTimeout: true)
            let _: Promise<Int,Error> = promise // type assertion
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                switch error {
                case PromiseTimeoutError<Error>.timedOut: break
                default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                }
            })
            wait(for: [expectation, cancelExpectation], timeout: 1)
        }
        
        do { // don't cancel
            let cancelExpectation = XCTestExpectation(description: "promise cancelled")
            cancelExpectation.isInverted = true
            
            let promise = Promise<Int,Error>(on: .immediate, { (resolver) in
                resolver.onRequestCancel(on: .immediate, { (resolver) in
                    cancelExpectation.fulfill()
                    resolver.cancel()
                })
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    resolver.fulfill(with: 42)
                }
            }).timeout(on: .utility, delay: 0.01, cancelOnTimeout: false)
            let _: Promise<Int,Error> = promise // type assertion
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                switch error {
                case PromiseTimeoutError<Error>.timedOut: break
                default: XCTFail("Expected PromiseTimeoutError.timedOut, found \(error)")
                }
            })
            wait(for: [expectation], timeout: 1)
            wait(for: [cancelExpectation], timeout: 0.01)
        }
    }
    
    func testErrorLinkCancel() {
        let cancelExpectation = XCTestExpectation(description: "promise cancelled")
        
        let promise = Promise<Int,Error>(on: .immediate, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                cancelExpectation.fulfill()
                resolver.cancel()
            })
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                resolver.fulfill(with: 42)
            }
        }).timeout(on: .utility, delay: 0.5)
        let _: Promise<Int,Error> = promise // type assertion
        let expectation = XCTestExpectation(onCancel: promise)
        promise.requestCancel()
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
}
