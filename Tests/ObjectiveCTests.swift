//
//  ObjectiveCTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 2/4/18.
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

final class ObjectiveCTests: XCTestCase {
    func testRequestCancelOnDeinit() {
        let sema = DispatchSemaphore(value: 0)
        let promise = Promise<Int,String>(on: .immediate, { (resolver) in
            resolver.onRequestCancel(on: .immediate, { (resolver) in
                resolver.cancel()
            })
            DispatchQueue.global(qos: .utility).async {
                sema.wait()
                resolver.fulfill(with: 42)
            }
        })
        XCTAssertNil(promise.result)
        autoreleasepool {
            let object = NSObject()
            withExtendedLifetime(object) {
                promise.requestCancelOnDeinit(object)
                XCTAssertNil(promise.result)
            }
        }
        XCTAssertEqual(promise.result, .cancelled)
        sema.signal()
    }
    
    func testThenCallbackDeinited() {
        // We're doing special things with callback lifetimes, so let's just make sure we aren't
        // leaking it.
        do {
            // When it executes
            let sema = DispatchSemaphore(value: 0)
            let promise = ObjCPromise<NSNumber,NSString>(on: .defaultQoS, { (resolver) in
                sema.wait()
                resolver.fulfill(with: 42)
            })
            let notYet = XCTestExpectation(description: "spy deinited")
            notYet.isInverted = true
            let expectation = XCTestExpectation(description: "then block deinited")
            _ = promise.then(on: .main, { [spy=DeinitSpy(onDeinit: { notYet.fulfill(); expectation.fulfill() })] _ in
                self.wait(for: [notYet], timeout: 0) // sanity check to make sure the spy is alive
                withExtendedLifetime(spy) {} // ensure we don't optimize away the spy
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
        do {
            // When it doesn't execute
            let sema = DispatchSemaphore(value: 0)
            let promise = ObjCPromise<NSNumber,NSString>(on: .defaultQoS, { (resolver) in
                sema.wait()
                resolver.reject(with: "foobar")
            })
            let notYet = XCTestExpectation(description: "spy deinited")
            notYet.isInverted = true
            let expectation = XCTestExpectation(description: "then block deinited")
            _ = promise.then(on: .main, { [spy=DeinitSpy(onDeinit: { notYet.fulfill(); expectation.fulfill() })] _ in
                self.wait(for: [notYet], timeout: 0) // sanity check to make sure the spy is alive
                withExtendedLifetime(spy) {} // ensure we don't optimize away the spy
            })
            sema.signal()
            wait(for: [expectation], timeout: 1)
        }
    }
}
