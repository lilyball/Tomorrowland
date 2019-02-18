//
//  TokenPromiseTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 5/13/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Tomorrowland

final class TokenPromiseTests: XCTestCase {
    func testWithTokenRoundtrip() {
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        })
        XCTAssertEqual(promise, promise.withToken(PromiseInvalidationToken()).inner)
    }
    
    func testMapInvalidate() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let token = PromiseInvalidationToken()
        let chainPromise = promise.withToken(token).map(on: .utility, { (x) in
            XCTFail("invalidated callback invoked")
        })
        let expectation = XCTestExpectation(onCancel: chainPromise.inner)
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testCancelsChildOnInvalidate() {
        let sema = DispatchSemaphore(value: 0)
        let expectation = XCTestExpectation(description: "cancel")
        let token: PromiseInvalidationToken, expectation2: XCTestExpectation
        do {
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                resolver.onRequestCancel(on: .utility, { (resolver) in
                    expectation.fulfill()
                    resolver.cancel()
                })
                sema.wait()
                resolver.fulfill(with: 42)
            })
            expectation2 = XCTestExpectation(onCancel: promise)
            token = PromiseInvalidationToken()
            _ = promise.withToken(token).map(on: .default, { $0 })
        }
        token.invalidate()
        wait(for: [expectation, expectation2], timeout: 1)
        sema.signal()
    }
    
    func testDoesNotCancelParentOnInvalidateWithoutChild() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .utility, { (resolver) in
            resolver.onRequestCancel(on: .utility, { (resolver) in
                XCTFail("Unexpected cancel")
            })
            sema.wait()
            resolver.fulfill(with: 42)
        })
        let token = PromiseInvalidationToken()
        let tokenPromise = promise.withToken(token)
        let expectation = XCTestExpectation(onSuccess: tokenPromise.inner, expectedValue: 42)
        token.invalidate()
        sema.signal()
        wait(for: [expectation], timeout: 1)
    }
    
    func testSuppressesAlwaysWhileCancelling() {
        let sema = DispatchSemaphore(value: 0)
        let expectation = XCTestExpectation(description: "cancel")
        let token: PromiseInvalidationToken, expectation2: XCTestExpectation
        do {
            token = PromiseInvalidationToken()
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                resolver.onRequestCancel(on: .utility, { (resolver) in
                    expectation.fulfill()
                    resolver.cancel()
                })
                sema.wait()
                resolver.fulfill(with: 42)
            })
                .withToken(token)
                .always({ (result) in
                    XCTFail("Unexpected always")
                })
                .inner
            expectation2 = XCTestExpectation(onCancel: promise)
        }
        token.invalidate()
        wait(for: [expectation, expectation2], timeout: 1)
        sema.signal()
    }
}
