//
//  TWLPromiseTests.m
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 1/1/18.
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
    XCTestExpectation *expectation = [self expectationOnSuccess:promise expectedValue:@42];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testBasicReject {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        [resolver rejectWithError:@"error"];
    }];
    XCTestExpectation *expectation = [self expectationOnError:promise expectedError:@"error"];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testBasicCancel {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
        [resolver cancel];
    }];
    XCTestExpectation *expectation = [self expectationOnCancel:promise];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testBasicResolve {
    TWLPromise *promise1 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithValue:@42 error:nil];
    }];
    XCTestExpectation *expectation1 = [self expectationOnSuccess:promise1 expectedValue:@42];
    TWLPromise *promise2 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithValue:nil error:@"foo"];
    }];
    XCTestExpectation *expectation2 = [self expectationOnError:promise2 expectedError:@"foo"];
    TWLPromise *promise3 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithValue:nil error:nil];
    }];
    XCTestExpectation *expectation3 = [self expectationOnCancel:promise3];
    TWLPromise *promise4 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver resolveWithValue:@42 error:@"foo"];
    }];
    XCTestExpectation *expectation4 = [self expectationOnSuccess:promise4 expectedValue:@42];
    [self waitForExpectations:@[expectation1, expectation2, expectation3, expectation4] timeout:1];
}

- (void)testAlreadyFulfilled {
    TWLPromise<NSNumber*,NSString*> *promise = [TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42];
    __block BOOL invoked = NO;
    [promise thenOnContext:TWLContext.immediate handler:^(id _Nonnull value) {
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
    XCTestExpectation *expectation = [self expectationOnSuccess:promise expectedValue:@43];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testMapReturningFulfilledPromise {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.utility handler:^id _Nonnull(NSNumber * _Nonnull x) {
        return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver fulfillWithValue:@(x.integerValue + 1)];
        }];
    }];
    XCTestExpectation *expectation = [self expectationOnSuccess:promise expectedValue:@43];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testMapReturningRejectedPromise {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.utility handler:^id _Nonnull(NSNumber * _Nonnull x) {
        return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver rejectWithError:@"error"];
        }];
    }];
    XCTestExpectation *expectation = [self expectationOnError:promise expectedError:@"error"];
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testMapReturningCancelledPromise {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] mapOnContext:TWLContext.utility handler:^id _Nonnull(NSNumber * _Nonnull x) {
        return [TWLPromise<NSNumber*,NSString*> newOnContext:TWLContext.utility withBlock:^(TWLResolver<NSNumber*,NSString*> * _Nonnull resolver) {
            [resolver cancel];
        }];
    }];
    XCTestExpectation *expectation = [self expectationOnCancel:promise];
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
        XCTestExpectation *expectation = [self expectationOnContext:[TWLContext queue:queue] onSuccess:promise handler:^(NSNumber * _Nonnull x) {
            XCTAssertEqual(i, resolved, @"callbacks invoked out of order");
            ++resolved;
            XCTAssertEqualObjects(x, @42);
        }];
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
    XCTestExpectation *expectaton = [self expectationOnSuccess:promise expectedValue:@42];
    [self waitForExpectations:@[expectaton] timeout:1];
}

- (void)testRecoverReturningPromise {
    TWLPromise<NSNumber*,NSString*> *promise = [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"] recoverOnContext:TWLContext.utility handler:^id _Nonnull(NSString * _Nonnull error) {
        return [TWLPromise newRejectedWithError:@"bar"];
    }];
    XCTestExpectation *expectation = [self expectationOnError:promise expectedError:@"bar"];
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
    XCTestExpectation *expectation = [self expectationOnSuccess:promise expectedValue:@43];
    [self waitForExpectations:@[expectation] timeout:1];
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
    XCTestExpectation *expectation = [self expectationOnCancel:chainPromise];
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
    XCTestExpectation *expectation = [self expectationOnError:chainPromise expectedError:@"foo"];
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
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:[NSString stringWithFormat:@"chain promise %zd", i]];
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
    XCTestExpectation *expectation2 = [self expectationOnSuccess:promise expectedValue:@42];
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
    XCTestExpectation *expectation2 = [self expectationOnError:promise expectedError:@"error"];
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
    XCTestExpectation *expectation2 = [self expectationOnCancel:promise];
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
    XCTestExpectation *cancelExpectation = [self expectationOnCancel:promise];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [promise requestCancel];
    });
    [self waitForExpectations:@[expectation, cancelExpectation] timeout:1];
}

- (void)testMultipleWhenCancelRequested {
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray array];
    for (NSInteger i = 1; i <= 3; ++i) {
        [expectations addObject:[[XCTestExpectation alloc] initWithDescription:[NSString stringWithFormat:@"whenCancelRequested %zd", i]]];
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

- (void)testLeavingPromiseUnresolvedTriggersCancel {
    dispatch_queue_t queue = dispatch_queue_create("test queue", DISPATCH_QUEUE_SERIAL);
    NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray array];
    for (NSInteger i = 1; i <= 3; ++i) {
        [expectations addObject:[[XCTestExpectation alloc] initWithDescription:[NSString stringWithFormat:@"promise %zd cancel", i]]];
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
            [resolver fulfillWithValue:[NSString stringWithFormat:@"%zd", value.integerValue + 1]];
        }];
        [innerPromise whenCancelledOnContext:TWLContext.utility handler:^{
            [innerExpectation fulfill];
        }];
        return innerPromise;
    }];
    XCTestExpectation *outerExpectation = [self expectationOnCancel:promise];
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
            [resolver fulfillWithValue:[NSString stringWithFormat:@"%zd", x.integerValue + 1]];
        }] ignoringCancel];
        [innerPromise thenOnContext:TWLContext.defaultQoS handler:^(NSString * _Nonnull x) {
            XCTAssertEqualObjects(x, @"43");
            [innerExpectation fulfill];
        }];
        return innerPromise;
    }];
    XCTestExpectation *outerExpectation = [self expectationOnSuccess:promise expectedValue:@"43"];
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

- (void)testResolverHandleCallback {
    TWLPromise *promise1 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallback](@42, nil);
    }];
    XCTestExpectation *expectation1 = [self expectationOnSuccess:promise1 expectedValue:@42];
    TWLPromise *promise2 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallback](nil, @"foo");
    }];
    XCTestExpectation *expectation2 = [self expectationOnError:promise2 expectedError:@"foo"];
    TWLPromise *promise3 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallback](@42, @"foo");
    }];
    XCTestExpectation *expectation3 = [self expectationOnSuccess:promise3 expectedValue:@42];
    TWLPromise *promise4 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallback](nil, nil);
    }];
    XCTestExpectation *expectation4 = [self expectationOnError:promise4 handler:^(NSError * _Nonnull error) {
        XCTAssertEqualObjects(error.domain, TWLPromiseCallbackErrorDomain);
        XCTAssertEqual(error.code, TWLPromiseCallbackErrorAPIMismatch);
    }];
    TWLPromise *promise5 = [TWLPromise newOnContext:TWLContext.utility withBlock:^(TWLResolver * _Nonnull resolver) {
        [resolver handleCallbackWithCancelPredicate:^BOOL(id _Nonnull error) {
            return [error isEqual:@"foo"];
        }](nil, @"foo");
    }];
    XCTestExpectation *expectation5 = [self expectationOnCancel:promise5];
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
