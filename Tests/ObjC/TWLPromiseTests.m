//
//  TWLPromiseTests.m
//  TomorrowlandTests
//
//  Created by Lily Ballard on 1/1/18.
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
#import "TWLDeallocSpy.h"
@import Tomorrowland;

@interface TWLPromiseTests : XCTestCase

@end

@interface TWLPromiseTestsRunLoopObserver : NSObject
@property (nonatomic) BOOL invoked;
@end

@implementation TWLPromiseTests

- (void)testBasicFulfill {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        [resolver fulfillWithValue:@42];
    }];
    XCTestExpectation *expectation = TWLExpectationSuccessWithValue(promise, @42);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testBasicReject {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        [resolver rejectWithError:@"error"];
    }];
    XCTestExpectation *expectation = TWLExpectationErrorWithError(promise, @"error");
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testBasicCancel {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        [resolver cancel];
    }];
    XCTestExpectation *expectation = TWLExpectationCancel(promise);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testBasicResolve {
    TWLPromise *promise1 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithValue:@42 error:nil];
    }];
    XCTestExpectation *expectation1 = TWLExpectationSuccessWithValue(promise1, @42);
    TWLPromise *promise2 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithValue:nil error:@"foo"];
    }];
    XCTestExpectation *expectation2 = TWLExpectationErrorWithError(promise2, @"foo");
    TWLPromise *promise3 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithValue:nil error:nil];
    }];
    XCTestExpectation *expectation3 = TWLExpectationCancel(promise3);
    TWLPromise *promise4 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithValue:@42 error:@"foo"];
    }];
    XCTestExpectation *expectation4 = TWLExpectationSuccessWithValue(promise4, @42);
    [self waitForExpectations:@[expectation1, expectation2, expectation3, expectation4] timeout:1];
}

- (void)testResolveWithPromise {
    TWLPromise *promise1 = [TWLPromise newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithPromise:[TWLPromise newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver * _Nonnull resolver) {
            [resolver fulfillWithValue:@42];
        }]];
    }];
    TWLPromise *promise2 = [TWLPromise newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithPromise:[TWLPromise newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver * _Nonnull resolver) {
            [resolver rejectWithError:@"foo"];
        }]];
    }];
    TWLPromise *promise3 = [TWLPromise newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithPromise:[TWLPromise newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }]];
    }];
    NSArray *expectations = @[TWLExpectationSuccessWithValue(promise1, @42),
                              TWLExpectationErrorWithError(promise2, @"foo"),
                              TWLExpectationCancel(promise3)];
    [self waitForExpectations:expectations timeout:1];
}

- (void)testResolveWithPromiseAlreadyResolved {
    TWLResolver<NSNumber*,NSString*> *resolver;
    __auto_type promise = [[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
    NSThread *currentThread = NSThread.currentThread;
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise resolution"];
    [promise inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        XCTAssert([currentThread isEqual:NSThread.currentThread], @"Promise resolved on another thread");
        XCTAssertEqualObjects(value, @42);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [resolver resolveWithPromise:[TWLPromise newFulfilledWithValue:@42]];
    [self waitForExpectations:@[expectation] timeout:0];
}

- (void)testResolveWithPromiseCancelPropagation {
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type innerCancelExpectation = [[XCTestExpectation alloc] initWithDescription:@"inner promise cancelled"];
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [resolver resolveWithPromise:[TWLPromise newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
                [resolver cancel];
                [innerCancelExpectation fulfill];
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }]];
    }];
    __auto_type outerCancelExpectation = TWLExpectationCancel(promise);
    XCTAssertFalse([promise getValue:NULL error:NULL]);
    [promise requestCancel];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[innerCancelExpectation, outerCancelExpectation] timeout:1];
    TWLAssertPromiseCancelled(promise);
}

- (void)testAlreadyFulfilled {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42];
    NSNumber *value;
    XCTAssertTrue([promise getValue:&value error:NULL]);
    XCTAssertEqualObjects(value, @42);
    __block BOOL invoked = NO;
    [promise thenOnContext:TWLContext.immediate handler:^(id _Nonnull value) {
        invoked = YES;
    }];
    XCTAssertTrue(invoked);
}

- (void)testAlreadyRejected {
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"];
    NSString *error;
    XCTAssertTrue([promise getValue:NULL error:&error]);
    XCTAssertEqualObjects(error, @"foo");
    __block BOOL invoked = NO;
    [promise catchOnContext:TWLContext.immediate handler:^(NSString * _Nonnull error) {
        invoked = YES;
    }];
    XCTAssertTrue(invoked);
}

- (void)testAlreadyCancelled {
    __auto_type promise = [TWLPromise<NSNumber*,NSString*> newCancelled];
    XCTAssertTrue([promise getValue:NULL error:NULL]);
    __block BOOL invoked = NO;
    [promise inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
        invoked = YES;
    }];
    XCTAssertTrue(invoked);
}

- (void)testThen {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"catch"];
    [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] thenOnContext:TWLContext.utility handler:^(NSNumber * _Nonnull value) {
        XCTAssertEqualObjects(value, @42);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testMapResult {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.utility handler:^(NSNumber * _Nonnull x) {
        return @(x.integerValue + 1);
    }];
    XCTestExpectation *expectation = TWLExpectationSuccessWithValue(promise, @43);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testMapReturningFulfilledPromise {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.utility handler:^id _Nonnull(NSNumber * _Nonnull x) {
        return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver fulfillWithValue:@(x.integerValue + 1)];
        }];
    }];
    XCTestExpectation *expectation = TWLExpectationSuccessWithValue(promise, @43);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testMapReturningRejectedPromise {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.utility handler:^id _Nonnull(NSNumber * _Nonnull x) {
        return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver rejectWithError:@"error"];
        }];
    }];
    XCTestExpectation *expectation = TWLExpectationErrorWithError(promise, @"error");
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testMapReturningCancelledPromise {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.utility handler:^id _Nonnull(NSNumber * _Nonnull x) {
        return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver cancel];
        }];
    }];
    XCTestExpectation *expectation = TWLExpectationCancel(promise);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testPromiseCallbackOrder {
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    __block NSUInteger resolved = 0;
    NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray arrayWithCapacity:10];
    for (NSUInteger i = 0; i < 10; ++i) {
        XCTestExpectation *expectation = TWLExpectationSuccessWithHandlerOnContext([TWLContext queue:queue], promise, ^(NSNumber * _Nonnull x) {
            XCTAssertEqual(i, resolved, @"callbacks invoked out of order");
            ++resolved;
            XCTAssertEqualObjects(x, @42);
        });
        [expectations addObject:expectation];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testMapReturningPreFulfilledPromise {
    TWLPromise<NSString*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.immediate handler:^(NSNumber * _Nonnull value) {
        return [TWLPromise<NSString*,NSString*> newFulfilledWithValue:value.description];
    }];
    NSString *value;
    NSString *error;
    if ([promise getValue:&value error:&error]) {
        XCTAssertEqualObjects(value, @"42");
        XCTAssertNil(error);
    } else {
        XCTFail("Promise was unfilled");
    }
    __block BOOL invoked = NO;
    [promise thenOnContext:TWLContext.immediate handler:^(NSString * _Nonnull value) {
        invoked = YES;
    }];
    XCTAssertTrue(invoked);
}

