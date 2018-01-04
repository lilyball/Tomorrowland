//
//  ObjCPromiseTests.swift
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 1/1/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//

import XCTest
import Foundation
import Tomorrowland

final class ObjCPromiseTests: XCTestCase {
    func testToObjC() {
        struct DummyError: Error {}
        struct StringError: Error {
            let message: String
        }
        
        do { // bridge where Value: AnyObject, Error: AnyObject
            let promise = Promise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            })
            let objcPromise = promise.objc()
            let _: ObjCPromise<NSNumber,NSString> = objcPromise // compile-time type assertion
            let expectation = XCTestExpectation(description: "objcPromise fulfilled")
            objcPromise.then { (value) in
                XCTAssertEqual(value as? Int, 42)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        
        do { // basic bridge fulfilled
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            })
            let objcPromise = promise.objc(mapValue: { $0 as NSNumber }, mapError: { $0 as NSString })
            let _: ObjCPromise<NSNumber,NSString> = objcPromise // compile-time type assertion
            let expectation = XCTestExpectation(description: "objcPromise fulfilled")
            objcPromise.then { (value) in
                XCTAssertEqual(value as? Int, 42)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        
        do { // basic bridge rejected
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                resolver.reject(with: "error")
            })
            let objcPromise = promise.objc(mapValue: { $0 as NSNumber }, mapError: { $0 as NSString })
            let _: ObjCPromise<NSNumber,NSString> = objcPromise // compile-time type assertion
            let expectation = XCTestExpectation(description: "objcPromise rejected")
            objcPromise.catch { (error) in
                XCTAssertEqual(error, "error")
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        
        do { // basic bridge cancelled
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                resolver.cancel()
            })
            let objcPromise = promise.objc(mapValue: { $0 as NSNumber }, mapError: { $0 as NSString })
            let _: ObjCPromise<NSNumber,NSString> = objcPromise // compile-time type assertion
            let expectation = XCTestExpectation(description: "objcPromise cancelled")
            objcPromise.onCancel {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where mapError returns Swift.Error and handlers throw
            let promise = Promise<Int,String>(on: .utility, { (resolver) in
                resolver.reject(with: "error")
            })
            let objcPromise = promise.objc(mapValue: { _ -> NSNumber in throw DummyError() }, mapError: StringError.init(message:))
            let _: ObjCPromise<NSNumber,NSError> = objcPromise // compile-time type assertion
            let expectation = XCTestExpectation(description: "objcPromise rejected")
            objcPromise.catch { (error) in
                XCTAssertTrue(error as Error is StringError)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where Value: AnyObject
            let promise = Promise<NSNumber,String>(on: .utility, { (resolver) in
                resolver.reject(with: "error")
            })
            let objcPromise = promise.objc(mapError: { StringError(message: $0) as NSError })
            let _: ObjCPromise<NSNumber,NSError> = objcPromise // compile-time type assertion
            let expectation = XCTestExpectation(description: "objcPromise rejected")
            objcPromise.catch { (error) in
                XCTAssertTrue(error as Error is StringError)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where Error: AnyObject
            let promise = Promise<Int,NSString>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            })
            let objcPromise = promise.objc(mapValue: { $0 as NSNumber })
            let _: ObjCPromise<NSNumber,NSString> = objcPromise // compile-time type assertion
            let expectation = XCTestExpectation(description: "objcPromise fulfilled")
            objcPromise.then { (value) in
                XCTAssertEqual(value as? Int, 42)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where Error == Swift.Error
            let promise = Promise<Int,Error>(on: .utility, { (resolver) in
                resolver.reject(with: StringError(message: "wat"))
            })
            let objcPromise = promise.objc(mapValue: { _ -> NSNumber in throw DummyError() })
            let _: ObjCPromise<NSNumber,NSError> = objcPromise // compile-time type assertion
            let expectation = XCTestExpectation(description: "objcPromise rejected")
            objcPromise.catch { (error) in
                XCTAssertTrue(error as Error is StringError)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testFromObjC() {
        struct DummyError: Error {}
        
        do { // bridge where Value: AnyObject, Error: AnyObject
            let promise = Promise(ObjCPromise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            }))
            let _: Promise<NSNumber,NSString> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
            wait(for: [expectation], timeout: 1)
        }
        
        do { // basic bridge fulfilled
            let promise = Promise(bridging: ObjCPromise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            }), mapValue: { $0.intValue }, mapError: { $0 as String })
            let _: Promise<Int,String> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
            wait(for: [expectation], timeout: 1)
        }
        
        do { // basic bridge rejected
            let promise = Promise(bridging: ObjCPromise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.reject(with: "error")
            }), mapValue: { $0.intValue }, mapError: { $0 as String })
            let _: Promise<Int,String> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onError: promise, expectedError: "error")
            wait(for: [expectation], timeout: 1)
        }
        
        do { // basic bridge cancelled
            let promise = Promise(bridging: ObjCPromise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.cancel()
            }), mapValue: { $0.intValue }, mapError: { $0 as String })
            let _: Promise<Int,String> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onCancel: promise)
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where Value: AnyObject
            let promise = Promise(bridging: ObjCPromise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            }), mapError: { $0 as String })
            let _: Promise<NSNumber,String> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where Error: AnyObject
            let promise = Promise(bridging: ObjCPromise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            }), mapValue: { $0.intValue })
            let _: Promise<Int,NSString> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where Error == Swift.Error throwing
            let promise = Promise(bridging: ObjCPromise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            }), mapValue: { $0.intValue }, mapError: { _ in throw DummyError() })
            let _: Promise<Int,Error> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onSuccess: promise, expectedValue: 42)
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where Error == Swift.Error fulfilled
            let promise = Promise(bridging: ObjCPromise<NSNumber,NSError>(on: .utility, { (resolver) in
                resolver.fulfill(with: 42)
            }), mapValue: { _ -> Int in throw DummyError() })
            let _: Promise<Int,Error> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                XCTAssert(error is DummyError)
            })
            wait(for: [expectation], timeout: 1)
        }
        
        do { // bridge where Error == Swift.Error rejected
            let promise = Promise(bridging: ObjCPromise<NSNumber,NSString>(on: .utility, { (resolver) in
                resolver.reject(with: "error")
            }), mapValue: { $0.intValue }, mapError: { _ in throw DummyError() })
            let _: Promise<Int,Error> = promise // compile-time type assertion
            let expectation = XCTestExpectation(onError: promise, handler: { (error) in
                XCTAssert(error is DummyError)
            })
            wait(for: [expectation], timeout: 1)
        }
    }
}
