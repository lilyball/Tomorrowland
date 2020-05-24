//
//  TWLPromise+ConvenienceTests.m
//  TomorrowlandTests
//
//  Created by Lily Ballard on 5/23/20.
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

@interface TWLPromise_ConvenienceTests : XCTestCase
@end

@implementation TWLPromise_ConvenienceTests

- (void)testThenCatch {
    // Fulfilled
    {
        __auto_type expectation = [XCTestExpectation new];
        [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] then:^(NSNumber * _Nonnull value) {
            XCTAssertEqualObjects(value, @42);
            [expectation fulfill];
        } catch:^(NSString * _Nonnull error) {
            XCTFail(@"Unexpected failure");
        }];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Rejected
    {
        __auto_type expectation = [XCTestExpectation new];
        [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"] then:^(NSNumber * _Nonnull value) {
            XCTFail(@"Unexpected success");
        } catch:^(NSString * _Nonnull error) {
            XCTAssertEqualObjects(error, @"foo");
            [expectation fulfill];
        }];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Cancelled
    {
        __auto_type expectation = [XCTestExpectation new];
        [[[TWLPromise<NSNumber*,NSString*> newCancelled] then:^(NSNumber * _Nonnull value) {
            XCTFail(@"Unexpected success");
        } catch:^(NSString * _Nonnull error) {
            XCTFail(@"Unexpected failure");
        }] inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
            [expectation fulfill];
        }];
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testThenCatchOnContext {
    // Fulfilled
    {
        __auto_type expectation = [XCTestExpectation new];
        [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] onContext:[TWLContext queue:TestQueue.one] then:^(NSNumber * _Nonnull value) {
            AssertOnTestQueue(1);
            XCTAssertEqualObjects(value, @42);
            [expectation fulfill];
        } catch:^(NSString * _Nonnull error) {
            XCTFail(@"Unexpected failure");
        }];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Rejected
    {
        __auto_type expectation = [XCTestExpectation new];
        [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"] onContext:[TWLContext queue:TestQueue.one] then:^(NSNumber * _Nonnull value) {
            XCTFail(@"Unexpected success");
        } catch:^(NSString * _Nonnull error) {
            AssertOnTestQueue(1);
            XCTAssertEqualObjects(error, @"foo");
            [expectation fulfill];
        }];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Cancelled
    {
        __auto_type expectation = [XCTestExpectation new];
        dispatch_async(TestQueue.two, ^{
            [[[TWLPromise<NSNumber*,NSString*> newCancelled] onContext:[TWLContext queue:TestQueue.one] then:^(NSNumber * _Nonnull value) {
                XCTFail(@"Unexpected success");
            } catch:^(NSString * _Nonnull error) {
                XCTFail(@"Unexpected failure");
            }] inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
                AssertOnTestQueue(2); // cancellation is immediate instead of hopping through the given context
                [expectation fulfill];
            }];
        });
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

- (void)testThenCatchOnContextWithToken {
    __auto_type token = [TWLInvalidationToken new];
    
    // Fulfilled, no token invalidation
    {
        __auto_type expectation = [XCTestExpectation new];
        [[TWLPromise<NSNumber*,NSString*> newFulfilledWithValue:@42] onContext:[TWLContext queue:TestQueue.one] token:token then:^(NSNumber * _Nonnull value) {
            AssertOnTestQueue(1);
            XCTAssertEqualObjects(value, @42);
            [expectation fulfill];
        } catch:^(NSString * _Nonnull error) {
            XCTFail(@"Unexpected failure");
        }];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Fullfiled with token invalidation
    {
        TWLResolver<NSNumber*,NSString*> *resolver;
        __auto_type promise = [[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
        __auto_type childPromise = [promise onContext:[TWLContext queue:TestQueue.one] token:token then:^(NSNumber * _Nonnull value) {
            XCTFail(@"Then callback evaluated despite token invalidation");
        } catch:^(NSString * _Nonnull error) {
            XCTFail(@"Catch callback evaluated despite token invalidation");
        }];
        __auto_type expectation = TWLExpectationSuccessWithHandlerOnContext(TWLContext.immediate, childPromise, ^(NSNumber * _Nonnull value) {
            XCTAssertEqualObjects(value, @42);
            AssertOnTestQueue(1); // resolves on given context despite token
        });
        [token invalidate];
        dispatch_async(TestQueue.two, ^{
            [resolver fulfillWithValue:@42];
        });
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Rejected, no token invalidation
    {
        __auto_type expectation = [XCTestExpectation new];
        [[TWLPromise<NSNumber*,NSString*> newRejectedWithError:@"foo"] onContext:[TWLContext queue:TestQueue.one] token:token then:^(NSNumber * _Nonnull value) {
            XCTFail(@"Unexpected success");
        } catch:^(NSString * _Nonnull error) {
            AssertOnTestQueue(1);
            XCTAssertEqualObjects(error, @"foo");
            [expectation fulfill];
        }];
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Rejected with token invalidation
    {
        TWLResolver<NSNumber*,NSString*> *resolver;
        __auto_type promise = [[TWLPromise<NSNumber*,NSString*> alloc] initWithResolver:&resolver];
        __auto_type childPromise = [promise onContext:[TWLContext queue:TestQueue.one] token:token then:^(NSNumber * _Nonnull value) {
            XCTFail(@"Then callback evaluated despite token invalidation");
        } catch:^(NSString * _Nonnull error) {
            XCTFail(@"Catch callback evaluated despite token invalidation");
        }];
        __auto_type expectation = TWLExpectationErrorWithHandlerOnContext(TWLContext.immediate, childPromise, ^(NSString * _Nonnull error) {
            XCTAssertEqualObjects(error, @"foo");
            AssertOnTestQueue(1); // resolves on given context despite token
        });
        [token invalidate];
        dispatch_async(TestQueue.two, ^{
            [resolver rejectWithError:@"foo"];
        });
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Cancelled, no token invalidation
    {
        __auto_type expectation = [XCTestExpectation new];
        dispatch_async(TestQueue.two, ^{
            [[[TWLPromise<NSNumber*,NSString*> newCancelled] onContext:[TWLContext queue:TestQueue.one] token:token then:^(NSNumber * _Nonnull value) {
                XCTFail(@"Unexpected success");
            } catch:^(NSString * _Nonnull error) {
                XCTFail(@"Unexpected failure");
            }] inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
                AssertOnTestQueue(2); // cancellation is immediate instead of hopping through the given context
                [expectation fulfill];
            }];
        });
        [self waitForExpectations:@[expectation] timeout:1];
    }
    
    // Cancelled with token invalidation
    // The token shouldn't affect anything at all as the promise was cancelled.
    {
        __auto_type expectation = [XCTestExpectation new];
        dispatch_async(TestQueue.two, ^{
            [[[TWLPromise<NSNumber*,NSString*> newCancelled] onContext:[TWLContext queue:TestQueue.one] token:token then:^(NSNumber * _Nonnull value) {
                XCTFail(@"Unexpected success");
            } catch:^(NSString * _Nonnull error) {
                XCTFail(@"Unexpected failure");
            }] inspectOnContext:TWLContext.immediate handler:^(NSNumber * _Nullable value, NSString * _Nullable error) {
                AssertOnTestQueue(2); // cancellation is immediate instead of hopping through the given context
                [expectation fulfill];
            }];
        });
        [self waitForExpectations:@[expectation] timeout:1];
    }
}

@end