- (void)testCatch {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"catch"];
    [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"error"] catchOnContext:TWLContext.utility handler:^(NSString * _Nonnull error) {
        XCTAssertEqualObjects(error, @"error");
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testRecover {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"] recoverOnContext:TWLContext.utility handler:^id _Nonnull(NSString * _Nonnull error) {
        return @42;
    }];
    XCTestExpectation *expectaton = TWLExpectationSuccessWithValue(promise, @42);
    [self waitForExpectations:@[expectaton] timeout:1];
}

- (void)testRecoverReturningPromise {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"] recoverOnContext:TWLContext.utility handler:^id _Nonnull(NSString * _Nonnull error) {
        return [TWLPromise newRejectedWithError:@"bar"];
    }];
    XCTestExpectation *expectation = TWLExpectationErrorWithError(promise, @"bar");
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testWhenCancelled {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        [resolver cancel];
    }];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"whenCancelled"];
    [promise whenCancelledOnContext:TWLContext.utility handler:^{
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAlwaysReturningPromise {
    TWLPromise<NSString*,NSNumber*> *promise = [[TWLPromise<NSString*,NSNumber*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSString*,NSNumber*> * _Nonnull resolver) {
        [resolver rejectWithError:@42];
    }] alwaysOnContext:TWLContext.utility handler:^TWLPromise * _Nonnull(NSString * _Nullable value, NSNumber * _Nullable error) {
        return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            if (error) {
                [resolver fulfillWithValue:@(error.integerValue + 1)];
            } else {
                [resolver rejectWithError:@"error"];
            }
        }];
    }];
    XCTestExpectation *expectation = TWLExpectationSuccessWithValue(promise, @43);
    [self waitForExpectations:@[expectation] timeout:1];
}

#pragma mark -

- (void)testPropagatingCancellation {
    __auto_type requestExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on root"];
    __auto_type childExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on child"];
    __auto_type notYetExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on child too early"];
    notYetExpectation.inverted = YES;
    TWLPromise *childPromise __attribute__((objc_precise_lifetime));
    { // scope rootPromise
        __auto_type rootPromise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber*,NSString*> * _Nonnull _resolver) {
                [requestExpectation fulfill];
                [resolver cancel]; // retain resolver to keep the promise alive until cancelled
            }];
        }];
        __block TWLPromise *blockChildPromise;
        childPromise = [rootPromise propagatingCancellationOnContext:TWLContext.immediate cancelRequestedHandler:^(TWLPromise *promise){
            XCTAssertEqualObjects(promise, blockChildPromise, @"Promise passed to cancelRequestedHandler isn't the same as what was returned");
            // Note: We can only wait on an expectation once, so we trigger multiple here for testing at different points.
            [childExpectation fulfill];
            [notYetExpectation fulfill];
        }];
        blockChildPromise = childPromise;
    }
    __auto_type promise1 = [childPromise thenOnContext:TWLContext.immediate handler:^(id _Nonnull value) {}];
    __auto_type promise2 = [childPromise thenOnContext:TWLContext.immediate handler:^(id _Nonnull value) {}];
    [promise1 requestCancel];
    if ([[[XCTWaiter alloc] initWithDelegate:self] waitForExpectations:@[notYetExpectation] timeout:0] != XCTWaiterResultCompleted) {
        XCTFail(@"Cancel requested on child too early");
        return;
    }
    __auto_type cancelExpectations = @[
        TWLExpectationCancelOnContext(TWLContext.immediate, promise1),
        TWLExpectationCancelOnContext(TWLContext.immediate, promise2)
    ];
    [promise2 requestCancel];
    // Everything was marked as immediate, so all cancellation should have happened immediately.
    [self waitForExpectations:[@[childExpectation, requestExpectation] arrayByAddingObjectsFromArray:cancelExpectations] timeout:0 enforceOrder:YES];
    
    // Adding new children at this point causes no problems, they're just insta-cancelled.
    __auto_type promise3 = [childPromise thenOnContext:TWLContext.immediate handler:^(id _Nonnull value) {}];
    id _Nullable value, error;
    XCTAssertTrue([promise3 getValue:&value error:&error]);
    XCTAssertNil(value);
    XCTAssertNil(error);
}

- (void)testPropagatingCancellationNoChildren {
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type requestExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on root"];
    requestExpectation.inverted = YES;
    __auto_type childExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on child"];
    childExpectation.inverted = YES;
    __auto_type resolvedExpectation = [[XCTestExpectation alloc] initWithDescription:@"Child promise resolved"];
    resolvedExpectation.inverted = YES;
    { // scope childPromise
        TWLPromise *childPromise;
        { // scope rootPromise
            __auto_type rootPromise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
                [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
                    [requestExpectation fulfill];
                    [resolver cancel];
                }];
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                    [resolver fulfillWithValue:@42];
                });
            }];
            childPromise = [rootPromise propagatingCancellationOnContext:TWLContext.immediate cancelRequestedHandler:^(TWLPromise *_promise){
                [childExpectation fulfill];
            }];
        }
        [[childPromise tap] inspectOnContext:TWLContext.immediate handler:^(id  _Nullable value, id  _Nullable error) {
            [resolvedExpectation fulfill];
        }];
    }
    // At this point childPromise and rootPromise are gone, and all callbacks are .immediate.
    // If cancellation was going to propagate, it would have done so already.
    [self waitForExpectations:@[requestExpectation, childExpectation, resolvedExpectation] timeout:0];
    dispatch_semaphore_signal(sema);
}

- (void)testPropagatingCancelManualRequestCancel {
    // -requestCancel should behave the same as cancellation propagation with respect to running the callback
    __auto_type childExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on child"];
    __auto_type notYetExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on child too early"];
    notYetExpectation.inverted = YES;
    TWLPromise *childPromise;
    { // scope rootPromise
        __auto_type rootPromise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber*,NSString*> * _Nonnull _resolver) {
                [resolver cancel]; // retain resolver to keep the promise alive until cancelled
            }];
        }];
        childPromise = [rootPromise propagatingCancellationOnContext:TWLContext.immediate cancelRequestedHandler:^(TWLPromise *_promise){
            // Note: We can only wait on an expectation once, so we trigger multiple here for testing at different points.
            [childExpectation fulfill];
            [notYetExpectation fulfill];
        }];
    }
    if ([[[XCTWaiter alloc] initWithDelegate:self] waitForExpectations:@[notYetExpectation] timeout:0] != XCTWaiterResultCompleted) {
        XCTFail(@"Cancel requested on child too early");
        return;
    }
    [childPromise requestCancel];
    [self waitForExpectations:@[childExpectation] timeout:0];
}

