//
//  TWLUtilities.m
//  Tomorrowland
//
//  Created by Lily Ballard on 1/5/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLUtilities.h"
#import "TWLPromisePrivate.h"
#import "TWLContextPrivate.h"
#import "TWLOneshotBlock.h"
#import "TWLBlockOperation.h"

@implementation TWLPromise (Utilities)

+ (instancetype)newFulfilledWithValue:(id)value afterDelay:(NSTimeInterval)delay {
    return [[self alloc] initFulfilledOnContext:TWLContext.automatic withValue:value afterDelay:delay];
}

+ (instancetype)newFulfilledOnContext:(TWLContext *)context withValue:(id)value afterDelay:(NSTimeInterval)delay {
    return [[self alloc] initFulfilledOnContext:context withValue:value afterDelay:delay];
}

+ (instancetype)newRejectedWithError:(id)error afterDelay:(NSTimeInterval)delay {
    return [[self alloc] initRejectedOnContext:TWLContext.automatic withError:error afterDelay:delay];
}

+ (instancetype)newRejectedOnContext:(TWLContext *)context withError:(id)error afterDelay:(NSTimeInterval)delay {
    return [[self alloc] initRejectedOnContext:context withError:error afterDelay:delay];
}

+ (instancetype)newCancelledAfterDelay:(NSTimeInterval)delay {
    return [[self alloc] initCancelledOnContext:TWLContext.automatic afterDelay:delay];
}

+ (instancetype)newCancelledOnContext:(TWLContext *)context afterDelay:(NSTimeInterval)delay {
    return [[self alloc] initCancelledOnContext:context afterDelay:delay];
}

- (instancetype)initFulfilledWithValue:(id)value afterDelay:(NSTimeInterval)delay {
    return [self initFulfilledOnContext:TWLContext.automatic withValue:value afterDelay:delay];
}

- (instancetype)initFulfilledOnContext:(TWLContext *)context withValue:(id)value afterDelay:(NSTimeInterval)delay {
    TWLResolver *resolver;
    if ((self = [self initWithResolver:&resolver])) {
        resolveAfterDelay(resolver, context, value, nil, delay);
    }
    return self;
}

- (instancetype)initRejectedWithError:(id)error afterDelay:(NSTimeInterval)delay {
    return [self initRejectedOnContext:TWLContext.automatic withError:error afterDelay:delay];
}

- (instancetype)initRejectedOnContext:(TWLContext *)context withError:(id)error afterDelay:(NSTimeInterval)delay {
    TWLResolver *resolver;
    if ((self = [self initWithResolver:&resolver])) {
        resolveAfterDelay(resolver, context, nil, error, delay);
    }
    return self;
}

- (instancetype)initCancelledAfterDelay:(NSTimeInterval)delay {
    return [self initCancelledOnContext:TWLContext.automatic afterDelay:delay];
}

- (instancetype)initCancelledOnContext:(TWLContext *)context afterDelay:(NSTimeInterval)delay {
    TWLResolver *resolver;
    if ((self = [self initWithResolver:&resolver])) {
        resolveAfterDelay(resolver, context, nil, nil, delay);
    }
    return self;
}

static void resolveAfterDelay(TWLResolver * _Nonnull resolver, TWLContext * _Nonnull context, id _Nullable value, id _Nullable error, NSTimeInterval delay) {
    dispatch_source_t timer;
    dispatch_queue_t queue;
    NSOperationQueue *operationQueue;
    [context getDestinationQueue:&queue operationQueue:&operationQueue];
    if (queue) {
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_event_handler(timer, ^{
            [resolver resolveWithValue:value error:error];
        });
    } else {
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
        __auto_type operation = [TWLBlockOperation blockOperationWithBlock:^{
            [resolver resolveWithValue:value error:error];
        }];
        dispatch_source_set_event_handler(timer, ^{
            [operation markReady];
        });
        dispatch_source_set_cancel_handler(timer, ^{
            // Clean up the operation
            [operation cancel];
            [operation markReady];
        });
        [operationQueue addOperation:operation];
    }
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        dispatch_source_cancel(timer); // NB: This reference also keeps the timer alive
        [resolver cancel];
    }];
    // Using ~0 as the interval is the same trick the Swift Dispatch overlay uses for oneshot timers.
    // The timer will clean itself up when all references to it go away.
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC)), ~0, 0);
    dispatch_resume(timer);
}

// MARK: -

