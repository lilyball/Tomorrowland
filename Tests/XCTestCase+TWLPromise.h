//
//  XCTestCase+TWLPromise.h
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 1/1/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//

#import <XCTest/XCTest.h>

@class TWLContext;
@class TWLPromise;

NS_ASSUME_NONNULL_BEGIN

@interface XCTestCase (TWLPromise)

- (XCTestExpectation *)expectationOnSuccess:(TWLPromise *)promise;
- (XCTestExpectation *)expectationOnSuccess:(TWLPromise *)promise handler:(void (^)(id value))handler;
- (XCTestExpectation *)expectationOnSuccess:(TWLPromise *)promise expectedValue:(id)expectedValue;
- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onSuccess:(TWLPromise *)promise;
- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onSuccess:(TWLPromise *)promise handler:(void (^)(id value))handler;
- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onSuccess:(TWLPromise *)promise expectedValue:(id)expectedValue;

- (XCTestExpectation *)expectationOnError:(TWLPromise *)promise;
- (XCTestExpectation *)expectationOnError:(TWLPromise *)promise handler:(void (^)(id error))handler;
- (XCTestExpectation *)expectationOnError:(TWLPromise *)promise expectedError:(id)expectedError;
- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onError:(TWLPromise *)promise;
- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onError:(TWLPromise *)promise handler:(void (^)(id error))handler;
- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onError:(TWLPromise *)promise expectedError:(id)expectedError;

- (XCTestExpectation *)expectationOnCancel:(TWLPromise *)promise;
- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onCancel:(TWLPromise *)promise;

@end

NS_ASSUME_NONNULL_END
