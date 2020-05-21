//
//  TWLWhen.m
//  Tomorrowland
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

#import "TWLWhen.h"
#import "TWLOneshotBlock.h"
#import "TWLPromisePrivate.h"
#import "TWLContextPrivate.h"
#import <Tomorrowland/TWLContext.h>

@implementation TWLPromise (When)

+ (TWLPromise<NSArray *,id> *)whenFulfilled:(NSArray<TWLPromise *> *)promises {
    return [self whenFulfilled:promises qos:QOS_CLASS_DEFAULT cancelOnFailure:NO];
}

+ (TWLPromise<NSArray *,id> *)whenFulfilled:(NSArray<TWLPromise *> *)promises qos:(dispatch_qos_class_t)qosClass {
    return [self whenFulfilled:promises qos:qosClass cancelOnFailure:NO];
}

+ (TWLPromise<NSArray *,id> *)whenFulfilled:(NSArray<TWLPromise *> *)promises cancelOnFailure:(BOOL)cancelOnFailure {
    return [self whenFulfilled:promises qos:QOS_CLASS_DEFAULT cancelOnFailure:cancelOnFailure];
}

+ (TWLPromise<NSArray *,id> *)whenFulfilled:(NSArray<TWLPromise *> *)promises qos:(dispatch_qos_class_t)qosClass cancelOnFailure:(BOOL)cancelOnFailure {
    if (promises.count == 0) {
        return [TWLPromise newFulfilledWithValue:@[]];
    }
    TWLOneshotBlock *cancelAllInput;
    if (cancelOnFailure) {
        cancelAllInput = [[TWLOneshotBlock alloc] initWithBlock:^{
            for (TWLPromise *promise in promises) {
                [promise requestCancel];
            }
        }];
    }
    
    TWLResolver *resolver;
    TWLPromise *resultPromise = [[TWLPromise alloc] initWithResolver:&resolver];
    NSUInteger count = promises.count;
    id _Nullable __unsafe_unretained * _Nonnull resultBuffer = (id _Nullable __unsafe_unretained *)calloc((size_t)count, sizeof(id));
    dispatch_group_t group = dispatch_group_create();
    TWLContext *context = [TWLContext contextForQoS:qosClass];
    for (NSUInteger i = 0; i < count; ++i) {
        TWLPromise *promise = promises[i];
        dispatch_group_enter(group);
        [promise enqueueCallbackWithoutOneshot:^(id _Nullable value, id _Nullable error, BOOL isSynchronous) {
            [context executeIsSynchronous:isSynchronous block:^{
                if (value) {
                    resultBuffer[i] = (__bridge id)CFBridgingRetain(value);
                } else if (error) {
                    [resolver rejectWithError:error];
                    [cancelAllInput invoke];
                } else {
                    [resolver cancel];
                    [cancelAllInput invoke];
                }
                dispatch_group_leave(group);
            }];
        } willPropagateCancel:YES];
    }
    dispatch_group_notify(group, dispatch_get_global_queue(qosClass, 0), ^{
        @try {
            for (NSUInteger i = 0; i < count; ++i) {
                if (resultBuffer[i] == NULL) {
                    // Must have had a rejected or cancelled promise
                    return;
                }
            }
            NSArray *results = [[NSArray alloc] initWithObjects:(id __unsafe_unretained *)resultBuffer count:count];
            [resolver fulfillWithValue:results];
        } @finally {
            for (NSUInteger i = 0; i < count; ++i) {
                (void)CFBridgingRelease((__bridge CFTypeRef)(resultBuffer[i]));
            }
        }
    });
    NSHashTable *boxes = [NSHashTable weakObjectsHashTable];
    for (TWLPromise *promise in promises) {
        [boxes addObject:promise->_box];
    }
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        for (TWLObjCPromiseBox *box in boxes) {
            [box propagateCancel];
        }
    }];
    return resultPromise;
}

+ (TWLPromise *)race:(NSArray<TWLPromise *> *)promises {
    return [self race:promises cancelRemaining:NO];
}

+ (TWLPromise *)race:(NSArray<TWLPromise *> *)promises cancelRemaining:(BOOL)cancelRemaining {
    if (promises.count == 0) {
        return [TWLPromise newOnContext:TWLContext.immediate withBlock:^(TWLResolver * _Nonnull resolver) {
            [resolver cancel];
        }];
    }
    TWLOneshotBlock *cancelAllInput;
    if (cancelRemaining) {
        cancelAllInput = [[TWLOneshotBlock alloc] initWithBlock:^{
            for (TWLPromise *promise in promises) {
                [promise requestCancel];
            }
        }];
    }
    
    TWLResolver *resolver;
    TWLPromise *newPromise = [[TWLPromise alloc] initWithResolver:&resolver];
    dispatch_group_t group = dispatch_group_create();
    for (TWLPromise *promise in promises) {
        dispatch_group_enter(group);
        [promise enqueueCallbackWithoutOneshot:^(id _Nullable value, id _Nullable error, BOOL isSynchronous) {
            if (value) {
                [resolver fulfillWithValue:value];
                [cancelAllInput invoke];
            } else if (error) {
                [resolver rejectWithError:error];
                [cancelAllInput invoke];
            }
            dispatch_group_leave(group);
        } willPropagateCancel:YES];
    }
    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [resolver cancel];
    });
    NSHashTable *boxes = [NSHashTable weakObjectsHashTable];
    for (TWLPromise *promise in promises) {
        [boxes addObject:promise->_box];
    }
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        for (TWLObjCPromiseBox *box in boxes) {
            [box propagateCancel];
        }
    }];
    return newPromise;
}

@end
