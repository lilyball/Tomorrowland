//
//  WhenTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 12/20/17.
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

final class WhenArrayTests: XCTestCase {
    func testWhen() {
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                resolver.fulfill(with: x * 2)
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
                    resolver.reject(with: "error")
                } else {
                    resolver.fulfill(with: x * 2)
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
                    resolver.fulfill(with: x * 2)
                }
            })
        })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenRejectedWithCancelOnFailureCancelsInput() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promisesAndExpectations = (1...5).map({ x -> (Promise<Int,String>, XCTestExpectation) in
            let expectation = XCTestExpectation(description: "promise \(x)")
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.reject(with: "error")
                    expectation.fulfill()
                } else {
                    resolver.onRequestCancel(on: .immediate) { (resolver) in
                        resolver.cancel()
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(with: x * 2)
                }
            })
            if x != 3 {
                expectation.fulfill(onCancel: promise)
            }
            return (promise, expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(fulfilled: promises, cancelOnFailure: true)
        let expectation = XCTestExpectation(onError: promise, expectedError: "error")
        wait(for: expectations + [expectation], timeout: 1)
        sema.signal() // let the promises empty out
    }
    
    func testWhenCancelledWithCancelOnFailureCancelsInput() {
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
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(with: x * 2)
                }
            })
            if x != 3 {
                expectation.fulfill(onCancel: promise)
            }
            return (promise, expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(fulfilled: promises, cancelOnFailure: true)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: expectations + [expectation], timeout: 1)
        sema.signal() // let the promises empty out
    }
    
    func testWhenCancelledByDefaultDoesntCancelInput() {
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
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(with: x * 2)
                }
            })
            if x != 3 {
                expectation.fulfill(onSuccess: promise, expectedValue: x * 2)
            }
            return (promise, expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(fulfilled: promises)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
        sema.signal() // let the promises empty out
        wait(for: expectations, timeout: 1)
    }
    
    func testWhenEmptyInput() {
        let promise: Promise<[Int],String> = when(fulfilled: [])
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
            XCTAssertEqual([], values)
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenDuplicatePromise() {
        let dummy = Promise<Int,String>(fulfilled: 42)
        let promise: Promise<[Int],String> = when(fulfilled: [dummy, dummy, dummy])
        let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
            XCTAssertEqual(values, [42, 42, 42])
        })
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenCancelPropagation() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promise: Promise<[Int],String>
        let expectations: [XCTestExpectation]
        do {
            let promisesAndExpectations = (1...3).map({ (_) -> (Promise<Int,String>, XCTestExpectation) in
                let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        resolver.cancel()
                    })
                    DispatchQueue.global(qos: .utility).async {
                        sema.wait()
                        sema.signal()
                        resolver.reject(with: "foo")
                    }
                })
                let expectation = XCTestExpectation(onCancel: promise)
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            expectations = promisesAndExpectations.map({ $0.1 })
            promise = when(fulfilled: promises)
        }
        promise.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testWhenCancelPropagationCancelOnFailure() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promise: Promise<[Int],String>
        let expectations: [XCTestExpectation]
        do {
            let promisesAndExpectations = (1...3).map({ (_) -> (Promise<Int,String>, XCTestExpectation) in
                let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        resolver.cancel()
                    })
                    DispatchQueue.global(qos: .utility).async {
                        sema.wait()
                        sema.signal()
                        resolver.reject(with: "foo")
                    }
                })
                let expectation = XCTestExpectation(onCancel: promise)
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            expectations = promisesAndExpectations.map({ $0.1 })
            promise = when(fulfilled: promises, cancelOnFailure: true)
        }
        promise.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
}

