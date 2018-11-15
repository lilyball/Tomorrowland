//
//  TWLDelayedPromiseTests.m
//  TomorrowlandTests
//
//  Created by Lily Ballard on 1/5/18.
//  Copyright © 2018 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+TWLPromise.h"
@import Tomorrowland;

@interface TWLDelayedPromiseTests : XCTestCase

@end

@interface TWLDelayedPromiseTestsDropSpy : NSObject
- (nonnull instancetype)initWithDropCallback:(void (^)(void))dropCallback NS_DESIGNATED_INITIALIZER;
+ (nonnull instancetype)new NS_UNAVAILABLE;
- (nonnull instancetype)init NS_UNAVAILABLE;
@end

@implementation TWLDelayedPromiseTests

- (void)testDelayedPromiseResolves {
    TWLDelayedPromise<NSNumber*,NSString*> *dp = [TWLDelayedPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [resolver fulfillWithValue:@42];
    }];
    XCTestExpectation *expectation = TWLExpectationSuccessWithValue(dp.promise, @42);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testDelayedPromiseDelays {
    __block BOOL invoked = NO;
    TWLDelayedPromise<NSNumber*,NSString*> *dp = [TWLDelayedPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        invoked = YES;
        [resolver fulfillWithValue:@42];
    }];
    XCTAssertFalse(invoked);
    (void)dp.promise;
    XCTAssertTrue(invoked);
}

- (void)testDelayedPromiseReturnsSamePromise {
    TWLDelayedPromise *dp = [TWLDelayedPromise newOnContext:TWLContext.utility handler:^(TWLResolver * _Nonnull resolver) {
        [resolver fulfillWithValue:@42];
    }];
    TWLPromise *promiseA = dp.promise;
    TWLPromise *promiseB = dp.promise;
    XCTAssertEqualObjects(promiseA, promiseB);
    XCTestExpectation *expectationA = TWLExpectationSuccessWithValue(promiseA, @42);
    XCTestExpectation *expectationB = TWLExpectationSuccessWithValue(promiseB, @42);
    [self waitForExpectations:@[expectationA, expectationB] timeout:1];
}

- (void)testDelayedPromiseDropsCallbackAfterInvocation {
    XCTestExpectation *dropExpectation = [[XCTestExpectation alloc] initWithDescription:@"callback dropped"];
    XCTestExpectation *notDroppedExpectation = [[XCTestExpectation alloc] initWithDescription:@"callback not yet dropped"];
    notDroppedExpectation.inverted = YES;
    TWLDelayedPromise *dp;
    @autoreleasepool {
        TWLDelayedPromiseTestsDropSpy *dropSpy = [[TWLDelayedPromiseTestsDropSpy alloc] initWithDropCallback:^{
            [dropExpectation fulfill];
            [notDroppedExpectation fulfill];
        }];
        dp = [TWLDelayedPromise newOnContext:TWLContext.utility handler:^(TWLResolver * _Nonnull resolver) {
            [resolver fulfillWithValue:@42];
            (void)dropSpy;
        }];
        dropSpy = nil;
    }
    [self waitForExpectations:@[notDroppedExpectation] timeout:0]; // ensure DropSpy is held by dp
    (void)dp.promise;
    [self waitForExpectations:@[dropExpectation] timeout:1];
    (void)dp;
}

@end

@implementation TWLDelayedPromiseTestsDropSpy {
    void (^ _Nonnull _callback)(void);
}

- (instancetype)initWithDropCallback:(void (^)(void))dropCallback {
    if ((self = [super init])) {
        _callback = [dropCallback copy];
    }
    return self;
}

- (void)dealloc {
    _callback();
}

@end
