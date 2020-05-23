//
//  DelayedPromiseTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 12/26/17.
//  Copyright © 2017 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Tomorrowland

final class DelayedPromiseTests: XCTestCase {
    func testDelayedPromiseResolves() {
        let dp = DelayedPromise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        })
        let promise = dp.promise
        let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
        wait(for: [expectation], timeout: 1)
    }
    
    func testDelayedPromiseDelays() {
        var invoked = false
        let dp = DelayedPromise<Int,String>(on: .immediate, { (resolver) in
            invoked = true
            resolver.fulfill(with: 42)
        })
        XCTAssertFalse(invoked)
        _ = dp.promise
        XCTAssertTrue(invoked)
    }
    
    func testDelayedPromiseReturnsSamePromise() {
        let dp = DelayedPromise<Int,String>(on: .utility, { (resolver) in
            resolver.fulfill(with: 42)
        })
        let promiseA = dp.promise
        let promiseB = dp.promise
        XCTAssertEqual(promiseA, promiseB)
        let expectationA = XCTestExpectation(onSuccess: promiseA, expectedValue: 42)
        let expectationB = XCTestExpectation(onSuccess: promiseB, expectedValue: 42)
        wait(for: [expectationA, expectationB], timeout: 1)
    }
    
    func testDelayedPromiseDropsCallbackAfterInvocation() {
        let dropExpectation = XCTestExpectation(description: "callback dropped")
        let notDroppedExpectation = XCTestExpectation(description: "callback not yet dropped")
        notDroppedExpectation.isInverted = true
        var dropSpy: DropSpy? = DropSpy(onDrop: {
            dropExpectation.fulfill()
            notDroppedExpectation.fulfill()
        })
        let dp = DelayedPromise<Int,String>(on: .utility, { [dropSpy] (resolver) in
            withExtendedLifetime(dropSpy, {
                resolver.fulfill(with: 42)
            })
        })
        dropSpy = nil
        wait(for: [notDroppedExpectation], timeout: 0) // ensure DropSpy is held by dp
        _ = dp.promise
        withExtendedLifetime(dp) {
            wait(for: [dropExpectation], timeout: 1)
        }
    }
    
    func testDelayedPromiseDropsCallbackIfReleased() {
        let dropExpectation = XCTestExpectation(description: "callback dropped")
        let notDroppedExpectation = XCTestExpectation(description: "callback not yet dropped")
        notDroppedExpectation.isInverted = true
        var dropSpy: DropSpy? = DropSpy(onDrop: {
            dropExpectation.fulfill()
            notDroppedExpectation.fulfill()
        })
        var dp = Optional(DelayedPromise<Int,String>(on: .utility, { [dropSpy] (resolver) in
            withExtendedLifetime(dropSpy, {
                resolver.fulfill(with: 42)
            })
        }))
        _ = dp // suppress "variable never read" warning
        dropSpy = nil
        wait(for: [notDroppedExpectation], timeout: 0) // ensure DropSpy is held by dp
        dp = nil
        wait(for: [dropExpectation], timeout: 0) // dropSpy should be dropped now
    }
    
    func testDelayedPromiseUsingNowOr() {
        // .nowOr doesn't ever run now when used with DelayedPromise
        let expectation = XCTestExpectation()
        let dp = DelayedPromise<Int,String>(on: .nowOr(.queue(TestQueue.two)), { (resolver) in
            TestQueue.assert(on: .two)
            expectation.fulfill()
        })
        _ = dp.promise
        wait(for: [expectation], timeout: 1)
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
