//
//  PrivateTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 1/2/18.
//  Copyright © 2018 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Tomorrowland.Private

final class PrivateTests: XCTestCase {
    func testThreadLocalFlag() {
        defer { TWLSetMainContextThreadLocalFlag(false) }
        
        let expectation = XCTestExpectation(description: "done")
        DispatchQueue.main.async {
            XCTAssertFalse(TWLGetMainContextThreadLocalFlag())
            TWLSetMainContextThreadLocalFlag(true)
            DispatchQueue.global().async {
                XCTAssertFalse(TWLGetMainContextThreadLocalFlag())
                DispatchQueue.main.async {
                    XCTAssertTrue(TWLGetMainContextThreadLocalFlag())
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 1)
    }
}
