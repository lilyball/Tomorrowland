//
//  XCTestExpectation+Promise.swift
//  PromissoryTests
//
//  Created by Kevin Ballard on 12/18/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import Promissory

extension XCTestExpectation {
    convenience init<T,E>(description: String? = nil, on context: PromiseContext = .default, onSuccess promise: Promise<T,E>, handler: @escaping (T) -> Void) {
        self.init(description: description ?? "Expectation for \(type(of: promise)) success")
        assertForOverFulfill = true
        fulfill(on: context, onSuccess: promise, handler: handler)
    }
    
    convenience init<T,E>(description: String? = nil, on context: PromiseContext = .default, onSuccess promise: Promise<T,E>, expectedValue: T) where T: Equatable {
        self.init(description: description, on: context, onSuccess: promise) { (value) in
            XCTAssertEqual(expectedValue, value, "Promise value")
        }
    }
    
    convenience init<T,E>(description: String? = nil, on context: PromiseContext = .default, onError promise: Promise<T,E>, handler: @escaping (E) -> Void) {
        self.init(description: description ?? "Expectation for \(type(of: promise)) error")
        assertForOverFulfill = true
        fulfill(on: context, onError: promise, handler: handler)
    }
    
    convenience init<T,E>(description: String? = nil, on context: PromiseContext = .default, onError promise: Promise<T,E>, expectedError: E) where E: Equatable {
        self.init(description: description, on: context, onError: promise) { (error) in
            XCTAssertEqual(expectedError, error, "Promise error")
        }
    }
    
    convenience init<T,E>(description: String? = nil, on context: PromiseContext = .default, onCancel promise: Promise<T,E>) {
        self.init(description: description ?? "Expectation for \(type(of: promise)) cancel")
        assertForOverFulfill = true
        fulfill(on: context, onCancel: promise)
    }
    
    func fulfill<T,E>(on context: PromiseContext = .default, onSuccess promise: Promise<T,E>, handler: @escaping (T) -> Void) {
        promise.always(on: context) { (result) in
            switch result {
            case .value(let value):
                handler(value)
                self.fulfill()
            case .error(let error):
                XCTFail("Expected Promise success, got error \(error)")
                self.fulfill()
            case .cancelled:
                XCTFail("Expected Promise success, got cancellation")
                self.fulfill()
            }
        }
    }
    
    func fulfill<T,E>(on context: PromiseContext = .default, onSuccess promise: Promise<T,E>, expectedValue: T) where T: Equatable {
        fulfill(on: context, onSuccess: promise) { (value) in
            XCTAssertEqual(expectedValue, value, "Promise value")
        }
    }
    
    func fulfill<T,E>(on context: PromiseContext = .default, onError promise: Promise<T,E>, handler: @escaping (E) -> Void) {
        promise.always(on: context) { (result) in
            switch result {
            case .value(let value):
                XCTFail("Expected Promise failure, got value \(value)")
                self.fulfill()
            case .error(let error):
                handler(error)
                self.fulfill()
            case .cancelled:
                XCTFail("Expected Promise success, got cancellation")
                self.fulfill()
            }
        }
    }
    
    func fulfill<T,E>(on context: PromiseContext = .default, onError promise: Promise<T,E>, expectedError: E) where E: Equatable {
        fulfill(on: context, onError: promise) { (error) in
            XCTAssertEqual(expectedError, error, "Promise error")
        }
    }
    
    func fulfill<T,E>(on context: PromiseContext = .default, onCancel promise: Promise<T,E>) {
        promise.always(on: context) { (result) in
            switch result {
            case .value(let value):
                XCTFail("Expected Promise cancellation, got value: \(value)")
                self.fulfill()
            case .error(let error):
                XCTFail("Expected Promise cancellation, got error \(error)")
                self.fulfill()
            case .cancelled:
                self.fulfill()
            }
        }
    }
}

func XCTAssertEqual<T,E>(_ lhs: PromiseResult<T,E>?, _ rhs: PromiseResult<T,E>?, _ message: String? = nil, file: StaticString = #file, line: UInt = #line)
    where T: Equatable, E: Equatable
{
    XCTAssert(lhs == rhs, "\(lhs.map(String.init(describing:)) ?? "nil") and \(rhs.map(String.init(describing:)) ?? "nil") are not equal\(message.map({ "; \($0)" }) ?? "")", file: file, line: line)
}