- (void)testPropagatingCancellationAsyncCallback {
    // Test that using an asynchronous cancelRequested callback works as expected.
    __auto_type childExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on child"];
    TWLPromise *childPromise;
    __auto_type queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    { // scope rootPromise
        __auto_type rootPromise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber*,NSString*> * _Nonnull _resolver) {
                [resolver cancel]; // retain resolver
            }];
        }];
        childPromise = [rootPromise propagatingCancellationOnContext:[TWLContext operationQueue:queue] cancelRequestedHandler:^(TWLPromise *_promise){
            XCTAssertEqualObjects(NSOperationQueue.currentQueue, queue);
            [childExpectation fulfill];
        }];
    }
    [[childPromise thenOnContext:TWLContext.immediate handler:^(id _Nonnull value) {}] requestCancel];
    // cancel should already be enqueued on the queue at this point. No need for a timeout.
    [queue waitUntilAllOperationsAreFinished];
    [self waitForExpectations:@[childExpectation] timeout:0];
}

- (void)testPropagatingCancellationFulfilled {
    // Just a quick test to ensure propagatingCancellation actually resolves properly too
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type rootPromise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    __auto_type childPromise = [rootPromise propagatingCancellationOnContext:TWLContext.immediate cancelRequestedHandler:^(TWLPromise *_promise){
        XCTFail(@"Unexpected cancellation");
    }];
    __auto_type expectation1 = TWLExpectationSuccessWithValueOnContext(TWLContext.immediate, childPromise, @42);
    expectation1.inverted = YES;
    [self waitForExpectations:@[expectation1] timeout:0];
    __auto_type expectation2 = TWLExpectationSuccessWithValue(childPromise, @42);
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation2] timeout:1];
}

- (void)testPropagatingCancellationOtherChildrenOfRoot {
    // Ensure cancellation propagation doesn't ignore other children of the root promise
    __auto_type sema = dispatch_semaphore_create(0);
    __auto_type rootPromiseCancelExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on root promise"];
    rootPromiseCancelExpectation.inverted = YES;
    __auto_type childExpectation = [[XCTestExpectation alloc] initWithDescription:@"Cancel requested on child"];
    XCTestExpectation *child2Expectation;
    __auto_type notYetExpectation = [[XCTestExpectation alloc] initWithDescription:@"Child 2 promise resolved too quickly"];
    notYetExpectation.inverted = YES;
    TWLPromise *childPromise;
    { // scope rootPromise
        __auto_type rootPromise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
                [rootPromiseCancelExpectation fulfill];
                [resolver cancel];
            }];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                [resolver fulfillWithValue:@42];
            });
        }];
        childPromise = [rootPromise propagatingCancellationOnContext:TWLContext.immediate cancelRequestedHandler:^(TWLPromise *_promise){
            [childExpectation fulfill];
        }];
        __auto_type child2Promise = [rootPromise thenOnContext:TWLContext.immediate handler:^(NSNumber * _Nonnull value) {}];
        child2Expectation = TWLExpectationSuccessWithValueOnContext(TWLContext.immediate, child2Promise, @42);
        [[child2Promise tap] inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [notYetExpectation fulfill];
        }];
    }
    [[childPromise thenOnContext:TWLContext.immediate handler:^(id  _Nonnull value) {}] requestCancel];
    [self waitForExpectations:@[notYetExpectation, childExpectation] timeout:0];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[rootPromiseCancelExpectation, child2Expectation] timeout:1];
}

#pragma mark -

- (void)testPromiseContexts {
    NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray array];
    XCTestExpectation *mainExpectation = [[XCTestExpectation alloc] initWithDescription:@"main context"];
    [TWLPromise newOnContext:TWLContext.main withBlock:^(TWLResolver * _Nonnull resolver) {
        XCTAssertTrue(NSThread.isMainThread);
        [mainExpectation fulfill];
        [resolver fulfillWithValue:@42];
    }];
    [expectations addObject:mainExpectation];
    NSArray<TWLContext *> *bgContexts = @[TWLContext.background, TWLContext.utility, TWLContext.defaultQoS, TWLContext.userInitiated, TWLContext.userInteractive];
    for (TWLContext *context in bgContexts) {
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:[NSString stringWithFormat:@"%@ context", context]];
        [TWLPromise newOnContext:context withBlock:^(TWLResolver * _Nonnull resolver) {
            XCTAssertFalse(NSThread.isMainThread);
            [expectation fulfill];
            [resolver fulfillWithValue:@42];
        }];
        [expectations addObject:expectation];
    }
    static const void * const queueKey = &queueKey;
    {
        dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(queue, queueKey, (void *)1, NULL);
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"+queue: context"];
        [TWLPromise newOnContext:[TWLContext queue:queue] withBlock:^(TWLResolver * _Nonnull resolver) {
            XCTAssert(dispatch_get_specific(queueKey) == (void *)1);
            [expectation fulfill];
            [resolver fulfillWithValue:@42];
        }];
        [expectations addObject:expectation];
    }
    {
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.name = @"test queue";
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"+operationQueue: context"];
        [TWLPromise newOnContext:[TWLContext operationQueue:queue] withBlock:^(TWLResolver * _Nonnull resolver) {
            XCTAssertEqualObjects(NSOperationQueue.currentQueue, queue);
            [expectation fulfill];
            [resolver fulfillWithValue:@42];
        }];
        [expectations addObject:expectation];
    }
    __block BOOL invoked = NO;
    [TWLPromise newOnContext:TWLContext.immediate withBlock:^(TWLResolver * _Nonnull resolver) {
        invoked = YES;
        [resolver fulfillWithValue:@42];
    }];
    XCTAssertTrue(invoked);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testAutoPromiseContext {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42];
    XCTestExpectation *expectationMain = [[XCTestExpectation alloc] initWithDescription:@"main queue"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [promise inspectOnContext:TWLContext.automatic handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            XCTAssertTrue(NSThread.isMainThread);
            XCTAssertNotNil(value);
            [expectationMain fulfill];
        }];
    });
    XCTestExpectation *expectationBG = [[XCTestExpectation alloc] initWithDescription:@"background queue"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [promise inspectOnContext:TWLContext.automatic handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            XCTAssertFalse(NSThread.isMainThread);
            XCTAssertNotNil(value);
            [expectationBG fulfill];
        }];
    });
    [self waitForExpectations:@[expectationMain, expectationBG] timeout:1];
}

#pragma mark - Invalidation Token

