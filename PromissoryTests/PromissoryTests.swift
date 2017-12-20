//
//  PromissoryTests.swift
//  PromissoryTests
//
//  Created by Kevin Ballard on 12/12/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import XCTest
import Promissory

final class PromissoryTests: XCTestCase {
    func testBasicFulfill() {
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(42)
        })
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(promise.result, .value(42))
    }
    
    func testBasicReject() {
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.reject("error")
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
            resolver.fulfill(42)
        }).then(on: .utility) { (x) -> Promise<String,String> in
            let newPromise = Promise<String,String>(on: .utility) { resolver in
                resolver.fulfill("\(x+1)")
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
            resolver.fulfill(42)
        }).then(on: .utility) { (x) -> Promise<String,String> in
            let newPromise = Promise<String,String>(on: .utility) { resolver in
                resolver.reject("foo")
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
            resolver.fulfill(42)
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
            resolver.fulfill(42)
        })
        let expectations = (0..<10).map({ _ in
            return XCTestExpectation(on: .queue(queue), onSuccess: promise, expectedValue: 42)
        })
        sema.signal()
        wait(for: expectations, timeout: 1, enforceOrder: true)
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
    
    func testPromiseContexts() {
        var expectations: [XCTestExpectation] = []
        let mainExpectation = XCTestExpectation(description: "main context")
        _ = Promise<Int,String>(on: .main, { (resolver) in
            XCTAssertTrue(Thread.isMainThread)
            mainExpectation.fulfill()
            resolver.fulfill(42)
        })
        expectations.append(mainExpectation)
        let bgContexts: [PromiseContext] = [.background, .utility, .default, .userInitiated, .userInteractive]
        expectations.append(contentsOf: bgContexts.map({ context in
            let expectation = XCTestExpectation(description: "\(context) context")
            _ = Promise<Int,String>(on: context, { (resolver) in
                XCTAssertFalse(Thread.isMainThread)
                expectation.fulfill()
                resolver.fulfill(42)
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
                resolver.fulfill(42)
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
                resolver.fulfill(42)
            })
            expectations.append(expectation)
        }
        var invoked = false
        _ = Promise<Int,String>(on: .immediate, { (resolver) in
            invoked = true
            resolver.fulfill(42)
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
            resolver.fulfill(42)
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
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(42)
        })
        let token = PromiseInvalidationToken()
        let expectation = XCTestExpectation(description: "promise success")
        _ = promise.then(on: .utility, token: token, { (x) in
            XCTFail("invalidated callback invoked")
        }).always({ (_) in
            expectation.fulfill()
        })
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testInvalidationTokenInvalidateChainSuccess() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(42)
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
            resolver.reject("foo")
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
}

private let testQueueKey = DispatchSpecificKey<String>()
