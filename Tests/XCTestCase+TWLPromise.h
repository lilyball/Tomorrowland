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
#define _TWLExpectationSuccessOnContext(test, context, promise) ({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise success"]; \
    expectation.assertForOverFulfill = YES; \
    TWLFulfillExpectationForPromiseSuccessOnContext(expectation, context, promise); \
    expectation; \
})

#define TWLFulfillExpectationForPromiseSuccess(expectation, promise) TWLFulfillExpectationForPromiseSuccessOnContext(expectation, TWLContext.defaultQoS, promise)
#define TWLFulfillExpectationForPromiseSuccessOnContext(expectation, context, promise) \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (error) { \
            XCTFail(@"Expected TWLPromise success, found error: %@", error); \
        } else if (!value) { \
            XCTFail(@"Expected TWLPromise success, found cancellation"); \
        } \
        [(expectation) fulfill]; \
    }]

// MARK: -

#define TWLExpectationSuccessWithHandler(promise, handler) TWLExpectationSuccessWithHandlerOnContext(TWLContext.defaultQoS, promise, handler)
#define TWLExpectationSuccessWithHandlerOnContext(context, promise, handler) _TWLExpectationSuccessWithHandlerOnContext(self, context, promise, handler)
#define _TWLExpectationSuccessWithHandlerOnContext(test, context, promise, handler) ({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise success"]; \
    expectation.assertForOverFulfill = YES; \
    TWLFulfillExpectationForPromiseSuccessWithHandlerOnContext(expectation, context, promise, handler); \
    expectation; \
})

#define TWLFulfillExpectationForPromiseSuccessWithHandler(expectation, promise, handler) TWLFulfillExpectationForPromiseSuccessWithHandlerOnContext(expectation, TWLContext.defaultQoS, promise, handler)
#define TWLFulfillExpectationForPromiseSuccessWithHandlerOnContext(expectation, context, promise, _handler) \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (value) { \
            (_handler)(value); \
        } else if (error) { \
            XCTFail(@"Expected TWLPromise success, found error: %@", error); \
        } else { \
            XCTFail(@"Expected TWLPromise success, found cancellation"); \
        } \
        [(expectation) fulfill]; \
    }]

// MARK: -

#define TWLExpectationSuccessWithValue(promise, expectedValue) TWLExpectationSuccessWithValueOnContext(TWLContext.defaultQoS, promise, expectedValue)
#define TWLExpectationSuccessWithValueOnContext(context, promise, expectedValue) \
    TWLExpectationSuccessWithHandlerOnContext(context, promise, ^(id _Nonnull value) { \
        XCTAssertEqualObjects(value, (expectedValue)); \
    })

#define TWLFulfillExpectationForPromiseSuccessWithValue(expectation, promise, expectedValue) TWLFulfillExpectationForPromiseSuccessWithValueOnContext(expectation, TWLContext.defaultQoS, promise, expectedValue)
#define TWLFulfillExpectationForPromiseSuccessWithValueOnContext(expectation, context, promise, expectedValue) \
    TWLFulfillExpectationForPromiseSuccessWithHandlerOnContext(expectation, context, promise, ^(id _Nonnull value) { \
        XCTAssertEqualObjects(value, (expectedValue)); \
    })

// MARK: - Error

#define TWLExpectationError(promise) TWLExpectationErrorOnContext(TWLContext.defaultQoS, promise)
#define TWLExpectationErrorOnContext(context, promise) _TWLExpectationErrorOnContext(self, context, promise)
#define _TWLExpectationErrorOnContext(test, context, promise) ({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise error"]; \
    expectation.assertForOverFulfill = YES; \
    TWLFulfillExpectationForPromiseErrorOnContext(expectation, context, promise); \
    expectation; \
})

#define TWLFulfillExpectationForPromiseError(expectation, promise) TWLFulfillExpectationForPromiseErrorOnContext(expectation, TWLContext.defaultQoS, promise)
#define TWLFulfillExpectationForPromiseErrorOnContext(expectation, context, promise) \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (value) { \
            XCTFail(@"Expected TWLPromise failure, found value: %@", value); \
        } else if (!error) { \
            XCTFail(@"Expected TWLPromise failure, found cancellation"); \
        } \
        [(expectation) fulfill]; \
    }]