- (void)testInvalidationTokenNoInvalidate {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise success"];
    [promise thenOnContext:TWLContext.utility token:token handler:^(NSNumber * _Nonnull x) {
        XCTAssertEqualObjects(x, @42);
        [expectation fulfill];
    }];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testInvalidationTokenInvalidate {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    {
        TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }];
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise resolved"];
        [[promise thenOnContext:TWLContext.utility token:token handler:^(NSNumber * _Nonnull x) {
            XCTFail("invalidated callback invoked");
        }] inspectOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
        [token invalidate];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Test reuse
    {
        TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@44];
        }];
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise resolved"];
        [[promise thenOnContext:[TWLContext queue:queue] token:token handler:^(NSNumber * _Nonnull x) {
            XCTFail("invalidated callback invoked");
        }] inspectOnContext:TWLContext.utility handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
        [token invalidate];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testInvalidationTokenInvalidateChainSuccess {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    TWLPromise *chainPromise = [promise mapOnContext:TWLContext.utility token:token handler:^id _Nonnull(NSNumber * _Nonnull value) {
        XCTFail("invalidated callback invoked");
        return @"error";
    }];
    XCTestExpectation *expectation = TWLExpectationCancel(chainPromise);
    [token invalidate];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testInvalidationTokenInvalidateChainError {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver rejectWithError:@"foo"];;
    }];
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    TWLPromise *chainPromise = [promise mapOnContext:TWLContext.utility token:token handler:^id _Nonnull(NSNumber * _Nonnull value) {
        XCTFail("invalidated callback invoked");
        return @"error";
    }];
    XCTestExpectation *expectation = TWLExpectationErrorWithError(chainPromise, @"foo");
    [token invalidate];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testInvalidationTokenMultiplePromises {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray array];
    for (NSInteger i = 1; i <= 3; ++i) {
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:[NSString stringWithFormat:@"chain promise %ld", (long)i]];
        [[promise mapOnContext:[TWLContext queue:queue] token:token handler:^id _Nonnull(NSNumber * _Nonnull value) {
            XCTFail("invalidated callback invoked");
            return @0;
        }] inspectOnContext:[TWLContext queue:queue] handler:^(id _Nullable value, id _Nullable error) {
            [expectation fulfill];
        }];
        [expectations addObject:expectation];
    }
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"non-invalidated chain promise"];
    [promise thenOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nonnull value) {
        XCTAssertEqualObjects(value, @42);
        [expectation fulfill];
    }];
    [expectations addObject:expectation];
    [token invalidate];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:expectations timeout:1];
}

- (void)testInvalidationTokenRequestCancelOnInvalidate {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise *promise = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    XCTestExpectation *expectation = TWLExpectationCancel(promise);
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    [token requestCancelOnInvalidate:promise];
    [token invalidate];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testInvalidationTokenNoInvalidateOnDealloc {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise *promise = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    XCTestExpectation *expectation = TWLExpectationSuccessWithValue(promise, @42);
    {
        TWLInvalidationToken *token = [TWLInvalidationToken newInvalidateOnDealloc:NO];
        [token requestCancelOnInvalidate:promise];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testInvalidationTokenInvalidateOnDealloc {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise *promise = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    XCTestExpectation *expectation = TWLExpectationCancel(promise);
    {
        TWLInvalidationToken *token = [TWLInvalidationToken new];
        [token requestCancelOnInvalidate:promise];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testInvalidationTokenNotRetained {
    // Ensure that passing a token to a callback doesn't retain the token
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise *promise = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise resolved"];
    {
        TWLInvalidationToken *token = [TWLInvalidationToken new];
        [[promise thenOnContext:TWLContext.immediate token:token handler:^(id _Nonnull value) {
            XCTFail(@"token did not deinit when expected");
        }] inspectOnContext:TWLContext.immediate handler:^(id _Nullable value, id _Nullable error) {
            [expectation fulfill];
        }];
    }
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testInvalidationTokenCancelWithoutInvalidating {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLInvalidationToken *token = [TWLInvalidationToken newInvalidateOnDealloc:NO];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise cancelled"];
    [[[TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }] whenCancelledOnContext:TWLContext.utility handler:^{
        [expectation fulfill];
    }] requestCancelOnInvalidate:token];
    [token cancelWithoutInvalidating];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testInvalidationTokenChainInvalidationFromToken {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    TWLInvalidationToken *token = [TWLInvalidationToken newInvalidateOnDealloc:NO];
    TWLInvalidationToken *subToken = [TWLInvalidationToken newInvalidateOnDealloc:NO];
    [subToken chainInvalidationFromToken:token];
    {
        TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }];
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise resolved"];
        [[promise thenOnContext:TWLContext.utility token:subToken handler:^(NSNumber * _Nonnull x) {
            XCTFail("invalidated callback invoked");
        }] inspectOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
        [token invalidate];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    // Ensure the chain is still intact
    {
        TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }];
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise resolved"];
        [[promise thenOnContext:TWLContext.utility token:subToken handler:^(NSNumber * _Nonnull x) {
            XCTFail("invalidated callback invoked; the chained invalidation was not permanent");
        }] inspectOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
        [token invalidate];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    // Ensure adding a second token to the chain will cancel both of them
    {
        TWLInvalidationToken *subToken2 = [TWLInvalidationToken newInvalidateOnDealloc:NO];
        [subToken2 chainInvalidationFromToken:token];
        TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }];
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"subToken promise resolved"];
        [[promise thenOnContext:TWLContext.utility token:subToken handler:^(NSNumber * _Nonnull x) {
            XCTFail("invalidated callback invoked");
        }] inspectOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
        XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:@"subToken2 promise resolved"];
        [[promise thenOnContext:TWLContext.utility token:subToken2 handler:^(NSNumber * _Nonnull x) {
            XCTFail("invalidated callback invoked");
        }] inspectOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation2 fulfill];
        }];
        [token invalidate];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation, expectation2] timeout:1];
    }
}

