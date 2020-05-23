//
//  PrivateTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 1/2/18.
//  Copyright © 2018 Lily Ballard.
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
    func testMainContextThreadLocalFlag() {
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
    
    func testSynchronousContextThreadLocalFlag() {
        XCTAssertFalse(TWLGetSynchronousContextThreadLocalFlag())
        TWLExecuteBlockWithSynchronousContextThreadLocalFlag(true) {
            XCTAssertTrue(TWLGetSynchronousContextThreadLocalFlag())
            // Nesting identical values should work
            TWLExecuteBlockWithSynchronousContextThreadLocalFlag(true) {
                XCTAssertTrue(TWLGetSynchronousContextThreadLocalFlag())
                // Nesting changed values should work
                TWLExecuteBlockWithSynchronousContextThreadLocalFlag(false) {
                    XCTAssertFalse(TWLGetSynchronousContextThreadLocalFlag())
                }
                XCTAssertTrue(TWLGetSynchronousContextThreadLocalFlag())
            }
            XCTAssertTrue(TWLGetSynchronousContextThreadLocalFlag())
            
            let expectation = XCTestExpectation()
            DispatchQueue.global(qos: .default).async {
                // Different thread
                XCTAssertFalse(TWLGetSynchronousContextThreadLocalFlag())
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
            // Sanity check
            XCTAssertTrue(TWLGetSynchronousContextThreadLocalFlag())
        }
        XCTAssertFalse(TWLGetSynchronousContextThreadLocalFlag())
    }
}
