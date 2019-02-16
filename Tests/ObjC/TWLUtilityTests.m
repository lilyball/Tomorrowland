//
//  TWLUtilityTests.m
//  TomorrowlandTests
//
//  Created by Lily Ballard on 1/7/18.
//  Copyright © 2018 Lily Ballard.
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

@interface TWLUtilityTestsDeallocSpy : NSObject
- (nonnull instancetype)initWithExpectation:(nonnull XCTestExpectation *)expectation NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new NS_UNAVAILABLE;
@end

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
    XCTestExpectation *expectation = TWLExpectationSuccessWithHandlerOnContext(TWLContext.immediate, promise, ^(NSNumber * _Nonnull value) {
        XCTAssertEqualObjects(value, @42);
        XCTAssertTrue(NSThread.isMainThread);
    });
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testDelayPropagateCancel {
    XCTestExpectation *expectation;
    TWLPromise *promise;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    @autoreleasepool {
        TWLPromise * NS_VALID_UNTIL_END_OF_SCOPE origPromise = [TWLPromise newOnContext:TWLContext.immediate withBlock:^(TWLResolver * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
                [resolver cancel];
            }];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@42];
            });
        }];
        expectation = TWLExpectationCancel(origPromise);
        promise = [origPromise delay:0.05 onContext:TWLContext.immediate];
        [promise requestCancel];
        XCTAssertFalse([origPromise getValue:NULL error:NULL]); // shouldn't cancel yet
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testDelayUsingOperationQueue {
    // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
    __auto_type queue = [NSOperationQueue new];
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }] delay:0.05 onContext:[TWLContext operationQueue:queue]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    __block uint64_t invoked = 0;
    [promise inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = getCurrentUptime();
        XCTAssertEqualObjects(value, @42);
        XCTAssertEqualObjects(NSOperationQueue.currentQueue, queue);
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

- (void)testDelayUsingOperationQueueHeadOfLine {
    // This test ensures that when we delay on an operation queue, we add the operation immediately,
    // and thus it will have priority over later operations on the same queue.
    __auto_type queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.userInitiated withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }] delay:0.01 onContext:[TWLContext operationQueue:queue]];
    __auto_type expectation = TWLExpectationSuccessWithValue(promise, @42);
    [queue addOperationWithBlock:^{
        // block the queue for 50ms
        // This way the delay should be ready by the time we finish, which will allow it to run
        // before the next block.
        [NSThread sleepForTimeInterval:0.05];
    }];
    [queue addOperationWithBlock:^{
        // block the queue for 1 second. This ensures the test will fail if the delay operation is
        // behind us.
        [NSThread sleepForTimeInterval:1];
    }];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:0.5];
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
        XCTestExpectation *expectation = TWLExpectationSuccessWithValue(promise, @42);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    { // reject
        TWLPromise<NSNumber*,TWLTimeoutError<NSString*>*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_MSEC)), queue, ^{
                [resolver rejectWithError:@"error"];
            });
        }] timeoutOnContext:[TWLContext queue:queue] withDelay:0.05];
        XCTestExpectation *expectation = TWLExpectationErrorWithError(promise, [TWLTimeoutError newWithRejectedError:@"error"]);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    { // timeout
        TWLPromise<NSNumber*,TWLTimeoutError<NSString*>*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), queue, ^{
                [resolver fulfillWithValue:@42];
            });
        }] timeoutOnContext:[TWLContext queue:queue] withDelay:0.01];
        XCTestExpectation *expectation = TWLExpectationErrorWithError(promise, [TWLTimeoutError newTimedOut]);
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
            expectation = TWLExpectationErrorWithError(promise, [TWLTimeoutError newTimedOut]);
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
            expectation = TWLExpectationErrorWithError(promise, [TWLTimeoutError newTimedOut]);
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
    XCTestExpectation *expectation = TWLExpectationCancel(promise);
    [self waitForExpectations:@[expectation, cancelExpectation] timeout:1];
}

- (void)testZeroDelayAlreadyResolved {
    TWLPromise *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] timeoutOnContext:TWLContext.utility withDelay:0];
    XCTestExpectation *expectation = TWLExpectationSuccessWithValue(promise, @42);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testTimeoutUsingOperationQueue {
    __auto_type queue = [NSOperationQueue new];
    
    __auto_type promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [resolver fulfillWithValue:@42];
        });
    }] timeoutOnContext:[TWLContext operationQueue:queue] withDelay:0.01];
    XCTestExpectation *expectation = TWLExpectationErrorWithHandlerOnContext(TWLContext.immediate, promise, ^(NSError * _Nonnull error) {
        XCTAssertEqualObjects(error, [TWLTimeoutError newTimedOut]);
        XCTAssertEqualObjects(NSOperationQueue.currentQueue, queue);
    });
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testTimeoutUsingOperationQueueHeadOfLine {
    // This test ensures that when we timeout on an operation queue, we add the operation
    // immediately, and thus it will have priority over later operations on the same queue.
    __auto_type queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    
    __auto_type promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [resolver fulfillWithValue:@42];
        });
    }] timeoutOnContext:[TWLContext operationQueue:queue] withDelay:0.01];
    [queue addOperationWithBlock:^{
        // block the queue for 50ms
        // This way the delay should be ready by the time we finish, which will allow it to run
        // before the next block.
        [NSThread sleepForTimeInterval:0.05];
    }];
    [queue addOperationWithBlock:^{
        // block the queue for 1 second. This ensures the test will fail if the delay operation is
        // behind us.
        [NSThread sleepForTimeInterval:1];
    }];
    __auto_type expectation = TWLExpectationErrorWithHandlerOnContext(TWLContext.immediate, promise, ^(NSError * _Nonnull error) {
        XCTAssertEqualObjects(error, [TWLTimeoutError newTimedOut]);
    });
    [self waitForExpectations:@[expectation] timeout:0.5];
}