// MARK: -

#define TWLExpectationErrorWithHandler(promise, handler) TWLExpectationErrorWithHandlerOnContext(TWLContext.defaultQoS, promise, handler)
#define TWLExpectationErrorWithHandlerOnContext(context, promise, handler) _TWLExpectationErrorWithHandlerOnContext(self, context, promise, handler)
#define _TWLExpectationErrorWithHandlerOnContext(test, context, promise, handler) \
({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise error"]; \
    expectation.assertForOverFulfill = YES; \
    TWLFulfillExpectationForPromiseErrorWithHandlerOnContext(expectation, context, promise, handler); \
    expectation; \
})

#define TWLFulfillExpectationForPromiseErrorWithHandler(expectation, promise, handler) TWLFulfillExpectationForPromiseErrorWithHandlerOnContext(expectation, TWLContext.defaultQoS, promise, handler)
#define TWLFulfillExpectationForPromiseErrorWithHandlerOnContext(expectation, context, promise, _handler) \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (error) { \
            (_handler)(error); \
        } else if (value) { \
            XCTFail(@"Expected TWLPromise failure, found value: %@", value); \
        } else { \
            XCTFail(@"Expected TWLPromise failure, found cancellation"); \
        } \
        [(expectation) fulfill]; \
    }]

// MARK: -

#define TWLExpectationErrorWithError(promise, expectedError) TWLExpectationErrorWithErrorOnContext(TWLContext.defaultQoS, promise, expectedError)
#define TWLExpectationErrorWithErrorOnContext(context, promise, expectedError) \
    TWLExpectationErrorWithHandlerOnContext(context, promise, ^(id _Nonnull error) { \
        XCTAssertEqualObjects(error, (expectedError)); \
    })

#define TWLFulfillExpectationForPromiseErrorWithError(expectation, promise, expectedError) TWLFulfillExpectationForPromiseErrorWithErrorOnContext(expectation, TWLContext.defaultQoS, promise, expectedError)
#define TWLFulfillExpectationForPromiseErrorWithErrorOnContext(expectation, context, promise, expectedError) \
    TWLFulfillExpectationForPromiseErrorWithHandlerOnContext(expectation, context, promise, ^(id _Nonnull error) { \
        XCTAssertEqualObjects(error, (expectedError)); \
    })

// MARK: - Cancel

#define TWLExpectationCancel(promise) TWLExpectationCancelOnContext(TWLContext.defaultQoS, promise)
#define TWLExpectationCancelOnContext(context, promise) _TWLExpectationCancelOnContext(self, context, promise)
#define _TWLExpectationCancelOnContext(test, context, promise) \
({ \
    XCTestExpectation *expectation = [(test) expectationWithDescription:@"Expectation for TWLPromise cancel"]; \
    expectation.assertForOverFulfill = YES; \
    TWLFulfillExpectationForPromiseCancellationOnContext(expectation, context, promise); \
    expectation; \
})

#define TWLFulfillExpectationForPromiseCancellation(expectation, promise) TWLFulfillExpectationForPromiseCancellationOnContext(expectation, TWLContext.defaultQoS, promise)
#define TWLFulfillExpectationForPromiseCancellationOnContext(expectation, context, promise) \
    [(promise) tapOnContext:(context) handler:^(id _Nullable value, id _Nullable error) { \
        if (value) { \
            XCTFail(@"Expected TWLPromise cancellation, found value: %@", value); \
        } else if (error) { \
            XCTFail(@"Expected TWLPromise cancellation, found error: %@", error); \
        } \
        [(expectation) fulfill]; \
    }]

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

#define TWLAssertPromiseNotResolved(promise) do { \
    id _value, _error; \
    if ([promise getValue:&_value error:&_error]) { \
        if (_value) { \
            XCTFail("promise - expected not resolved, but was fulfilled with %@", _value); \
        } else if (_error) { \
            XCTFail("promise - expected not resolved, but was rejected with %@", _error); \
        } else { \
            XCTFail("promise - expected not resolved, but was cancelled"); \
        } \
    } \
} while (0)

NS_ASSUME_NONNULL_END
