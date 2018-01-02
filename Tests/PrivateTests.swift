//
//  PrivateTests.swift
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 1/2/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
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