// MARK: -

- (void)testInitFulfilledAfter {
    // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
    __auto_type deadline = getCurrentUptime() + 50 * NSEC_PER_MSEC;
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newFulfilledOnContext:TWLContext.userInteractive withValue:@42 afterDelay:0.05];
    __auto_type expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    __block uint64_t invoked = 0;
    [promise inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = getCurrentUptime();
        XCTAssertEqualObjects(value, @42);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
    if (invoked > 0) {
        XCTAssert(invoked > deadline);
    } else {
        XCTFail("Didn't retrieve invoked value");
    }
}

- (void)testInitRejectedAfter {
    // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
    __auto_type deadline = getCurrentUptime() + 50 * NSEC_PER_MSEC;
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newRejectedOnContext:TWLContext.userInteractive withError:@"foo" afterDelay:0.05];
    __auto_type expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    __block uint64_t invoked = 0;
    [promise inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = getCurrentUptime();
        XCTAssertEqualObjects(error, @"foo");
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
    if (invoked > 0) {
        XCTAssert(invoked > deadline);
    } else {
        XCTFail("Didn't retrieve invoked value");
    }
}

- (void)testInitCancelledAfter {
    // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
    __auto_type deadline = getCurrentUptime() + 50 * NSEC_PER_MSEC;
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newCancelledOnContext:TWLContext.userInteractive afterDelay:0.05];
    __auto_type expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    __block uint64_t invoked = 0;
    [promise inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = getCurrentUptime();
        XCTAssertNil(value);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
    if (invoked > 0) {
        XCTAssert(invoked > deadline);
    } else {
        XCTFail("Didn't retrieve invoked value");
    }
}

- (void)testInitFulfilledAfterCancelledCancelsImmediately {
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newFulfilledOnContext:TWLContext.utility withValue:@42 afterDelay:1];
    XCTAssertFalse([promise getValue:NULL error:NULL]);
    [promise requestCancel];
    // Cancellation of the promise is synchronous
    id value, error;
    XCTAssertTrue([promise getValue:&value error:&error]);
    XCTAssertNil(value);
    XCTAssertNil(error);
}

- (void)testInitFulfilledAfterCancelledReleasesResultBeforeDelay {
    // Cancellation is synchronous but we can't rely on the result itself being dropped
    // synchronously as it's held by a dispatch timer. So we'll instead just make sure it's dropped
    // before the delay.
    __auto_type expectation = [[XCTestExpectation alloc] initWithDescription:@"spy dealloced"];
    __auto_type promise = [TWLPromise<TWLUtilityTestsDeallocSpy*,NSString*> newFulfilledOnContext:TWLContext.utility withValue:[[TWLUtilityTestsDeallocSpy alloc] initWithExpectation:expectation] afterDelay:1];
    [promise requestCancel];
    [self waitForExpectations:@[expectation] timeout:0.5];
}

- (void)testInitFulfilledAfterUsingOperationQueue {
    // NB: We're going to delay by a very short value, 50ms, so the tests are still speedy
    __auto_type queue = [NSOperationQueue new];
    __auto_type deadline = getCurrentUptime() + 50 * NSEC_PER_MSEC;
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newFulfilledOnContext:[TWLContext operationQueue:queue] withValue:@42 afterDelay:0.05];
    __auto_type expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    __block uint64_t invoked = 0;
    [promise inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = getCurrentUptime();
        XCTAssertEqualObjects(value, @42);
        XCTAssertEqualObjects(NSOperationQueue.currentQueue, queue);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
    if (invoked > 0) {
        XCTAssert(invoked > deadline);
    } else {
        XCTFail("Didn't retrieve invoked value");
    }
}

- (void)testInitFulfilledAfterUsingOperationQueueHeadOfLine {
    // This test ensures that when we delay on an operation queue, we add the operation
    // immediately, and thus it will have priority over later operations on the same queue.
    __auto_type queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newFulfilledOnContext:[TWLContext operationQueue:queue] withValue:@42 afterDelay:0.05];
    __auto_type expectation = TWLExpectationSuccessWithValue(promise, @42);
    [queue addOperationWithBlock:^{
        // block the queue for 50ms
        // This way the delay should be ready by the time we finish, which will allow it to run
        // before the next block.
        [NSThread sleepForTimeInterval:0.1];
    }];
    [queue addOperationWithBlock:^{
        // block the queue for 1 second. This ensures the test will fail if the delay operation is
        // behind us.
        [NSThread sleepForTimeInterval:1];
    }];
    [self waitForExpectations:@[expectation] timeout:0.5];
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

@implementation TWLUtilityTestsDeallocSpy {
    XCTestExpectation * _Nonnull _expectation;
}
- (instancetype)initWithExpectation:(XCTestExpectation *)expectation {
    if ((self = [super init])) {
        _expectation = expectation;
    }
    return self;
}

- (void)dealloc {
    [_expectation fulfill];
}
@end