- (void)testInvalidationTokenChainInvalidationFromTokenIncludingCancelWithoutInvalidate {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLInvalidationToken *token = [TWLInvalidationToken newInvalidateOnDealloc:NO];
    { // propagating cancel without invalidate
        TWLInvalidationToken *subToken = [TWLInvalidationToken newInvalidateOnDealloc:NO];
        [subToken chainInvalidationFromToken:token];
        TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                [resolver cancel];
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }] requestCancelOnInvalidate:subToken];
        XCTestExpectation *expectation = TWLExpectationCancel(promise);
        [token cancelWithoutInvalidating];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    { // without propagating cancel without invalidate
        TWLInvalidationToken *subToken = [TWLInvalidationToken newInvalidateOnDealloc:NO];
        [subToken chainInvalidationFromToken:token includingCancelWithoutInvalidating:NO];
        TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                XCTFail(@"cancel requested");
                [resolver cancel];
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }] requestCancelOnInvalidate:subToken];
        XCTestExpectation *expectation = TWLExpectationSuccessWithValue(promise, @42);
        [token cancelWithoutInvalidating];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testInvalidationTokenChainInvalidationFromTokenDoesNotRetain {
    // Ensure that -chainInvalidationFromToken: does not retain the tokens in either direction
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    { // child is not retained
        TWLInvalidationToken *token = [TWLInvalidationToken newInvalidateOnDealloc:NO];
        TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }];
        {
            TWLInvalidationToken *subToken = [TWLInvalidationToken newInvalidateOnDealloc:YES];
            [subToken chainInvalidationFromToken:token];
            promise = [promise thenOnContext:TWLContext.utility token:subToken handler:^(NSNumber * _Nonnull x) {
                XCTFail("invalidated callback invoked");
            }];
        } // subToken deinited, thus invalidated
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise resolved"];
        [promise inspectOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    { // parent is not retained
        TWLInvalidationToken *subToken = [TWLInvalidationToken newInvalidateOnDealloc:NO];
        TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }];
        {
            TWLInvalidationToken *token = [TWLInvalidationToken newInvalidateOnDealloc:YES];
            [subToken chainInvalidationFromToken:token];
            promise = [promise thenOnContext:TWLContext.utility token:token handler:^(NSNumber * _Nonnull x) {
                XCTFail("invalidated callback invoked");
            }];
        } // token deinited, thus invalidated
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise resolved"];
        [promise inspectOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testInvalidationTokenChainInvalidationFromSelf {
    // Ask a token to chain invalidation from itself just to ensure this doesn't trigger an infinite
    // loop.
    TWLInvalidationToken *token = [TWLInvalidationToken new];
    [token chainInvalidationFromToken:token];
    [token invalidate];
}

#pragma mark -

- (void)testResolvingFulfilledPromise {
    // Resolving a promise that has already been fulfilled does nothing
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [resolver fulfillWithValue:@42];
        [resolver fulfillWithValue:@43];
        [resolver rejectWithError:@"error"];
        [resolver cancel];
        [expectation fulfill];
    }];
    XCTestExpectation *expectation2 = TWLExpectationSuccessWithValue(promise, @42);
    [self waitForExpectations:@[expectation, expectation2] timeout:1];
    // now that the promise is resolved, check again to make sure the value is the same
    NSNumber *value;
    if ([promise getValue:&value error:NULL]) {
        XCTAssertEqualObjects(value, @42);
    } else {
        XCTFail(@"Expected resolved promise, found unresolved");
    }
}

- (void)testResolvingRejectedPromise {
    // Resolving a promise that has already been rejected does nothing
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [resolver rejectWithError:@"error"];
        [resolver rejectWithError:@"foobar"];
        [resolver fulfillWithValue:@43];
        [resolver cancel];
        [expectation fulfill];
    }];
    XCTestExpectation *expectation2 = TWLExpectationErrorWithError(promise, @"error");
    [self waitForExpectations:@[expectation, expectation2] timeout:1];
    // now that the promise is resolved, check again to make sure the value is the same
    NSString *error;
    if ([promise getValue:NULL error:&error]) {
        XCTAssertEqualObjects(error, @"error");
    } else {
        XCTFail(@"Expected resolved promise, found unresolved");
    }
}

- (void)testResolvingCancelledPromise {
    // Resolving a promise that has already been rejected does nothing
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        [resolver cancel];
        [resolver cancel];
        [resolver rejectWithError:@"foobar"];
        [resolver fulfillWithValue:@43];
        [expectation fulfill];
    }];
    XCTestExpectation *expectation2 = TWLExpectationCancel(promise);
    [self waitForExpectations:@[expectation, expectation2] timeout:1];
    // now that the promise is resolved, check again to make sure the value is the same
    NSNumber *value;
    NSString *error;
    if ([promise getValue:&value error:&error]) {
        XCTAssertNil(value);
        XCTAssertNil(error);
    } else {
        XCTFail(@"Expected resolved promise, found unresolved");
    }
}

- (void)testRequestCancel {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"whenCancelRequested"];
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        [resolver whenCancelRequestedOnContext:TWLContext.utility handler:^(TWLResolver<NSNumber*,NSString*> * _Nonnull cancellable) {
            [expectation fulfill];
            [cancellable cancel];
        }];
    }];
    XCTestExpectation *cancelExpectation = TWLExpectationCancel(promise);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [promise requestCancel];
    });
    [self waitForExpectations:@[expectation, cancelExpectation] timeout:1];
}

- (void)testMultipleWhenCancelRequested {
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray array];
    for (NSInteger i = 1; i <= 3; ++i) {
        [expectations addObject:[[XCTestExpectation alloc] initWithDescription:[NSString stringWithFormat:@"whenCancelRequested %ld", (long)i]]];
    }
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        __block NSUInteger resolved = 0;
        for (NSInteger i = 0; i < expectations.count; ++i) {
            XCTestExpectation *expectation = expectations[i];
            [resolver whenCancelRequestedOnContext:[TWLContext queue:queue] handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                XCTAssertEqual(resolved, i);
                ++resolved;
                [expectation fulfill];
                [resolver cancel];
            }];
        }
        dispatch_semaphore_signal(sema);
    }];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [promise requestCancel];
    });
    [self waitForExpectations:expectations timeout:1];
}

- (void)testWhenCancelRequestedAfterCancel {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        __block BOOL invoked = NO;
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver cancel];
            invoked = YES;
        }];
        XCTAssertTrue(invoked);
        [expectation fulfill];
    }];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [promise requestCancel];
        dispatch_semaphore_signal(sema);
    });
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testResolverRequestedCancel {
    // Same thread
    {
        TWLResolver<NSNumber*,NSString*> *resolver;
        __auto_type promise = [[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
        XCTAssertFalse(resolver.cancelRequested);
        [promise requestCancel];
        XCTAssertTrue(resolver.cancelRequested);
    }
    
    // Different thread
    {
        __auto_type sema = dispatch_semaphore_create(0);
        __auto_type promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            XCTAssertTrue(resolver.cancelRequested);
            [resolver fulfillWithValue:@42];
            XCTAssertFalse(resolver.cancelRequested);
        }];
        __auto_type expectation = TWLExpectationSuccessWithValue(promise, @42);
        [promise requestCancel];
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // In callback
    {
        TWLResolver<NSNumber*,NSString*> *resolver;
        __auto_type promise = [[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
        [resolver whenCancelRequestedOnContext:TWLContext.defaultQoS handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull innerResolver) {
            XCTAssertTrue(innerResolver.cancelRequested);
            XCTAssertTrue(resolver.cancelRequested);
            [resolver fulfillWithValue:@42];
            XCTAssertFalse(resolver.cancelRequested);
            XCTAssertFalse(innerResolver.cancelRequested);
        }];
        __auto_type expectation = TWLExpectationSuccessWithValue(promise, @42);
        XCTAssertFalse(resolver.cancelRequested);
        [promise requestCancel];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Cancelled without request
    {
        __auto_type expectation = [XCTestExpectation new];
        (void)[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            XCTAssertFalse(resolver.cancelRequested);
            [resolver cancel];
            XCTAssertTrue(resolver.cancelRequested);
            [expectation fulfill];
        }];
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testLeavingPromiseUnresolvedTriggersCancel {
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray array];
    for (NSInteger i = 1; i <= 3; ++i) {
        [expectations addObject:[[XCTestExpectation alloc] initWithDescription:[NSString stringWithFormat:@"promise %ld cancel", (long)i]]];
    }
    {
        TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            // don't resolve
        }];
        for (XCTestExpectation *expectation in expectations) {
            [promise inspectOnContext:[TWLContext queue:queue] handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
                XCTAssertNil(value);
                XCTAssertNil(error);
                [expectation fulfill];
            }];
        }
    }
    [self waitForExpectations:expectations timeout:1 enforceOrder:YES];
}

