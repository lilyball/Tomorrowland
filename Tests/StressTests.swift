//
//  StressTests.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 4/5/19.
//  Copyright © 2019 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Tomorrowland

/// Tests that may not be reliable or take a long time and are disabled by default.
final class StressTests: XCTestCase {
    /// Tests that blocks executed on the main context dealloc on the main context.
    func testMainContextBlockDeallocAfterExec() {
        let atomicBool = TWLAtomicBool()
        // Use a bunch of low-priority queues instead of the global one to try and get overcommit behavior
        let backgroundQueues = repeatElement({ DispatchQueue(label: "bg queue", qos: .background) }, count: 20).map({ $0() })
        /// Creates a spy that sets `atomicBool` iff it deinits on a background thread
        func makeSpy() -> DeinitSpy {
            return DeinitSpy(onDeinit: {
                if !Thread.isMainThread {
                    // We're not running on the main thread
                    atomicBool.value = true
                }
            })
        }
        // Hop onto a high-priority queue for the orchestration
        let expectation = XCTestExpectation(description: "done")
        DispatchQueue.global(qos: .userInteractive).async {
            defer { expectation.fulfill() }
            // Try a bunch of times
            for i in 1...200 {
                let group = DispatchGroup()
                for queue in backgroundQueues {
                    let promise = Promise<Int,String>(on: .queue(queue)) { (resolver) in
                        // busywork to make sure we're actually using up the CPU
                        var sum = 0
                        for _ in 0..<1000 {
                            sum += Int.random(in: 1...10_000)
                        }
                        withExtendedLifetime(sum) {}
                        resolver.fulfill(with: 42)
                    }
                    promise.always(on: .main) { [spy=makeSpy()] _ in
                        withExtendedLifetime(spy) {} // ensure spy isn't optimized away
                    }
                    group.enter()
                    queue.async {
                        group.leave()
                    }
                }
                group.wait()
                if atomicBool.value {
                    XCTFail("At least one main-context block dealloced on a background queue after \(i) iteration(s)")
                    break
                }
            }
        }
        wait(for: [expectation], timeout: 10)
    }
    
    /// Tests that blocks executed on the main context dealloc on the main context even with token
    /// invalidation.
    func testMainContextBlockDeallocAfterExecWithTokenInvalidation() {
        let atomicBool = TWLAtomicBool()
        // Use a bunch of low-priority queues instead of the global one to try and get overcommit behavior
        let backgroundQueues = repeatElement({ DispatchQueue(label: "bg queue", qos: .background) }, count: 20).map({ $0() })
        /// Creates a spy that sets `atomicBool` iff it deinits on a background thread
        func makeSpy() -> DeinitSpy {
            return DeinitSpy(onDeinit: {
                if !Thread.isMainThread {
                    // We're not running on the main thread
                    atomicBool.value = true
                }
            })
        }
        // Hop onto a high-priority queue for the orchestration
        let expectation = XCTestExpectation(description: "done")
        DispatchQueue.global(qos: .userInteractive).async {
            defer { expectation.fulfill() }
            // Try a bunch of times
            for i in 1...200 {
                let group = DispatchGroup()
                let sema = DispatchSemaphore(value: 0)
                let token = PromiseInvalidationToken()
                for queue in backgroundQueues {
                    let promise = Promise<Int,String>(on: .queue(queue)) { (resolver) in
                        // busywork to make sure we're actually using up the CPU
                        var sum = 0
                        for _ in 0..<1000 {
                            sum += Int.random(in: 1...10_000)
                        }
                        withExtendedLifetime(sum) {}
                        sema.wait()
                        resolver.fulfill(with: 42)
                    }
                    promise.always(on: .main, token: token) { [spy=makeSpy()] _ in
                        withExtendedLifetime(spy) {} // ensure spy isn't optimized away
                    }
                    group.enter()
                    queue.async {
                        group.leave()
                    }
                }
                token.invalidate()
                for _ in backgroundQueues {
                    sema.signal()
                }
                group.wait()
                if atomicBool.value {
                    XCTFail("At least one main-context block dealloced on a background queue after \(i) iteration(s)")
                    break
                }
            }
        }
        wait(for: [expectation], timeout: 10)
    }
    
