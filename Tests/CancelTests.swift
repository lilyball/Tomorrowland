//
//  CancelTests.swift
//  TomorrowlandTests
//
//  Created by Ballard, Kevin on 12/22/17.
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

final class CancelTests: XCTestCase {
    func testRequestCancelOnInvalidate() {
        let (promise, sema) = StdPromise.makeCancellablePromise(value: 2)
        let token = PromiseInvalidationToken()
        token.requestCancelOnInvalidate(promise)
        let expectation = XCTestExpectation(onCancel: promise)
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testRequestCancelOnInvalidateMultipleBlocks() {
        let token = PromiseInvalidationToken()
        let expectationsAndSemas = (1...5).map({ x -> (XCTestExpectation, DispatchSemaphore) in
            let (promise, sema) = StdPromise.makeCancellablePromise(value: 2)
            token.requestCancelOnInvalidate(promise)
            return (XCTestExpectation(onCancel: promise), sema)
        })
        token.invalidate()
        for sema in expectationsAndSemas.map({ $0.1 }) {
            sema.signal()
        }
        wait(for: expectationsAndSemas.map({ $0.0 }), timeout: 1)
    }
    
    func testLinkCancelThen() {
        let (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
        let promise2 = promise.then(on: .utility, options: [.linkCancel], { (x) in
            XCTFail("callback invoked")
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelThenReturningPromise() {
        let (promise, sema) = Promise<Int,String>.makeCancellablePromise(error: "foo")
        let promise2 = promise.then(on: .utility, options: [.linkCancel], { (x) -> Promise<String,String> in
            XCTFail("callback invoked")
            return Promise(fulfilled: "foo")
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelRecover() {
        let (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
        let promise2 = promise.recover(on: .utility, options: [.linkCancel], { (error) in
            XCTFail("callback invoked")
            return 42
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelRecoverReturningPromise() {
        let (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
        let promise2 = promise.recover(on: .utility, options: [.linkCancel], { (error) -> Promise<Int,String> in
            XCTFail("callback invoked")
            return Promise(fulfilled: 42)
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelAlwaysReturningPromise() {
        let (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
        let promise2 = promise.always(on: .utility, options: [.linkCancel], { (result) -> Promise<String,Int> in
            XCTAssertEqual(result, .cancelled)
            return Promise(fulfilled: "foo")
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onSuccess: promise2, handler: { _ in })]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelAlwaysReturningPromiseThrowingCompatibleError() {
        struct DummyError: Swift.Error {}
        let (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
        let promise2 = promise.tryAlways(on: .utility, options: [.linkCancel], { (result) -> Promise<String,DummyError> in
            XCTAssertEqual(result, .cancelled)
            throw DummyError()
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onError: promise2, handler: { _ in })]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelAlwaysReturningPromiseThrowingSwiftError() {
        let (promise, sema) = Promise<Int,String>.makeCancellablePromise(value: 2)
        let promise2 = promise.tryAlways(on: .utility, options: [.linkCancel], { (result) -> Promise<String,Swift.Error> in
            XCTAssertEqual(result, .cancelled)
            struct DummyError: Swift.Error {}
            throw DummyError()
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onError: promise2, handler: { _ in })]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelSwiftErrorThenThrowing() {
        struct DummyError: Swift.Error {}
        let (promise, sema) = StdPromise<Int>.makeCancellablePromise(error: DummyError())
        let promise2 = promise.tryThen(on: .utility, options: [.linkCancel], { (_) -> String in
            XCTFail("callback invoked")
            struct DummyError: Swift.Error {}
            throw DummyError()
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelSwiftErrorThenReturningPromiseThrowing() {
        struct DummyError: Swift.Error {}
        let (promise, sema) = StdPromise<Int>.makeCancellablePromise(error: DummyError())
        let promise2 = promise.tryThen(on: .utility, options: [.linkCancel], { (_) -> StdPromise<String> in
            XCTFail("callback invoked")
            struct DummyError: Swift.Error {}
            throw DummyError()
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelSwiftErrorThenReturningCompatiblePromiseThrowing() {
        struct DummyError: Swift.Error {}
        let (promise, sema) = StdPromise<Int>.makeCancellablePromise(error: DummyError())
        let promise2 = promise.tryThen(on: .utility, options: [.linkCancel], { (_) -> Promise<Int,DummyError> in
            XCTFail("callback invoked")
            throw DummyError()
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelSwiftErrorRecoverThrowing() {
        let (promise, sema) = StdPromise<Int>.makeCancellablePromise(value: 2)
        let promise2 = promise.tryRecover(on: .utility, options: [.linkCancel], { (_) -> Int in
            XCTFail("callback invoked")
            struct DummyError: Swift.Error {}
            throw DummyError()
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelSwiftErrorRecoverReturningPromiseThrowing() {
        let (promise, sema) = StdPromise<Int>.makeCancellablePromise(value: 2)
        let promise2 = promise.tryRecover(on: .utility, options: [.linkCancel], { (_) -> StdPromise<Int> in
            XCTFail("callback invoked")
            struct DummyError: Swift.Error {}
            throw DummyError()
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
    
    func testLinkCancelSwiftErrorRecoverReturningCompatiblePromiseThrowing() {
        struct DummyError: Swift.Error {}
        let (promise, sema) = StdPromise<Int>.makeCancellablePromise(value: 2)
        let promise2 = promise.tryRecover(on: .utility, options: [.linkCancel], { (_) -> Promise<Int,DummyError> in
            XCTFail("callback invoked")
            throw DummyError()
        })
        let expectations = [XCTestExpectation(onCancel: promise), XCTestExpectation(onCancel: promise2)]
        promise2.requestCancel()
        sema.signal()
        wait(for: expectations, timeout: 1)
    }
}

private extension Promise {
    static func makeCancellablePromise(value: Value) -> (Promise, DispatchSemaphore) {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Value,Error>(on: .utility, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            sema.wait()
            resolver.fulfill(with: value)
        })
        return (promise, sema)
    }
    
    static func makeCancellablePromise(error: Error) -> (Promise, DispatchSemaphore) {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Value,Error>(on: .utility, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            sema.wait()
            resolver.reject(with: error)
        })
        return (promise, sema)
    }
}
