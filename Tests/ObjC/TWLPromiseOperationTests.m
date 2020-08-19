//
//  TWLPromiseOperationTests.m
//  TomorrowlandTests
//
//  Created by Lily Ballard on 8/19/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+TWLPromise.h"
#import "XCTestCase+Helpers.h"
@import Tomorrowland;

@interface TWLPromiseOperationTests : XCTestCase
@end

@interface TWLPromiseOperationTestsDropSpy : NSObject
- (nonnull instancetype)initWithDropCallback:(void (^)(void))dropCallback NS_DESIGNATED_INITIALIZER;
+ (nonnull instancetype)new NS_UNAVAILABLE;
- (nonnull instancetype)init NS_UNAVAILABLE;
@end

@implementation TWLPromiseOperationTests

- (void)testOperationResolvesOnStart {
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [resolver fulfillWithValue:@42];
    }];
    __auto_type promise = op.promise;
    TWLAssertPromiseNotResolved(promise);
    [op start];
    TWLAssertPromiseFulfilledWithValue(promise, @42);
}

- (void)testOperationLifecycle {
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.defaultQoS handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    XCTAssertFalse(op.executing);
    XCTAssertFalse(op.finished);
    [op start];
    XCTAssertTrue(op.executing);
    XCTAssertFalse(op.finished);
    __auto_type expectation = TWLExpectationSuccessWithHandlerOnContext(TWLContext.immediate, op.promise, ^(NSNumber * _Nonnull value) {
        // When the promise is resolved, the operation should already be in its finished state
        XCTAssertFalse(op.executing);
        XCTAssertTrue(op.finished);
    });
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testOperationPromiseCancelsOnDealloc {
    [XCTContext runActivityNamed:@"Dealloc without running handler" block:^(id<XCTActivity>  _Nonnull activity) {
        __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            XCTFail(@"Invoked unexpectedly");
        }];
        __auto_type promise = op.promise;
        TWLAssertPromiseNotResolved(promise);
        op = nil;
        TWLAssertPromiseCancelled(promise);
    }];
    
    [XCTContext runActivityNamed:@"Dealloc while handler is running" block:^(id<XCTActivity>  _Nonnull activity) {
        // If the handler is running, it shouldn't request cancel
        __auto_type sema = dispatch_semaphore_create(0);
        __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                XCTFail(@"Resolver requested to cancel");
            }];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@42];
            });
        }];
        __auto_type promise = op.promise;
        [op start];
        TWLAssertPromiseNotResolved(promise);
        op = nil;
        TWLAssertPromiseNotResolved(promise);
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[TWLExpectationSuccessWithValue(promise, @42)] timeout:1];
    }];
}

- (void)testOperationReturnsSamePromise {
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [resolver fulfillWithValue:@42];
    }];
    __auto_type promise1 = op.promise;
    __auto_type promise2 = op.promise;
    XCTAssertEqual(promise1, promise2); // same object pointer
}

- (void)testOperationCancelWillCancelPromise {
    [XCTContext runActivityNamed:@"Cancelling while operation is executing" block:^(id<XCTActivity>  _Nonnull activity) {
        __auto_type sema = dispatch_semaphore_create(0);
        __auto_type requestCancelExpectation = [[XCTestExpectation alloc] initWithDescription:@"whenCancelRequested"];
        __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                [requestCancelExpectation fulfill];
                [resolver cancel];
            }];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@42];
            });
        }];
        [op start];
        TWLAssertPromiseNotResolved(op.promise);
        [op cancel];
        dispatch_semaphore_signal(sema);
        __auto_type cancelExpectation = TWLExpectationCancelOnContext(TWLContext.immediate, op.promise);
        [self waitForExpectations:@[requestCancelExpectation, cancelExpectation] timeout:0];
    }];
    
    [XCTContext runActivityNamed:@"Cancelling before operation starts" block:^(id<XCTActivity>  _Nonnull activity) {
        __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            XCTFail(@"This shouldn't be invoked");
        }];
        // Cancel the operation now without it having started
        [op cancel];
        // The promise won't be cancelled until the operation itself moves to finished.
        TWLAssertPromiseNotResolved(op.promise);
        // Start the operation so it can cancel itself.
        [op start];
        TWLAssertPromiseCancelled(op.promise);
    }];
}

