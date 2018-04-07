//
//  XCTestCase+TWLPromise.h
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

NS_ASSUME_NONNULL_BEGIN

// MARK: Success

#define TWLExpectationSuccess(promise) TWLExpectationSuccessOnContext(TWLContext.defaultQoS, promise)
#define TWLExpectationSuccessOnContext(context, promise) _TWLExpectationSuccessOnContext(self, context, promise)
#define _TWLExpectationSuccessOnContext(test, context, promise) \
({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise success"]; \
    expectation.assertForOverFulfill = YES; \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (error) { \
            XCTFail(@"Expected TWLPromise success, found error"); \
        } else if (!value) { \
            XCTFail(@"Expected TWLPromise success, found cancellation"); \
        } \
        [expectation fulfill]; \
    }]; \
    expectation; \
})

// MARK: -

#define TWLExpectationSuccessWithHandler(promise, handler) TWLExpectationSuccessWithHandlerOnContext(TWLContext.defaultQoS, promise, handler)
#define TWLExpectationSuccessWithHandlerOnContext(context, promise, handler) _TWLExpectationSuccessWithHandlerOnContext(self, context, promise, handler)
#define _TWLExpectationSuccessWithHandlerOnContext(test, context, promise, _handler) \
({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise success"]; \
    expectation.assertForOverFulfill = YES; \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (value) { \
            (_handler)(value); \
        } else if (error) { \
            XCTFail(@"Expected TWLPromise success, found error"); \
        } else { \
            XCTFail(@"Expected TWLPromise success, found cancellation"); \
        } \
        [expectation fulfill]; \
    }]; \
    expectation; \
})

// MARK: -

#define TWLExpectationSuccessWithValue(promise, expectedValue) TWLExpectationSuccessWithValueOnContext(TWLContext.defaultQoS, promise, expectedValue)
#define TWLExpectationSuccessWithValueOnContext(context, promise, expectedValue) \
    TWLExpectationSuccessWithHandlerOnContext(context, promise, ^(id _Nonnull value) { \
        XCTAssertEqualObjects(value, (expectedValue)); \
    })

// MARK: - Error

#define TWLExpectationError(promise) TWLExpectationErrorOnContext(TWLContext.defaultQoS, promise)
#define TWLExpectationErrorOnContext(context, promise) _TWLExpectationErrorOnContext(self, context, promise)
#define _TWLExpectationErrorOnContext(test, context, promise) \
({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise error"]; \
    expectation.assertForOverFulfill = YES; \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (value) { \
            XCTFail(@"Expected TWLPromise error, found success"); \
        } else if (!error) { \
            XCTFail(@"Expected TWLPromise error, found cancellation"); \
        } \
        [expectation fulfill]; \
    }]; \
    expectation; \
})

// MARK: -

#define TWLExpectationErrorWithHandler(promise, handler) TWLExpectationErrorWithHandlerOnContext(TWLContext.defaultQoS, promise, handler)
#define TWLExpectationErrorWithHandlerOnContext(context, promise, handler) _TWLExpectationErrorWithHandlerOnContext(self, context, promise, handler)
#define _TWLExpectationErrorWithHandlerOnContext(test, context, promise, _handler) \
({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise error"]; \
    expectation.assertForOverFulfill = YES; \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (error) { \
            (_handler)(error); \
        } else if (value) { \
            XCTFail(@"Expected TWLPromise error, found success"); \
        } else { \
            XCTFail(@"Expected TWLPromise error, found cancellation"); \
        } \
        [expectation fulfill]; \
    }]; \
    expectation; \
})

// MARK: -

#define TWLExpectationErrorWithError(promise, expectedError) TWLExpectationErrorWithErrorOnContext(TWLContext.defaultQoS, promise, expectedError)
#define TWLExpectationErrorWithErrorOnContext(context, promise, expectedError) \
    TWLExpectationErrorWithHandlerOnContext(context, promise, ^(id _Nonnull error) { \
        XCTAssertEqualObjects(error, (expectedError)); \
    })

// MARK: - Cancel

#define TWLExpectationCancel(promise) TWLExpectationCancelOnContext(TWLContext.defaultQoS, promise)
#define TWLExpectationCancelOnContext(context, promise) _TWLExpectationCancelOnContext(self, context, promise)
#define _TWLExpectationCancelOnContext(test, context, promise) \
({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise cancel"]; \
    expectation.assertForOverFulfill = YES; \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (value) { \
            XCTFail(@"Expected TWLPromise cancel, found success"); \
        } else if (error) { \
            XCTFail(@"Expected TWLPromise cancel, found error"); \
        } \
        [expectation fulfill]; \
    }]; \
    expectation; \
})

NS_ASSUME_NONNULL_END
