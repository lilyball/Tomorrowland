//
//  EnforceContextTests.swift
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 12/28/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Dispatch
import Tomorrowland

private let specificKey = DispatchSpecificKey<Bool>()

final class EnforceContextTests: XCTestCase {
    private let queue = DispatchQueue(label: "test queue")
    
    override func setUp() {
        super.setUp()
        queue.setSpecific(key: specificKey, value: true)
    }
    
    func testThen() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).then(on: .queue(queue), { (x) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: x + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertEqual(x, 43)
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).then(on: .queue(queue), options: [.enforceContext], { (x) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: x + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertEqual(x, 43)
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testRecover() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(rejected: "foo").recover(on: .queue(queue), { (err) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.reject(with: err + "bar")
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onError: promise, handler: { (x) in
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(rejected: "foo").recover(on: .queue(queue), options: [.enforceContext], { (err) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.reject(with: err + "bar")
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onError: promise, handler: { (x) in
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testAlways() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).always(on: .queue(queue), { (result) -> Promise<Int,String> in
                sema.wait()
                guard let value = result.value else {
                    XCTFail()
                    return Promise(rejected: "error")
                }
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: value + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertEqual(x, 43)
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).always(on: .queue(queue), options: [.enforceContext], { (result) -> Promise<Int,String> in
                sema.wait()
                guard let value = result.value else {
                    XCTFail()
                    return Promise(rejected: "error")
                }
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: value + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertEqual(x, 43)
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testAlwaysCompatibleError() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).always(on: .queue(queue), { (result) -> Promise<Int,String> in
                sema.wait()
                guard let value = result.value else {
                    XCTFail()
                    return Promise(rejected: "error")
                }
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: value + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertEqual(x, 43)
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).always(on: .queue(queue), options: [.enforceContext], { (result) -> Promise<Int,String> in
                sema.wait()
                guard let value = result.value else {
                    XCTFail()
                    return Promise(rejected: "error")
                }
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: value + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertEqual(x, 43)
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testAlwaysStdError() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).always(on: .queue(queue), { (result) -> Promise<Int,String> in
                sema.wait()
                guard let value = result.value else {
                    XCTFail()
                    return Promise(rejected: "error")
                }
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: value + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertEqual(x, 43)
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).always(on: .queue(queue), options: [.enforceContext], { (result) -> Promise<Int,String> in
                sema.wait()
                guard let value = result.value else {
                    XCTFail()
                    return Promise(rejected: "error")
                }
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: value + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertEqual(x, 43)
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testThenStdError() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).then(on: .queue(queue), { (x) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: x + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).then(on: .queue(queue), options: [.enforceContext], { (x) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: x + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testThenCompatibleError() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).then(on: .queue(queue), { (x) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: x + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(fulfilled: 42).then(on: .queue(queue), options: [.enforceContext], { (x) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.fulfill(with: x + 1)
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onSuccess: promise, handler: { (x) in
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testRecoverStdError() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(rejected: "foo").recover(on: .queue(queue), { (err) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.reject(with: err + "bar")
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onError: promise, handler: { (x) in
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(rejected: "foo").recover(on: .queue(queue), options: [.enforceContext], { (err) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.reject(with: err + "bar")
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onError: promise, handler: { (x) in
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testRecoverCompatibleError() {
        // not enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(rejected: "foo").recover(on: .queue(queue), { (err) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.reject(with: err + "bar")
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onError: promise, handler: { (x) in
                XCTAssertFalse(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        
        // enforcing
        do {
            let sema = DispatchSemaphore(value: 0)
            let promise = Promise<Int,String>(rejected: "foo").recover(on: .queue(queue), options: [.enforceContext], { (err) -> Promise<Int,String> in
                sema.wait()
                return Promise(on: .utility, { (resolver) in
                    resolver.reject(with: err + "bar")
                })
            })
            let expectation = XCTestExpectation(on: .immediate, onError: promise, handler: { (x) in
                XCTAssertTrue(DispatchQueue.getSpecific(key: specificKey) ?? false)
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
}