final class WhenTupleTests: XCTestCase {
    func testWhen() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>, splat: @escaping (Value) -> [Int]) {
            let promises = (1...n).map({ x -> Promise<Int,String> in
                Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: x * 2)
                })
            })
            let promise = when(promises)
            let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
                let ary = splat(values)
                XCTAssertEqual(ary, Array([2,4,6,8,10,12].prefix(ary.count)))
            })
            wait(for: [expectation], timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) }, splat: splat)
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) }, splat: splat)
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) }, splat: splat)
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) }, splat: splat)
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) }, splat: splat)
    }
    
    func testWhenRejected() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let promises = (1...n).map({ x -> Promise<Int,String> in
                Promise(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.reject(with: "error")
                    } else {
                        resolver.fulfill(with: x * 2)
                    }
                })
            })
            let promise = when(promises)
            let expectation = XCTestExpectation(onError: promise, expectedError: "error")
            wait(for: [expectation], timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) })
    }
    
    func testWhenCancelled() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let promises = (1...n).map({ x -> Promise<Int,String> in
                Promise(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.cancel()
                    } else {
                        resolver.fulfill(with: x * 2)
                    }
                })
            })
            let promise = when(promises)
            let expectation = XCTestExpectation(onCancel: promise)
            wait(for: [expectation], timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) })
    }
    
    func testWhenRejectedWithCancelOnFailureCancelsInput() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let sema = DispatchSemaphore(value: 1)
            sema.wait()
            let promisesAndExpectations = (1...n).map({ x -> (Promise<Int,String>, XCTestExpectation) in
                let expectation = XCTestExpectation(description: "promise \(x)")
                let promise = Promise<Int,String>(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.reject(with: "error")
                        expectation.fulfill()
                    } else {
                        resolver.onRequestCancel(on: .immediate) { (resolver) in
                            resolver.cancel()
                        }
                        sema.wait()
                        sema.signal()
                        resolver.fulfill(with: x * 2)
                    }
                })
                if x != 2 {
                    expectation.fulfill(onCancel: promise)
                }
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            let expectations = promisesAndExpectations.map({ $0.1 })
            let promise = when(promises)
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.always(on: .utility, { _ in expectation.fulfill() })
            wait(for: expectations + [expectation], timeout: 1)
            sema.signal() // let the promises empty out
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5], cancelOnFailure: true) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], cancelOnFailure: true) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], cancelOnFailure: true) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], cancelOnFailure: true) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1], cancelOnFailure: true) })
    }
    
    func testWhenCancelledWithCancelOnFailureCancelsInput() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let sema = DispatchSemaphore(value: 1)
            sema.wait()
            let promisesAndExpectations = (1...n).map({ x -> (Promise<Int,String>, XCTestExpectation) in
                let expectation = XCTestExpectation(description: "promise \(x)")
                let promise = Promise<Int,String>(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.cancel()
                        expectation.fulfill()
                    } else {
                        resolver.onRequestCancel(on: .immediate) { (resolver) in
                            resolver.cancel()
                        }
                        sema.wait()
                        sema.signal()
                        resolver.fulfill(with: x * 2)
                    }
                })
                if x != 2 {
                    expectation.fulfill(onCancel: promise)
                }
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            let expectations = promisesAndExpectations.map({ $0.1 })
            let promise = when(promises)
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.always(on: .utility, { _ in expectation.fulfill() })
            wait(for: expectations + [expectation], timeout: 1)
            sema.signal() // let the promises empty out
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5], cancelOnFailure: true) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], cancelOnFailure: true) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], cancelOnFailure: true) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], cancelOnFailure: true) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1], cancelOnFailure: true) })
    }
    
    func testWhenCancelledByDefaultDoesntCancelInput() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>) {
            let sema = DispatchSemaphore(value: 1)
            sema.wait()
            let promisesAndExpectations = (1...n).map({ x -> (Promise<Int,String>, XCTestExpectation) in
                let expectation = XCTestExpectation(description: "promise \(x)")
                let promise = Promise<Int,String>(on: .utility, { (resolver) in
                    if x == 2 {
                        resolver.cancel()
                        expectation.fulfill()
                    } else {
                        resolver.onRequestCancel(on: .immediate) { (resolver) in
                            resolver.cancel()
                        }
                        sema.wait()
                        sema.signal()
                        resolver.fulfill(with: x * 2)
                    }
                })
                if x != 2 {
                    expectation.fulfill(onSuccess: promise, expectedValue: x * 2)
                }
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            let expectations = promisesAndExpectations.map({ $0.1 })
            let promise = when(promises)
            let expectation = XCTestExpectation(description: "promise resolved")
            promise.always(on: .utility, { _ in expectation.fulfill() })
            wait(for: [expectation], timeout: 1)
            sema.signal() // let the promises empty out
            wait(for: expectations, timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) })
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) })
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) })
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) })
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) })
    }
    
    func testWhenDuplicatePromise() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>, splat: @escaping (Value) -> [Int]) {
            let dummy = Promise<Int,String>(fulfilled: 42)
            let promises = (1...n).map({ _ in dummy })
            let promise = when(promises)
            let expectation = XCTestExpectation(onSuccess: promise, handler: { (values) in
                let ary = splat(values)
                XCTAssertEqual(ary, Array([42,42,42,42,42,42].prefix(ary.count)))
            })
            wait(for: [expectation], timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) }, splat: splat)
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) }, splat: splat)
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) }, splat: splat)
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) }, splat: splat)
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) }, splat: splat)
    }
    
    func testWhenCancelPropagation() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>, splat: @escaping (Value) -> [Int]) {
            let sema = DispatchSemaphore(value: 1)
            sema.wait()
            let promise: Promise<Value,String>
            let expectations: [XCTestExpectation]
            do {
                let promisesAndExpectations = (1...n).map({ (_) -> (Promise<Int,String>, XCTestExpectation) in
                    let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                        resolver.onRequestCancel(on: .immediate, { (resolver) in
                            resolver.cancel()
                        })
                        DispatchQueue.global(qos: .utility).async {
                            sema.wait()
                            sema.signal()
                            resolver.reject(with: "foo")
                        }
                    })
                    let expectation = XCTestExpectation(onCancel: promise)
                    return (promise, expectation)
                })
                let promises = promisesAndExpectations.map({ $0.0 })
                expectations = promisesAndExpectations.map({ $0.1 })
                promise = when(promises)
            }
            promise.requestCancel()
            sema.signal()
            wait(for: expectations, timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5]) }, splat: splat)
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4]) }, splat: splat)
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3]) }, splat: splat)
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2]) }, splat: splat)
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1]) }, splat: splat)
    }
    
    func testWhenCancelPropagationCancelOnFailure() {
        func helper<Value>(n: Int, when: ([Promise<Int,String>]) -> Promise<Value,String>, splat: @escaping (Value) -> [Int]) {
            let sema = DispatchSemaphore(value: 1)
            sema.wait()
            let promise: Promise<Value,String>
            let expectations: [XCTestExpectation]
            do {
                let promisesAndExpectations = (1...n).map({ (_) -> (Promise<Int,String>, XCTestExpectation) in
                    let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                        resolver.onRequestCancel(on: .immediate, { (resolver) in
                            resolver.cancel()
                        })
                        DispatchQueue.global(qos: .utility).async {
                            sema.wait()
                            sema.signal()
                            resolver.reject(with: "foo")
                        }
                    })
                    let expectation = XCTestExpectation(onCancel: promise)
                    return (promise, expectation)
                })
                let promises = promisesAndExpectations.map({ $0.0 })
                expectations = promisesAndExpectations.map({ $0.1 })
                promise = when(promises)
            }
            promise.requestCancel()
            sema.signal()
            wait(for: expectations, timeout: 1)
        }
        helper(n: 6, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], ps[5], cancelOnFailure: true) }, splat: splat)
        helper(n: 5, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], ps[4], cancelOnFailure: true) }, splat: splat)
        helper(n: 4, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], ps[3], cancelOnFailure: true) }, splat: splat)
        helper(n: 3, when: { ps in when(fulfilled: ps[0], ps[1], ps[2], cancelOnFailure: true) }, splat: splat)
        helper(n: 2, when: { ps in when(fulfilled: ps[0], ps[1], cancelOnFailure: true) }, splat: splat)
    }
}

