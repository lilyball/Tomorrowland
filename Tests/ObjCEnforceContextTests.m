//
//  ObjCEnforceContextTests.m
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 1/5/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+TWLPromise.h"
@import Foundation;
@import Tomorrowland;

@interface ObjCEnforceContextTests : XCTestCase

@end

@implementation ObjCEnforceContextTests

static dispatch_queue_t testQueue;
static const void * const specificKey = &specificKey;

+ (void)setUp {
    [super setUp];
    testQueue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(testQueue, specificKey, (void *)1, NULL);
}

+ (void)tearDown {
    testQueue = nil;
    [super tearDown];
}

- (void)testMap {
    // not enforcing
    {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:[TWLContext queue:testQueue] handler:^id _Nonnull(NSNumber * _Nonnull value) {
            return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@(value.integerValue + 1)];
            }];
        }];
        XCTestExpectation *expectation = [self expectationOnContext:TWLContext.immediate onSuccess:promise handler:^(NSNumber * _Nonnull value) {
            XCTAssertEqualObjects(value, @43);
            XCTAssert(dispatch_get_specific(specificKey) == NULL);
        }];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // enforcing
    {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:[TWLContext queue:testQueue] options:TWLPromiseOptionsEnforceContext handler:^id _Nonnull(NSNumber * _Nonnull value) {
            return [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@(value.integerValue + 1)];
            }];
        }];
        XCTestExpectation *expectation = [self expectationOnContext:TWLContext.immediate onSuccess:promise handler:^(NSNumber * _Nonnull value) {
            XCTAssertEqualObjects(value, @43);
            XCTAssert(dispatch_get_specific(specificKey) != NULL);
        }];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testRecover {
    // not enforcing
    {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"] recoverOnContext:[TWLContext queue:testQueue] handler:^id _Nonnull(NSString * _Nonnull error) {
            return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver rejectWithError:[NSString stringWithFormat:@"%@bar", error]];
            }];
        }];
        XCTestExpectation *expectation = [self expectationOnContext:TWLContext.immediate onError:promise handler:^(NSNumber * _Nonnull value) {
            XCTAssert(dispatch_get_specific(specificKey) == NULL);
        }];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // enforcing
    {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"] recoverOnContext:[TWLContext queue:testQueue] options:TWLPromiseOptionsEnforceContext handler:^id _Nonnull(NSString * _Nonnull error) {
            return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver rejectWithError:[NSString stringWithFormat:@"%@bar", error]];
            }];
        }];
        XCTestExpectation *expectation = [self expectationOnContext:TWLContext.immediate onError:promise handler:^(NSString * _Nonnull error) {
            XCTAssert(dispatch_get_specific(specificKey) != NULL);
        }];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testAlways {
    // not enforcing
    {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] alwaysOnContext:[TWLContext queue:testQueue] handler:^TWLPromise<NSNumber*,NSString*> * _Nonnull(NSNumber * _Nullable value, NSString * _Nullable error) {
            if (!value) {
                XCTFail(@"missing value");
                return [TWLPromise newRejectedWithError:@"error"];
            }
            return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@(value.integerValue + 1)];
            }];
        }];
        XCTestExpectation *expectation = [self expectationOnContext:TWLContext.immediate onSuccess:promise handler:^(NSNumber * _Nonnull value) {
            XCTAssertEqualObjects(value, @43);
            XCTAssert(dispatch_get_specific(specificKey) == NULL);
        }];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // enforcing
    {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] alwaysOnContext:[TWLContext queue:testQueue] options:TWLPromiseOptionsEnforceContext handler:^TWLPromise<NSNumber*,NSString*> * _Nonnull(NSNumber * _Nullable value, NSString * _Nullable error) {
            if (!value) {
                XCTFail(@"missing value");
                return [TWLPromise newRejectedWithError:@"error"];
            }
            return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@(value.integerValue + 1)];
            }];
        }];
        XCTestExpectation *expectation = [self expectationOnContext:TWLContext.immediate onSuccess:promise handler:^(NSNumber * _Nonnull value) {
            XCTAssertEqualObjects(value, @43);
            XCTAssert(dispatch_get_specific(specificKey) != NULL);
        }];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

@end
