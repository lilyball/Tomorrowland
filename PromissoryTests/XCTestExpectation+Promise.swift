//
//  XCTestExpectation+Promise.swift
//  PromissoryTests
//
//  Created by Kevin Ballard on 12/18/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import XCTest
import Promissory

extension XCTestExpectation {
    convenience init<T,E>(description: String? = nil, onSuccess promise: Promise<T,E>, handler: @escaping (T) -> Void) {
        self.init(description: description ?? "Expectation for \(type(of: promise)) success")
        assertForOverFulfill = true
        fulfill(onSuccess: promise, handler: handler)
    }
    
    convenience init<T,E>(description: String? = nil, onSuccess promise: Promise<T,E>, expectedValue: T) where T: Equatable {
        self.init(description: description, onSuccess: promise) { (value) in
            XCTAssertEqual(expectedValue, value, "Promise value")
        }
    }
    
    convenience init<T,E>(description: String? = nil, onError promise: Promise<T,E>, handler: @escaping (E) -> Void) {
        self.init(description: description ?? "Expectation for \(type(of: promise)) error")
        assertForOverFulfill = true
        fulfill(onError: promise, handler: handler)
    }
    
    convenience init<T,E>(description: String? = nil, onError promise: Promise<T,E>, expectedError: E) where E: Equatable {
        self.init(description: description, onError: promise) { (error) in
            XCTAssertEqual(expectedError, error, "Promise error")
        }
    }
    
    convenience init<T,E>(description: String? = nil, onCancel promise: Promise<T,E>) {
        self.init(description: description ?? "Expectation for \(type(of: promise)) cancel")
        assertForOverFulfill = true
        fulfill(onCancel: promise)
    }
    
    func fulfill<T,E>(onSuccess promise: Promise<T,E>, handler: @escaping (T) -> Void) {
        promise.always(on: .default) { (result) in
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
    
    func fulfill<T,E>(onSuccess promise: Promise<T,E>, expectedValue: T) where T: Equatable {
        fulfill(onSuccess: promise) { (value) in
            XCTAssertEqual(expectedValue, value, "Promise value")
        }
    }
    
    func fulfill<T,E>(onError promise: Promise<T,E>, handler: @escaping (E) -> Void) {
        promise.always(on: .default) { (result) in
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
    
    func fulfill<T,E>(onError promise: Promise<T,E>, expectedError: E) where E: Equatable {
        fulfill(onError: promise) { (error) in
            XCTAssertEqual(expectedError, error, "Promise error")
        }
    }
    
    func fulfill<T,E>(onCancel promise: Promise<T,E>) {
        promise.always(on: .default) { (result) in
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

func XCTAssertEqual<T,E>(_ lhs: PromiseResult<T,E>?, _ rhs: PromiseResult<T,E>?, message: String? = nil, file: StaticString = #file, line: UInt = #line)
    where T: Equatable, E: Equatable
{
    XCTAssert(lhs == rhs, "\(lhs.map(String.init(describing:)) ?? "nil") and \(rhs.map(String.init(describing:)) ?? "nil") are not equal\(message.map({ "; \($0)" }) ?? "")", file: file, line: line)
}
