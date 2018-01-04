//
//  XCTestCase+TWLPromise.m
//  TomorrowlandTests
//
//  Created by Kevin Ballard on 1/1/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//

#import "XCTestCase+TWLPromise.h"
@import Tomorrowland;

@implementation XCTestCase (TWLPromise)

- (XCTestExpectation *)expectationOnSuccess:(TWLPromise *)promise {
    return [self expectationOnContext:TWLContext.defaultQoS onSuccess:promise];
}

- (XCTestExpectation *)expectationOnSuccess:(TWLPromise *)promise handler:(void (^)(id _Nonnull))handler {
    return [self expectationOnContext:TWLContext.defaultQoS onSuccess:promise handler:handler];
}

- (XCTestExpectation *)expectationOnSuccess:(TWLPromise *)promise expectedValue:(id)expectedValue {
    return [self expectationOnContext:TWLContext.defaultQoS onSuccess:promise expectedValue:expectedValue];
}

- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onSuccess:(nonnull TWLPromise *)promise {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation for TWLPromise success"];
    expectation.assertForOverFulfill = YES;
    [promise inspectOnContext:context handler:^(id _Nullable value, id _Nullable error) {
        if (error) {
            XCTFail(@"Expected TWLPromise success, found error");
        } else if (!value) {
            XCTFail(@"Expected TWLPromise success, found cancellation");
        }
        [expectation fulfill];
    }];
    return expectation;
}

- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onSuccess:(TWLPromise *)promise handler:(void (^)(id _Nonnull))handler {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation for TWLPromise success"];
    expectation.assertForOverFulfill = YES;
    [promise inspectOnContext:context handler:^(id _Nullable value, id _Nullable error) {
        if (value) {
            handler(value);
        } else if (error) {
            XCTFail(@"Expected TWLPromise success, found error");
        } else {
            XCTFail(@"Expected TWLPromise success, found cancellation");
        }
        [expectation fulfill];
    }];
    return expectation;
}

- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onSuccess:(TWLPromise *)promise expectedValue:(id)expectedValue {
    return [self expectationOnContext:context onSuccess:promise handler:^(id  _Nonnull value) {
        XCTAssertEqualObjects(value, expectedValue);
    }];
}

- (XCTestExpectation *)expectationOnError:(TWLPromise *)promise {
    return [self expectationOnContext:TWLContext.defaultQoS onError:promise];
}

- (XCTestExpectation *)expectationOnError:(TWLPromise *)promise handler:(void (^)(id _Nonnull))handler {
    return [self expectationOnContext:TWLContext.defaultQoS onError:promise handler:handler];
}

- (XCTestExpectation *)expectationOnError:(TWLPromise *)promise expectedError:(id)expectedError {
    return [self expectationOnContext:TWLContext.defaultQoS onError:promise expectedError:expectedError];
}

- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onError:(TWLPromise *)promise {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation for TWLPromise error"];
    expectation.assertForOverFulfill = YES;
    [promise inspectOnContext:context handler:^(id _Nullable value, id _Nullable error) {
        if (value) {
            XCTFail(@"Expected TWLPromise error, found success");
        } else if (!error) {
            XCTFail(@"Expected TWLPromise error, found cancellation");
        }
        [expectation fulfill];
    }];
    return expectation;
}

- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onError:(TWLPromise *)promise handler:(void (^)(id _Nonnull))handler {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation for TWLPromise error"];
    expectation.assertForOverFulfill = YES;
    [promise inspectOnContext:context handler:^(id _Nullable value, id _Nullable error) {
        if (error) {
            handler(error);
        } else if (value) {
            XCTFail(@"Expected TWLPromise error, found success");
        } else {
            XCTFail(@"Expected TWLPromise error, found cancellation");
        }
        [expectation fulfill];
    }];
    return expectation;
}

- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onError:(TWLPromise *)promise expectedError:(id)expectedError {
    return [self expectationOnContext:context onError:promise handler:^(id  _Nonnull error) {
        XCTAssertEqualObjects(error, expectedError);
    }];
}

- (XCTestExpectation *)expectationOnCancel:(TWLPromise *)promise {
    return [self expectationOnContext:TWLContext.defaultQoS onCancel:promise];
}

- (XCTestExpectation *)expectationOnContext:(TWLContext *)context onCancel:(TWLPromise *)promise {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation for TWLPromise cancel"];
    expectation.assertForOverFulfill = YES;
    [promise inspectOnContext:context handler:^(id _Nullable value, id _Nullable error) {
        if (value) {
            XCTFail(@"Expected TWLPromise cancel, found success");
        } else if (error) {
            XCTFail(@"Expected TWLPromise cancel, found error");
        }
        [expectation fulfill];
    }];
    return expectation;
}

@end
