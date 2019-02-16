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
}
