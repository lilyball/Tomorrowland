//
//  PromiseUtilitiesTests.swift
//  PromissoryTests
//
//  Created by Ballard, Kevin on 12/20/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import XCTest
import Promissory

final class PromiseUtilitiesTests: XCTestCase {
    func testWhen() {
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                resolver.fulfill(x * 2)
            })
        })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
            XCTAssertEqual(values, [2,4,6,8,10])
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenRejected() {
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.reject("error")
                } else {
                    resolver.fulfill(x * 2)
                }
            })
        })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onError: promise, expectedError: "error")
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenCancelled() {
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.cancel()
                } else {
                    resolver.fulfill(x * 2)
                }
            })
        })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenRejectedCancelsInput() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promisesAndExpectations = (1...5).map({ x -> (Promise<Int,String>, XCTestExpectation) in
            let expectation = XCTestExpectation(description: "promise \(x)")
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.reject("error")
                    expectation.fulfill()
                } else {
                    resolver.onRequestCancel(on: .immediate) { (resolver) in
                        resolver.cancel()
                        expectation.fulfill()
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(x * 2)
                }
            })
            return (promise, expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onError: promise, expectedError: "error")
        wait(for: [expectation] + expectations, timeout: 1)
    }
    
    func testWhenCancelledCancelsInput() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promisesAndExpectations = (1...5).map({ x -> (Promise<Int,String>, XCTestExpectation) in
            let expectation = XCTestExpectation(description: "promise \(x)")
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.cancel()
                    expectation.fulfill()
                } else {
                    resolver.onRequestCancel(on: .immediate) { (resolver) in
                        resolver.cancel()
                        expectation.fulfill()
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(x * 2)
                }
            })
            return (promise, expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation] + expectations, timeout: 1)
    }
    
    func testWhenEmptyInput() {
        let promise: Promise<[Int],String> = when(fulfilled: [])
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
            XCTAssertEqual([], values)
        })
        wait(for: [expectation], timeout: 1)
    }
}