- (void)testCancellingOuterPromiseCancelsInnerPromise {
    XCTestExpectation *innerExpectation = [[XCTestExpectation alloc] initWithDescription:@"inner promise"];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSString*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.immediate handler:^TWLPromise<NSString*,NSString*> * _Nonnull(NSNumber * _Nonnull value) {
        TWLPromise<NSString*,NSString*> *innerPromise = [TWLPromise<NSString*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSString *,NSString *> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                [resolver cancel];
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:[NSString stringWithFormat:@"%ld", (long)(value.integerValue + 1)]];
        }];
        [innerPromise whenCancelledOnContext:TWLContext.utility handler:^{
            [innerExpectation fulfill];
        }];
        return innerPromise;
    }];
    XCTestExpectation *outerExpectation = TWLExpectationCancel(promise);
    [promise requestCancel];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[outerExpectation, innerExpectation] timeout:1];
}

- (void)testIgnoringCancel {
    XCTestExpectation *innerExpectation = [[XCTestExpectation alloc] initWithDescription:@"inner promise"];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.immediate handler:^TWLPromise * _Nonnull (NSNumber * _Nonnull x) {
        TWLPromise<NSString*,NSString*> *innerPromise = [[TWLPromise<NSString*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSString*,NSString*> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSString*,NSString*> * _Nonnull resolver) {
                XCTFail("inner promise was cancelled");
                [resolver cancel];
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:[NSString stringWithFormat:@"%ld", (long)(x.integerValue + 1)]];
        }] ignoringCancel];
        [innerPromise thenOnContext:TWLContext.defaultQoS handler:^(NSString * _Nonnull x) {
            XCTAssertEqualObjects(x, @"43");
            [innerExpectation fulfill];
        }];
        return innerPromise;
    }];
    XCTestExpectation *outerExpectation = TWLExpectationSuccessWithValue(promise, @"43");
    [promise requestCancel];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[outerExpectation, innerExpectation] timeout:1];
}

