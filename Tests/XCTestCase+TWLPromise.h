//
//  XCTestCase+TWLPromise.h
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

// MARK: -

#define TWLAssertPromiseFulfilledWithValue(promise, expectedValue) do { \
    id _value, _error; \
    if ([promise getValue:&_value error:&_error]) { \
        if (_value) { \
            XCTAssertEqualObjects(_value, expectedValue, @"promise fulfilled value"); \
        } else if (_error) { \
            XCTFail(@"promise - expected fulfilled with %@, but was rejected with %@", expectedValue, _error); \
        } else { \
            XCTFail(@"promise - expected fulfilled with %@, but was cancelled", expectedValue); \
        } \
    } else { \
        XCTFail(@"promise - expected fulfilled with %@, but was not resolved", expectedValue); \
    } \
} while (0)

#define TWLAssertPromiseRejectedWithError(promise, expectedError) do { \
    id _value, _error; \
    if ([promise getValue:&_value error:&_error]) { \
        if (_value) { \
            XCTFail(@"promise - expected rejected with %@, but was fulfilled with %@", expectedError, _value); \
        } else if (_error) { \
            XCTAssertEqualObjects(_error, expectedError, @"promise rejected error"); \
        } else { \
            XCTFail(@"promise - expected rejected with %@, but was cancelled", expectedError); \
        } \
    } else { \
        XCTFail(@"promise - expected rejected with %@, but was not resolved", expectedError); \
    } \
} while (0)

#define TWLAssertPromiseCancelled(promise) do { \
    id _value, _error; \
    if ([promise getValue:&_value error:&_error]) { \
        if (_value) { \
            XCTFail(@"promise - expected cancelled, but was fulfilled with %@", _value); \
        } else if (_error) { \
            XCTFail(@"promise - expected cancelled, but was rejected with %@", _error); \
        } \
    } else { \
        XCTFail(@"promise - expected cancelled, but was not resolved"); \
    } \
} while (0)

NS_ASSUME_NONNULL_END