- (void)testOperationPromiseCancelWillCancelOperation {
    [XCTContext runActivityNamed:@"Cancelling while operation is executing" block:^(id<XCTActivity>  _Nonnull activity) {
        __auto_type sema = dispatch_semaphore_create(0);
        __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.defaultQoS handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                [resolver cancel];
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }];
        [op start];
        XCTAssertFalse(op.cancelled);
        [op.promise requestCancel];
        XCTAssertTrue(op.cancelled);
        dispatch_semaphore_signal(sema);
    }];
    
    [XCTContext runActivityNamed:@"Cancelling before operation starts" block:^(id<XCTActivity>  _Nonnull activity) {
        __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            XCTFail(@"This shouldn't be invoked");
        }];
        // Cancel the promise now without it having started
        [op.promise requestCancel];
        // The operation will be cancelled
        XCTAssertTrue(op.cancelled);
        // But the promise won't have resolved yet
        TWLAssertPromiseNotResolved(op.promise);
        // Start the promise now so the promise can get resolved
        [op start];
        TWLAssertPromiseCancelled(op.promise);
    }];
}

- (void)testOperationDropsCallbackAfterInvocation {
    __auto_type dropExpectation = [[XCTestExpectation alloc] initWithDescription:@"callback dropped"];
    __auto_type notDroppedExpectation = [[XCTestExpectation alloc] initWithDescription:@"callback not yet dropped"];
    notDroppedExpectation.inverted = true;
    TWLPromiseOperation<NSNumber*,NSString*> *op;
    @autoreleasepool {
        __auto_type dropSpy = [[TWLPromiseOperationTestsDropSpy alloc] initWithDropCallback:^{
            [dropExpectation fulfill];
            [notDroppedExpectation fulfill];
        }];
        op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver fulfillWithValue:@42];
            (void)[dropSpy self];
        }];
        dropSpy = nil;
    }
    [self waitForExpectations:@[notDroppedExpectation] timeout:0]; // ensure DropSpy is held by op
    [op start];
    [self waitForExpectations:@[dropExpectation] timeout:0];
    (void)[op self];
}