- (TWLPromise *)delay:(NSTimeInterval)delay {
    return [self delay:delay onContext:TWLContext.automatic];
}

- (TWLPromise *)delay:(NSTimeInterval)delay onContext:(TWLContext *)context {
    TWLResolver *resolver;
    TWLPromise *promise = [[TWLPromise alloc] initWithResolver:&resolver];
    dispatch_queue_t queue;
    NSOperationQueue *operationQueue;
    [context getDestinationQueue:&queue operationQueue:&operationQueue];
    if (queue) {
        [self enqueueCallbackWithoutOneshot:^(id _Nullable value, id _Nullable error, BOOL isSynchronous) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC)), queue, ^{
                [resolver resolveWithValue:value error:error];
            });
        } willPropagateCancel:YES];
    } else {
        __auto_type operation = [TWLBlockOperation new];
        [self enqueueCallbackWithoutOneshot:^(id _Nullable value, id _Nullable error, BOOL isSynchronous) {
            [operation addExecutionBlock:^{
                [resolver resolveWithValue:value error:error];
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                [operation markReady];
            });
        } willPropagateCancel:YES];
        [operationQueue addOperation:operation];
    }
    __weak TWLObjCPromiseBox *box = _box;
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        [box propagateCancel];
    }];
    return promise;
}

- (TWLPromise *)timeoutWithDelay:(NSTimeInterval)delay {
    return [self timeoutOnContext:TWLContext.automatic withDelay:delay];
}

- (TWLPromise *)timeoutOnContext:(TWLContext *)context withDelay:(NSTimeInterval)delay {
    TWLResolver *resolver;
    TWLPromise *promise = [[TWLPromise alloc] initWithResolver:&resolver];
    __weak TWLObjCPromiseBox *weakBox = _box;
    __weak TWLObjCPromiseBox *weakNewBox = promise->_box;
    TWLOneshotBlock *propagateCancelBlock = [[TWLOneshotBlock alloc] initWithBlock:^{
        [weakBox propagateCancel];
    }];
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        TWLObjCPromiseBox *newBox = weakNewBox;
        if (newBox) {
            TWLResolver *resolver = [[TWLResolver alloc] initWithBox:newBox];
            // double-check the result just in case
            id value;
            id error;
            if ([weakBox getValue:&value error:&error]) {
                if (error) {
                    error = [TWLTimeoutError newWithRejectedError:error];
                }
                [resolver resolveWithValue:value error:error];
            } else {
                [resolver rejectWithError:[TWLTimeoutError newTimedOut]];
            }
        }
        [propagateCancelBlock invoke];
    });
    dispatch_queue_t queue;
    NSOperationQueue *operationQueue;
    TWLBlockOperation *operation;
    [context getDestinationQueue:&queue operationQueue:&operationQueue];
    if (operationQueue) {
        operation = [TWLBlockOperation blockOperationWithBlock:timeoutBlock];
    }
    [self enqueueCallbackWithoutOneshot:^(id _Nullable value, id _Nullable error, BOOL isSynchronous) {
        dispatch_block_cancel(timeoutBlock);
        if (error) {
            error = [TWLTimeoutError newWithRejectedError:error];
        }
        [context executeIsSynchronous:isSynchronous block:^{
            [resolver resolveWithValue:value error:error];
        }];
        [operation cancel]; // Clean up the operation early
        [operation markReady];
    } willPropagateCancel:YES];
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        [propagateCancelBlock invoke];
    }];
    if (queue) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC)), queue, timeoutBlock);
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [operation markReady];
        });
        [operationQueue addOperation:operation];
    }
    return promise;
}

@end

@implementation TWLTimeoutError

+ (instancetype)newTimedOut {
    return [[self alloc] initTimedOut];
}

+ (instancetype)newWithRejectedError:(id)error {
    return [[self alloc] initWithRejectedError:error];
}

- (instancetype)initTimedOut {
    if ((self = [super init])) {
        _timedOut = YES;
    }
    return self;
}

- (instancetype)initWithRejectedError:(id)error {
    if ((self = [super init])) {
        _rejectedError = error;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TWLTimeoutError class]]) return NO;
    TWLTimeoutError *other = object;
    if (self.timedOut) {
        return other.timedOut;
    } else {
        return [self.rejectedError isEqual:other.rejectedError];
    }
}

- (NSUInteger)hash {
    if (self.timedOut) {
        return 1;
    } else {
        return [self.rejectedError hash] << 1;
    }
}

@end
