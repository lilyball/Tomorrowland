//
//  TWLUtilityTests.m
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 1/7/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+TWLPromise.h"
#include <mach/mach_time.h>
@import Tomorrowland;

@interface TWLUtilityTests : XCTestCase

@end

@implementation TWLUtilityTests

- (void)testDelayFulfill {
    // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }] delay:0.05 onContext:TWLContext.utility];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    __block uint64_t invoked = 0;
    [promise inspectOnContext:TWLContext.userInteractive handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = getCurrentUptime();
        XCTAssertEqualObjects(value, @42);
        [expectation fulfill];
    }];
    uint64_t deadline = getCurrentUptime() + 50 * NSEC_PER_MSEC;
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
    if (invoked > 0) {
        XCTAssert(invoked > deadline);
    } else {
        XCTFail("Didn't retrieve invoked value");
    }
}

- (void)testDelayReject {
    // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver rejectWithError:@"foo"];
    }] delay:0.05 onContext:TWLContext.utility];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    __block uint64_t invoked = 0;
    [promise inspectOnContext:TWLContext.userInteractive handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = getCurrentUptime();
        XCTAssertEqualObjects(error, @"foo");
        [expectation fulfill];
    }];
    uint64_t deadline = getCurrentUptime() + 50 * NSEC_PER_MSEC;
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
    if (invoked > 0) {
        XCTAssert(invoked > deadline);
    } else {
        XCTFail("Didn't retrieve invoked value");
    }
}

- (void)testDelayCancel {
    // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver cancel];
    }] delay:0.05 onContext:TWLContext.utility];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    __block uint64_t invoked = 0;
    [promise inspectOnContext:TWLContext.userInteractive handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = getCurrentUptime();
        XCTAssertNil(value);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    uint64_t deadline = getCurrentUptime() + 50 * NSEC_PER_MSEC;
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
    if (invoked > 0) {
        XCTAssert(invoked > deadline);
    } else {
        XCTFail("Didn't retrieve invoked value");
    }
}

- (void)testDelayUsingImmediate {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [resolver fulfillWithValue:@42];
    }] delay:0.05 onContext:TWLContext.immediate];
    XCTestExpectation *expectation = [self expectationOnContext:TWLContext.immediate onSuccess:promise handler:^(NSNumber * _Nonnull value) {
        XCTAssertEqualObjects(value, @42);
        XCTAssertTrue(NSThread.isMainThread);
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testDelayCancelPropagation {
    XCTestExpectation *expectation;
    TWLPromise *promise;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    {
        TWLPromise * NS_VALID_UNTIL_END_OF_SCOPE origPromise = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
                [resolver cancel];
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }];
        expectation = [self expectationOnCancel:origPromise];
        promise = [origPromise delay:0.05 onContext:TWLContext.immediate];
        [promise requestCancel];
        XCTAssertFalse([origPromise getValue:NULL error:NULL]); // shouldn't cancel yet
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

// MARK: -

- (void)testTimeout {
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    
    { // fulfill
        TWLPromise<NSNumber*,TWLTimeoutError<NSString*>*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_MSEC)), queue, ^{
                [resolver fulfillWithValue:@42];
            });
        }] timeoutOnContext:[TWLContext queue:queue] withDelay:0.05];
        XCTestExpectation *expectation = [self expectationOnSuccess:promise expectedValue:@42];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    { // reject
        TWLPromise<NSNumber*,TWLTimeoutError<NSString*>*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_MSEC)), queue, ^{
                [resolver rejectWithError:@"error"];
            });
        }] timeoutOnContext:[TWLContext queue:queue] withDelay:0.05];
        XCTestExpectation *expectation = [self expectationOnError:promise expectedError:[TWLTimeoutError newWithRejectedError:@"error"]];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    { // timeout
        TWLPromise<NSNumber*,TWLTimeoutError<NSString*>*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), queue, ^{
                [resolver fulfillWithValue:@42];
            });
        }] timeoutOnContext:[TWLContext queue:queue] withDelay:0.01];
        XCTestExpectation *expectation = [self expectationOnError:promise expectedError:[TWLTimeoutError newTimedOut]];
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testCancelPropagationOnTimeout {
    { // cancel
        XCTestExpectation *cancelExpectation = [[XCTestExpectation alloc] initWithDescription:@"promise cancelled"];
        
        XCTestExpectation *expectation;
        {
            TWLPromise<NSNumber*,TWLTimeoutError<NSString*>*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                    [cancelExpectation fulfill];
                    [resolver cancel];
                }];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    [resolver fulfillWithValue:@42];
                });
            }] timeoutOnContext:TWLContext.utility withDelay:0.01];
            expectation = [self expectationOnError:promise expectedError:[TWLTimeoutError newTimedOut]];
        }
        [self waitForExpectations:@[expectation, cancelExpectation] timeout:1];
    }
    
    { // don't cancel
        XCTestExpectation *cancelExpectation = [[XCTestExpectation alloc] initWithDescription:@"promise cancelled"];
        cancelExpectation.inverted = YES;
        
        XCTestExpectation *expectation;
        {
            TWLPromise<NSNumber*,NSString*> *origPromise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                    [cancelExpectation fulfill];
                    [resolver cancel];
                }];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    [resolver fulfillWithValue:@42];
                });
            }];
            (void)[origPromise thenOnContext:TWLContext.utility handler:^(NSNumber * _Nonnull value) {}];
            TWLPromise<NSNumber*,TWLTimeoutError<NSString*>*> *promise = [origPromise timeoutOnContext:TWLContext.utility withDelay:0.01];
            expectation = [self expectationOnError:promise expectedError:[TWLTimeoutError newTimedOut]];
        }
        [self waitForExpectations:@[expectation] timeout:1];
        [self waitForExpectations:@[cancelExpectation] timeout:0.01];
    }
}

- (void)testTimeoutPropagateCancel {
    XCTestExpectation *cancelExpectation = [[XCTestExpectation alloc] initWithDescription:@"promise cancelled"];
    
    TWLPromise<NSNumber*,TWLTimeoutError<NSString*>*> *promise;
    {
        TWLPromise<NSNumber*,NSString*> * NS_VALID_UNTIL_END_OF_SCOPE origPromise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                [cancelExpectation fulfill];
                [resolver cancel];
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                [resolver fulfillWithValue:@42];
            });
        }];
        promise = [origPromise timeoutOnContext:TWLContext.utility withDelay:0.5];
        [promise requestCancel];
        XCTAssertFalse([origPromise getValue:NULL error:NULL]); // not yet cancelled
    }
    XCTestExpectation *expectation = [self expectationOnCancel:promise];
    [self waitForExpectations:@[expectation, cancelExpectation] timeout:1];
}

- (void)testZeroDelayAlreadyResolved {
    TWLPromise *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] timeoutOnContext:TWLContext.utility withDelay:0];
    XCTestExpectation *expectation = [self expectationOnSuccess:promise expectedValue:@42];
    [self waitForExpectations:@[expectation] timeout:1];
}

// MARK: -

static uint64_t getCurrentUptime() {
    // see https://developer.apple.com/library/content/qa/qa1398/_index.html
    uint64_t time = mach_absolute_time();
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) {
        (void)mach_timebase_info(&timebase);
    }
    // hope this doesn't overflow. Modern processors should be using very low timebases anyway, probably {1,1}.
    return time * timebase.numer / timebase.denom;
}

@end