- (void)testOperationUsingNowOrContext {
    // +nowOrContext: doesn't ever run now when used with TWLPromiseOperation
    __auto_type expectation = [[XCTestExpectation alloc] init];
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:[TWLContext nowOrContext:[TWLContext queue:TestQueue.two]] handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        AssertOnTestQueue(TestQueueIdentifierTwo);
        [expectation fulfill];
    }];
    [op start];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testOperationUsingNowOrContextStartedOnNowOrContext {
    // +nowOrContext: shouldn't run now even if the operation is started from a +nowOrContext:
    // context
    __auto_type expectation = [[XCTestExpectation alloc] init];
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:[TWLContext nowOrContext:[TWLContext queue:TestQueue.two]] handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        AssertOnTestQueue(TestQueueIdentifierTwo);
        [expectation fulfill];
    }];
    dispatch_async(TestQueue.one, ^{
        (void)[[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] thenOnContext:[TWLContext nowOrContext:[TWLContext queue:TestQueue.two]] handler:^(NSNumber * _Nonnull value) {
            AssertOnTestQueue(TestQueueIdentifierOne); // This runs now
            [op start];
        }];
    });
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testOperationImmediateWithStart {
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        AssertOnTestQueue(TestQueueIdentifierOne);
        [resolver fulfillWithValue:@123];
    }];
    dispatch_async(TestQueue.one, ^{
        [op start];
    });
    __auto_type expectation = TWLExpectationSuccessWithValue(op.promise, @123);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testOperationImmediateOnQueue {
    __auto_type queue = [NSOperationQueue new];
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        XCTAssertEqualObjects(NSOperationQueue.currentQueue, queue);
        [resolver fulfillWithValue:@321];
    }];
    [queue addOperation:op];
    __auto_type expectation = TWLExpectationSuccessWithValue(op.promise, @321);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testOperationStaysOnQueueUntilResolved {
    __auto_type queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type sema2 = dispatch_semaphore_create(0);
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.defaultQoS handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_signal(sema2); // Signal that we're in the block
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            dispatch_semaphore_signal(sema2); // Signal that we're in the async queue
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        });
    }];
    [queue addOperation:op];
    __auto_type expectation = [[XCTestExpectation alloc] initWithDescription:@"Next block finished"];
    __auto_type invertExpectation = [[XCTestExpectation alloc] initWithDescription:@"Next block finished"];
    invertExpectation.inverted = true;
    __auto_type op2 = [NSBlockOperation blockOperationWithBlock:^{
        [invertExpectation fulfill];
        [expectation fulfill];
    }];
    [op2 addDependency:op]; // just for good measure
    [queue addOperation:op2];
    dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER); // wait for the operation to have entered its callback
    XCTAssertFalse(op.finished);
    dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER); // wait for the operation to have entered the async queue too
    XCTAssertFalse(op.finished);
    [self waitForExpectations:@[invertExpectation] timeout:0]; // Ensure op2 hasn't run yet
    XCTAssertEqualObjects(queue.operations, (@[op, op2])); // Also for good measure
    dispatch_semaphore_signal(sema); // Let the operation finish
    [self waitForExpectations:@[TWLExpectationSuccessWithValue(op.promise, @42), expectation] timeout:1];
    // Double-check state for good measure
    XCTAssertTrue(op.finished);
    XCTAssertTrue(op2.finished);
    XCTAssertEqualObjects(queue.operations, @[]);
}

- (void)testOperationFinishesWhenCancelled {
    [XCTContext runActivityNamed:@"Cancelled before executing" block:^(id<XCTActivity>  _Nonnull activity) {
        __auto_type queue = [NSOperationQueue new];
        __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            XCTFail(@"Unexpected execution");
        }];
        __auto_type op2 = [NSBlockOperation blockOperationWithBlock:^{
            [op cancel];
        }];
        [op addDependency:op2];
        [queue addOperation:op];
        [queue addOperation:op2];
        [op2 waitUntilFinished];
        [self waitForExpectations:@[TWLExpectationCancel(op.promise)] timeout:1];
        XCTAssertFalse(op.executing);
        XCTAssertTrue(op.finished);
        XCTAssertEqualObjects(queue.operations, @[]);
    }];
    
    [XCTContext runActivityNamed:@"Cancelled while executing" block:^(id<XCTActivity>  _Nonnull activity) {
        __auto_type queue = [NSOperationQueue new];
        __auto_type sema = dispatch_semaphore_create(0);
        __auto_type sema2 = dispatch_semaphore_create(0);
        __auto_type cancelExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested"];
        __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                [cancelExpectation fulfill];
                [resolver cancel];
            }];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@42];
            });
            dispatch_semaphore_signal(sema2);
        }];
        [queue addOperation:op];
        dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER);
        [op cancel];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[cancelExpectation, TWLExpectationCancel(op.promise)] timeout:1];
    }];
}

- (void)testCallingStartMultipleTimes {
    // Calling start multiple times shoud do nothing
    __auto_type handlerExpectation = [[XCTestExpectation alloc] initWithDescription:@"handler invoked"];
    handlerExpectation.expectedFulfillmentCount = 1;
    handlerExpectation.assertForOverFulfill = YES;
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type op = [TWLPromiseOperation<NSNumber*,NSString*> newOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [handlerExpectation fulfill];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        });
    }];
    [op start];
    [op start];
    [op start];
    dispatch_semaphore_signal(sema);
    [op start];
    [self waitForExpectations:@[handlerExpectation, TWLExpectationSuccessWithValue(op.promise, @42)] timeout:1];
}

@end

@implementation TWLPromiseOperationTestsDropSpy {
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