- (void)testChainedMainContextCallbacks {
    // When chaining callbacks on the main context, they should all invoke within the same runloop
    // pass.
    {
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"done"];
        dispatch_async(dispatch_get_main_queue(), ^{ // tests should be on the main queue already, but just in case
            TWLPromiseTestsRunLoopObserver *observer = [TWLPromiseTestsRunLoopObserver new];
            __block BOOL initialDelayed = NO;
            // Ensure order is preserved. This really only applies to some of them.
            __block NSUInteger order = 0;
            [[[[[[[[TWLPromise newOnContext:TWLContext.main withBlock:^(TWLResolver * _Nonnull resolver) {
                XCTAssertTrue(initialDelayed); // this block shouldn't be immediate
                observer.invoked = NO;
                [resolver fulfillWithValue:@42];
            }] thenOnContext:TWLContext.main handler:^(id  _Nonnull value) {
                XCTAssertFalse(observer.invoked, @"then callback was delayed");
                XCTAssertEqual(order, 0);
                ++order;
                observer.invoked = NO;
            }] mapOnContext:TWLContext.main handler:^id _Nonnull(id  _Nonnull value) {
                XCTAssertFalse(observer.invoked, @"map callback was delayed");
                XCTAssertEqual(order, 1);
                ++order;
                observer.invoked = NO;
                return @"bar";
            }] mapOnContext:TWLContext.main handler:^id _Nonnull(id  _Nonnull value) {
                XCTAssertFalse(observer.invoked, @"second map callback was delayed");
                XCTAssertEqual(order, 2);
                ++order;
                observer.invoked = NO;
                return [TWLPromise newRejectedWithError:@"error"];
            }] catchOnContext:TWLContext.main handler:^(id  _Nonnull error) {
                XCTAssertFalse(observer.invoked, @"catch callback was delayed");
                XCTAssertEqual(order, 3);
                ++order;
                observer.invoked = NO;
            }] recoverOnContext:TWLContext.main handler:^id _Nonnull(id  _Nonnull error) {
                XCTAssertFalse(observer.invoked, @"recover callback was delayed");
                XCTAssertEqual(order, 4);
                ++order;
                observer.invoked = NO;
                return @42;
            }] alwaysOnContext:TWLContext.main handler:^TWLPromise<NSNumber*,NSString*> * _Nonnull (id _Nullable value, id _Nullable error) {
                XCTAssertFalse(observer.invoked, @"always callback was delayed");
                XCTAssertEqual(order, 5);
                ++order;
                observer.invoked = NO;
                return [TWLPromise newFulfilledWithValue:@42];
            }] inspectOnContext:TWLContext.main handler:^(id _Nullable value, id _Nullable error) {
                XCTAssertFalse(observer.invoked, @"inspect callback was delayed");
                XCTAssertEqual(order, 6);
                [expectation fulfill];
            }];
            initialDelayed = YES;
        });
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Chaining callbacks on +queue:main shouldn't have this behavior
    {
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"done"];
        dispatch_async(dispatch_get_main_queue(), ^{
            TWLPromiseTestsRunLoopObserver *observer = [TWLPromiseTestsRunLoopObserver new];
            __block BOOL initialDelayed = NO;
            TWLContext *mainContext = [TWLContext queue:dispatch_get_main_queue()];
            [[[[[[TWLPromise<NSNumber*,NSString*> newOnContext:mainContext withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                XCTAssertTrue(initialDelayed); // this block shouldn't be immediate
                observer.invoked = NO;
                [resolver fulfillWithValue:@42];
            }] mapOnContext:mainContext handler:^id _Nonnull(NSNumber * _Nonnull value) {
                XCTAssertTrue(observer.invoked, @"map callback wasn't delayed");
                observer.invoked = NO;
                return @(value.integerValue + 1);
            }] mapOnContext:mainContext handler:^id _Nonnull(id _Nonnull value) {
                XCTAssertTrue(observer.invoked, @"second map callback wasn't delayed");
                observer.invoked = NO;
                return [TWLPromise newRejectedWithError:@"error"];
            }] catchOnContext:mainContext handler:^(id _Nonnull error) {
                XCTAssertTrue(observer.invoked, @"catch callback wasn't delayed");
                observer.invoked = NO;
            }] recoverOnContext:mainContext handler:^id _Nonnull(id _Nonnull error) {
                XCTAssertTrue(observer.invoked, @"recover callback wasn't delayed");
                observer.invoked = NO;
                return @42;
            }] inspectOnContext:mainContext handler:^(id _Nullable value, id _Nullable error) {
                XCTAssertTrue(observer.invoked, @"inspect callback wasn't delayed");
                [expectation fulfill];
            }];
            initialDelayed = YES;
        });
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Chaining between .main and +queue:main should also not have this behavior
    {
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"done"];
        dispatch_async(dispatch_get_main_queue(), ^{
            TWLPromiseTestsRunLoopObserver *observer = [TWLPromiseTestsRunLoopObserver new];
            TWLContext *mainContext = [TWLContext queue:dispatch_get_main_queue()];
            [[[[[TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.main withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
                observer.invoked = NO;
                [resolver fulfillWithValue:@42];
            }] mapOnContext:TWLContext.main handler:^NSNumber * _Nonnull(NSNumber * _Nonnull value) {
                XCTAssertFalse(observer.invoked, @"map context was delayed");
                observer.invoked = NO;
                return @(value.integerValue + 1);
            }] mapOnContext:mainContext handler:^NSNumber * _Nonnull(NSNumber * _Nonnull value) {
                XCTAssertTrue(observer.invoked, @"second map callback wasn't delayed");
                observer.invoked = NO;
                return @(value.integerValue + 1);
            }] mapOnContext:TWLContext.main handler:^NSNumber * _Nonnull(NSNumber * _Nonnull value) {
                XCTAssertTrue(observer.invoked, @"third map callback wasn't delayed");
                observer.invoked = NO;
                return @(value.integerValue + 1);
            }] inspectOnContext:mainContext handler:^(id  _Nullable value, id  _Nullable error) {
                XCTAssertTrue(observer.invoked, @"inspect callback wasn't delayed");
                [expectation fulfill];
            }];
        });
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testChainedMainContextCallbacksArentImmedate {
    // Ensure the chained main context callbacks aren't treated as .immediate but instead wait until
    // the existing work is actually finished.
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"done"];
    __block BOOL finishedWork = NO;
    (void)[[[TWLPromise newOnContext:TWLContext.main withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver fulfillWithValue:@42];
        finishedWork = YES;
    }] thenOnContext:TWLContext.main handler:^(id _Nonnull value) {
        XCTAssertTrue(finishedWork);
    }] inspectOnContext:TWLContext.main handler:^(id _Nullable value, id _Nullable error) {
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testChainedMainContextCallbacksReleaseBeforeNextOneBegins {
    // Ensure that when we chain main context callbacks, we release each block before invoking the
    // next one.
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    XCTestExpectation *firstExpectation = [[XCTestExpectation alloc] initWithDescription:@"first block released"];
    XCTestExpectation *secondExpectation = [[XCTestExpectation alloc] initWithDescription:@"second block executed"];
    (void)[[[TWLPromise newOnContext:TWLContext.defaultQoS withBlock:^(TWLResolver * _Nonnull resolver) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [resolver fulfillWithValue:@42];
    }] thenOnContext:TWLContext.main handler:({
        __auto_type spy = [TWLDeallocSpy newWithHandler:^{
            [firstExpectation fulfill];
        }];
        ^(id _Nonnull value) {
            (void)spy;
        };})] thenOnContext:TWLContext.main handler:^(id _Nonnull value) {
        [self waitForExpectations:@[firstExpectation] timeout:0];
        [secondExpectation fulfill];
    }];
    dispatch_semaphore_signal(sema);
    [self waitForExpectations:@[secondExpectation] timeout:1];
}

- (void)testResolverHandleCallback {
    TWLPromise *promise1 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallback](@42, nil);
    }];
    XCTestExpectation *expectation1 = TWLExpectationSuccessWithValue(promise1, @42);
    TWLPromise *promise2 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallback](nil, @"foo");
    }];
    XCTestExpectation *expectation2 = TWLExpectationErrorWithError(promise2, @"foo");
    TWLPromise *promise3 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallback](@42, @"foo");
    }];
    XCTestExpectation *expectation3 = TWLExpectationSuccessWithValue(promise3, @42);
    TWLPromise *promise4 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallback](nil, nil);
    }];
    XCTestExpectation *expectation4 = TWLExpectationErrorWithHandler(promise4, ^(NSError * _Nonnull error) {
        XCTAssertEqualObjects(error.domain, TWLPromiseCallbackErrorDomain);
        XCTAssertEqual(error.code, TWLPromiseCallbackErrorAPIMismatch);
    });
    TWLPromise *promise5 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallbackWithCancelPredicate:^BOOL(id _Nonnull error) {
            return [error isEqual:@"foo"];
        }](nil, @"foo");
    }];
    XCTestExpectation *expectation5 = TWLExpectationCancel(promise5);
    [self waitForExpectations:@[expectation1, expectation2, expectation3, expectation4, expectation5] timeout:1];
}

- (void)compileTimeCheckForVariance:(TWLPromise<NSObject*,NSString*> *)promise resolver:(TWLResolver<NSObject*,NSString*> *)resolver {
    // promises are covariant
    TWLPromise<NSObject*,NSObject*> *upcastPromise = promise;
#pragma unused(upcastPromise)
    // resolvers are contravariant
    TWLResolver<NSNumber*,NSString*> *upcastResolver = resolver;
#pragma unused(upcastResolver)
}

- (void)testRequestCancelOnDealloc {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __auto_type promise = [TWLPromise newOnContext:TWLContext.immediate withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        });
    }];
    XCTAssertFalse([promise getValue:NULL error:NULL]);
    @autoreleasepool {
        id object __attribute__((objc_precise_lifetime)) = [NSObject new];
        [promise requestCancelOnDealloc:object];
        XCTAssertFalse([promise getValue:NULL error:NULL]);
    }
    id value, error;
    XCTAssertTrue([promise getValue:&value error:&error]);
    XCTAssertNil(value);
    XCTAssertNil(error);
    dispatch_semaphore_signal(sema);
}

