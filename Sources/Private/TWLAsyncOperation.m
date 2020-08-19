//
//  TWLAsyncOperation.m
//  Tomorrowland
//
//  Created by Lily Ballard on 8/18/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLAsyncOperation+Private.h"
#import <stdatomic.h>

@implementation TWLAsyncOperation {
    atomic_ulong _state;
}

- (TWLAsyncOperationState)state {
    return atomic_load_explicit(&_state, memory_order_relaxed);
}

- (void)setState:(TWLAsyncOperationState)state {
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    atomic_store_explicit(&_state, state, memory_order_relaxed);
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)start {
    if (self.state != TWLAsyncOperationStateInitial) {
        // Attempted to call -start after it's already been started.
        return;
    }
    self.state = TWLAsyncOperationStateExecuting;
    [self main];
}

- (void)main {
    // This should be overridden. If it does get invoked, just mark ourselves as finished.
    NSAssert(self.state == TWLAsyncOperationStateExecuting, @"-[TWLAsyncOperation main] invoked while the operation was not executing.");
    self.state = TWLAsyncOperationStateFinished;
}

- (BOOL)isExecuting {
    switch (self.state) {
        case TWLAsyncOperationStateInitial:
        case TWLAsyncOperationStateFinished:
            return NO;
        case TWLAsyncOperationStateExecuting:
            return YES;
    }
}

- (BOOL)isFinished {
    switch (self.state) {
        case TWLAsyncOperationStateInitial:
        case TWLAsyncOperationStateExecuting:
            return NO;
        case TWLAsyncOperationStateFinished:
            return YES;
    }
}

- (BOOL)isAsynchronous {
    return YES;
}

@end
