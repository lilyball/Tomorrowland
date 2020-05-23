//
//  XCTestCase+Helpers.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 5/22/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest

/// A collection of test queues for use in the tests.
/// Each queue can be tested to see if it's currently being executed on.
@objc final class TestQueue: NSObject {
    @objc static let one: DispatchQueue = {
        let queue = DispatchQueue(label: "test queue 1")
        queue.setSpecific(key: key, value: .one)
        return queue
    }()
    @objc static let two: DispatchQueue = {
        let queue = DispatchQueue(label: "test queue 2")
        queue.setSpecific(key: key, value: .two)
        return queue
    }()
    
    /// Returns the current queue, or `nil` if we're not on any of the queues.
    @objc(currentQueue)
    static var current: DispatchQueue? {
        return DispatchQueue.getSpecific(key: key).flatMap(queue(for:))
    }
    
    static func assert(on identifier: Identifier, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(current, queue(for: identifier), "current queue", file: file, line: line)
    }
    
    @objc(queueForIdentifier:)
    static func queue(for identifier: Identifier) -> DispatchQueue? {
        switch identifier {
        case .one: return self.one
        case .two: return self.two
        @unknown default: return nil
        }
    }
    
    @objc(TestQueueIdentifier)
    enum Identifier: Int {
        case one = 1
        case two = 2
    }
    
    private static let key = DispatchSpecificKey<Identifier>()
}