final class WhenFirstTests: XCTestCase {
    func testWhen() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                if x != 3 {
                    sema.wait()
                    sema.signal()
                }
                resolver.fulfill(with: x * 2)
            })
        })
        let promise = when(first: promises)
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 6)
        wait(for: [expectation], timeout: 1)
        sema.signal()
    }
    
    func testWhenRejected() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.reject(with: "foo")
                } else {
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(with: x * 2)
                }
            })
        })
        let promise = when(first: promises)
        let expectation = XCTestExpectation(onError: promise, expectedError: "foo")
        wait(for: [expectation], timeout: 1)
        sema.signal()
    }
    
    func testWhenCancelled() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.cancel()
                } else {
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(with: x * 2)
                }
            })
        })
        let promise = when(first: promises)
        let expectation = XCTestExpectation(onSuccess: promise, handler: { _ in })
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenAllCancelled() {
        let promises = (1...5).map({ x -> Promise<Int,String> in
            Promise(on: .utility, { (resolver) in
                resolver.cancel()
            })
        })
        let promise = when(first: promises)
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenCancelRemaining() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promisesAndExpectations = (1...5).map({ x -> (Promise<Int,String>,XCTestExpectation) in
            let expectation = XCTestExpectation(description: "promise \(x)")
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                if x == 3 {
                    resolver.fulfill(with: x * 2)
                    expectation.fulfill()
                } else {
                    resolver.onRequestCancel(on: .immediate) { (resolver) in
                        resolver.cancel()
                    }
                    sema.wait()
                    sema.signal()
                    resolver.fulfill(with: x * 2)
                }
            })
            if x != 3 {
                expectation.fulfill(onCancel: promise)
            }
            return (promise,expectation)
        })
        let promises = promisesAndExpectations.map({ $0.0 })
        let expectations = promisesAndExpectations.map({ $0.1 })
        let promise = when(first: promises, cancelRemaining: true)
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 6)
        wait(for: expectations + [expectation], timeout: 1)
        sema.signal()
    }
    
    func testWhenEmptyInput() {
        let promise: Promise<Int,String> = when(first: [])
        let expectation = XCTestExpectation(onCancel: promise)
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenDuplicateInput() {
        let dummy = Promise<Int,String>(fulfilled: 42)
        let promise = when(first: [dummy, dummy, dummy])
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [expectation], timeout: 1)
    }
    
    func testWhenCancelPropagation() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promise: Promise<Int,String>
        let expectations: [XCTestExpectation]
        do {
            let promisesAndExpectations = (1...3).map({ (_) -> (Promise<Int,String>, XCTestExpectation) in
                let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        resolver.cancel()
                    })
                    DispatchQueue.global(qos: .utility).async {
                        sema.wait()
                        sema.signal()
                        resolver.reject(with: "foo")
                    }
                })
                let expectation = XCTestExpectation(onCancel: promise)
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            expectations = promisesAndExpectations.map({ $0.1 })
            promise = when(first: promises)
        }
        promise.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testWhenCancelPropagationCancelRemaining() {
        let sema = DispatchSemaphore(value: 1)
        sema.wait()
        let promise: Promise<Int,String>
        let expectations: [XCTestExpectation]
        do {
            let promisesAndExpectations = (1...3).map({ (_) -> (Promise<Int,String>, XCTestExpectation) in
                let promise = Promise<Int,String>(on: .immediate, { (resolver) in
                    resolver.onRequestCancel(on: .immediate, { (resolver) in
                        resolver.cancel()
                    })
                    DispatchQueue.global(qos: .utility).async {
                        sema.wait()
                        sema.signal()
                        resolver.reject(with: "foo")
                    }
                })
                let expectation = XCTestExpectation(onCancel: promise)
                return (promise, expectation)
            })
            let promises = promisesAndExpectations.map({ $0.0 })
            expectations = promisesAndExpectations.map({ $0.1 })
            promise = when(first: promises, cancelRemaining: true)
        }
        promise.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
}

private func splat<T>(_ a: T, _ b: T, _ c: T, _ d: T, _ e: T, _ f: T) -> [T] {
    return [a,b,c,d,e,f]
}

private func splat<T>(_ a: T, _ b: T, _ c: T, _ d: T, _ e: T) -> [T] {
    return [a,b,c,d,e]
}

private func splat<T>(_ a: T, _ b: T, _ c: T, _ d: T) -> [T] {
    return [a,b,c,d]
}

private func splat<T>(_ a: T, _ b: T, _ c: T) -> [T] {
    return [a,b,c]
}

private func splat<T>(_ a: T, _ b: T) -> [T] {
    return [a,b]
}