    /// Tests that blocks executed on the main context dealloc on the main context.
    func testObjCMainContextBlockDeallocAfterExec() {
        let atomicBool = TWLAtomicBool()
        // Use a bunch of low-priority queues instead of the global one to try and get overcommit behavior
        let backgroundQueues = repeatElement({ DispatchQueue(label: "bg queue", qos: .background) }, count: 20).map({ $0() })
        /// Creates a spy that sets `atomicBool` iff it deinits on a background thread
        func makeSpy() -> DeinitSpy {
            return DeinitSpy(onDeinit: {
                if !Thread.isMainThread {
                    // We're not running on the target queue
                    atomicBool.value = true
                }
            })
        }
        // Hop onto a high-priority queue for the orchestration
        let expectation = XCTestExpectation(description: "done")
        DispatchQueue.global(qos: .userInteractive).async {
            defer { expectation.fulfill() }
            // Try a bunch of times
            for i in 1...200 {
                let group = DispatchGroup()
                for queue in backgroundQueues {
                    let promise = ObjCPromise<NSNumber,NSString>(on: .queue(queue)) { (resolver) in
                        // busywork to make sure we're actually using up the CPU
                        var sum = 0
                        for _ in 0..<1000 {
                            sum += Int.random(in: 1...10_000)
                        }
                        withExtendedLifetime(sum) {}
                        resolver.fulfill(with: 42)
                    }
                    promise.inspect(on: .main) { [spy=makeSpy()] (_, _) in
                        withExtendedLifetime(spy) {} // ensure spy isn't optimized away
                    }
                    group.enter()
                    queue.async {
                        group.leave()
                    }
                }
                group.wait()
                if atomicBool.value {
                    XCTFail("At least one main-context block dealloced on a background queue after \(i) iteration(s)")
                    break
                }
            }
        }
        wait(for: [expectation], timeout: 10)
    }
    
    /// Tests that blocks executed on the main context dealloc on the main context.
    func testObjCMainContextBlockDeallocAfterExecWithTokenInvalidation() {
        let atomicBool = TWLAtomicBool()
        // Use a bunch of low-priority queues instead of the global one to try and get overcommit behavior
        let backgroundQueues = repeatElement({ DispatchQueue(label: "bg queue", qos: .background) }, count: 20).map({ $0() })
        /// Creates a spy that sets `atomicBool` iff it deinits on a background thread
        func makeSpy() -> DeinitSpy {
            return DeinitSpy(onDeinit: {
                if !Thread.isMainThread {
                    // We're not running on the target queue
                    atomicBool.value = true
                }
            })
        }
        // Hop onto a high-priority queue for the orchestration
        let expectation = XCTestExpectation(description: "done")
        DispatchQueue.global(qos: .userInteractive).async {
            defer { expectation.fulfill() }
            // Try a bunch of times
            for i in 1...200 {
                let group = DispatchGroup()
                let sema = DispatchSemaphore(value: 0)
                let token = ObjCPromiseInvalidationToken()
                for queue in backgroundQueues {
                    let promise = ObjCPromise<NSNumber,NSString>(on: .queue(queue)) { (resolver) in
                        // busywork to make sure we're actually using up the CPU
                        var sum = 0
                        for _ in 0..<1000 {
                            sum += Int.random(in: 1...10_000)
                        }
                        withExtendedLifetime(sum) {}
                        sema.wait()
                        resolver.fulfill(with: 42)
                    }
                    promise.inspect(on: .main, token: token) { [spy=makeSpy()] (_, _) in
                        withExtendedLifetime(spy) {} // ensure spy isn't optimized away
                    }
                    group.enter()
                    queue.async {
                        group.leave()
                    }
                }
                token.invalidate()
                for _ in backgroundQueues {
                    sema.signal()
                }
                group.wait()
                if atomicBool.value {
                    XCTFail("At least one main-context block dealloced on a background queue after \(i) iteration(s)")
                    break
                }
            }
        }
        wait(for: [expectation], timeout: 10)
    }
}