- (void)testObservationCallbackReleasedWhenPromiseResolved {
    TWLResolver<NSNumber*,NSString*> *resolver;
    __auto_type promise = [[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
    __weak id weakObject;
    {
        id object = [NSObject new];
        weakObject = object;
        [promise thenOnContext:TWLContext.immediate handler:^(NSNumber * _Nonnull value) {
            (void)object;
        }];
    }
    XCTAssertNotNil(weakObject);
    [resolver fulfillWithValue:@42];
    XCTAssertNil(weakObject);
}

- (void)testObservationCallbackReleasedWhenPromiseCancelled {
    TWLResolver<NSNumber*,NSString*> *resolver;
    __auto_type promise = [[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
    __weak id weakObject;
    {
        id object = [NSObject new];
        weakObject = object;
        [promise thenOnContext:TWLContext.immediate handler:^(NSNumber * _Nonnull value) {
            (void)object;
        }];
    }
    XCTAssertNotNil(weakObject);
    [resolver cancel];
    XCTAssertNil(weakObject);
}

- (void)testWhenCancelCallbackReleasedWhenPromiseResolved {
    TWLResolver<NSNumber*,NSString*> *resolver;
    (void)[[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
    __weak id weakObject;
    {
        id object = [NSObject new];
        weakObject = object;
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            (void)object;
        }];
    }
    XCTAssertNotNil(weakObject);
    [resolver fulfillWithValue:@42];
    XCTAssertNil(weakObject);
}

- (void)testWhenCancelCallbackReleasedWhenPromiseRequestedCancel {
    TWLResolver<NSNumber*,NSString*> *resolver;
    __auto_type promise = [[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
    __weak id weakObject;
    {
        id object = [NSObject new];
        weakObject = object;
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            (void)object;
            [resolver cancel];
        }];
    }
    XCTAssertNotNil(weakObject);
    [promise requestCancel];
    XCTAssertNil(weakObject);
}

@end

@interface TWLPromiseNowOrContextTests : XCTestCase
@end

@implementation TWLPromiseNowOrContextTests {
    dispatch_queue_t _queueOne;
    dispatch_queue_t _queueTwo;
}

- (void)setUp {
    [super setUp];
    _queueOne = dispatch_queue_create("test queue 1", DISPATCH_QUEUE_SERIAL);
    _queueTwo = dispatch_queue_create("test queue 2", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(_queueOne, (__bridge void *)self, (void *)(intptr_t)1, NULL);
    dispatch_queue_set_specific(_queueTwo, (__bridge void *)self, (void *)(intptr_t)2, NULL);
}

- (void)testPromiseInitUsingNowOrContext {
    // +[TWLPromise new…] will treat it as now
    __auto_type expectation = [XCTestExpectation new];
    dispatch_sync(_queueOne, ^{
        [[TWLPromise<NSNumber*,NSString*> newOnContext:[TWLContext nowOrContext:[TWLContext queue:_queueTwo]] withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            XCTAssertEqual((intptr_t)dispatch_get_specific((__bridge void *)self), 1);
        }] inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
    });
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testWhenCancelRequestedUsingNowOrContext {
    // Not yet cancelled
    {
        __auto_type sema = dispatch_semaphore_create(0);
        __auto_type promise = [TWLPromise<NSNumber*,NSString*> newOnContext:[TWLContext queue:_queueOne] withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver whenCancelRequestedOnContext:[TWLContext nowOrContext:[TWLContext queue:self->_queueTwo]] handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull innerResolver) {
                XCTAssertEqual((intptr_t)dispatch_get_specific((__bridge void *)self), 2);
                [resolver cancel]; // capture outer resolver here
            }];
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        [promise requestCancel];
        __auto_type expectation = TWLExpectationCancel(promise);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Already cancelled
    {
        __auto_type expectation = [XCTestExpectation new];
        __auto_type promise = [TWLPromise<NSNumber*,NSString*> newOnContext:[TWLContext queue:_queueOne] withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            [resolver cancel];
            [resolver whenCancelRequestedOnContext:[TWLContext nowOrContext:[TWLContext queue:self->_queueTwo]] handler:^(TWLResolver<NSNumber *,NSString *> * _Nonnull innerResolver) {
                XCTAssertEqual((intptr_t)dispatch_get_specific((__bridge void *)self), 1);
                [resolver cancel]; // capture outer resolver here
                [expectation fulfill];
            }];
        }];
        [promise requestCancel];
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testThenNowOrContext {
    // Not yet resolved
    {
        __auto_type sema = dispatch_semaphore_create(0);
        __auto_type promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:[TWLContext queue:_queueOne] withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }] thenOnContext:[TWLContext nowOrContext:[TWLContext queue:_queueTwo]] handler:^(NSNumber * _Nonnull value) {
            XCTAssertEqual((intptr_t)dispatch_get_specific((__bridge void *)self), 2);
        }];
        __auto_type expectation = TWLExpectationSuccess(promise);
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Already resolved
    {
        __block TWLPromise<NSNumber*,NSString*> *promise;
        dispatch_sync(_queueOne, ^{
            promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] thenOnContext:[TWLContext nowOrContext:[TWLContext queue:self->_queueTwo]] handler:^(NSNumber * _Nonnull value) {
                XCTAssertEqual((intptr_t)dispatch_get_specific((__bridge void *)self), 1);
            }];
        });
        __auto_type expectation = TWLExpectationSuccess(promise);
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testMapNowOrContext {
    // Not yet resolved
    {
        __auto_type sema = dispatch_semaphore_create(0);
        __auto_type promise = [[TWLPromise<NSNumber*,NSString*> newOnContext:[TWLContext queue:_queueOne] withBlock:^(TWLResolver<NSNumber *,NSString *> * _Nonnull resolver) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            [resolver fulfillWithValue:@42];
        }] mapOnContext:[TWLContext nowOrContext:[TWLContext queue:_queueTwo]] handler:^id _Nonnull(NSNumber * _Nonnull value) {
            XCTAssertEqual((intptr_t)dispatch_get_specific((__bridge void *)self), 2);
            return @1;
        }];
        __auto_type expectation = TWLExpectationSuccessWithValue(promise, @1);
        dispatch_semaphore_signal(sema);
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Already resolved
    {
        __block TWLPromise<NSNumber*,NSString*> *promise;
        dispatch_sync(_queueOne, ^{
            promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:[TWLContext nowOrContext:[TWLContext queue:self->_queueTwo]] handler:^id _Nonnull(NSNumber * _Nonnull value) {
                XCTAssertEqual((intptr_t)dispatch_get_specific((__bridge void *)self), 1);
                return @1;
            }];
        });
        __auto_type expectation = TWLExpectationSuccessWithValue(promise, @1);
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

@end

@implementation TWLPromiseTestsRunLoopObserver {
    CFRunLoopObserverRef _Nonnull _observer;
}
- (instancetype)init {
    if ((self = [super init])) {
        __weak typeof(self) weakSelf = self;
        _observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            weakSelf.invoked = YES;
        });
        CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    }
    return self;
}

- (void)dealloc {
    CFRunLoopObserverInvalidate(_observer);
}
@end
