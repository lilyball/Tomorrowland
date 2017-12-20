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
    
    // Test to make sure `then(on: context, { /* return a fulfilled promise */ })` returns an already-fulfilled promise.
    
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
}
