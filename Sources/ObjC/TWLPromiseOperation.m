//
//  TWLPromiseOperation.m
//  Tomorrowland
//
//  Created by Lily Ballard on 8/19/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLPromiseOperation.h"
#import "TWLAsyncOperation+Private.h"
#import "TWLPromisePrivate.h"
#import "TWLPromiseBox.h"
#import "TWLContextPrivate.h"

@implementation TWLPromiseOperation {
    TWLContext * _Nullable _context;
    void (^ _Nullable _callback)(TWLResolver * _Nonnull);
    
    /// The box for our internal promise.
    TWLObjCPromiseBox * _Nonnull _box;
    
    /// The actual promise we return to our callers.
    ///
    /// This is a child of our internal promise. This way we can observe cancellation requests while
    /// our box is still in the delayed state, and when we go out of scope the promise will get
    /// cancelled if the callback was never invoked.
    TWLPromise * _Nonnull _promise;
}

+ (instancetype)newOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<id,id> * _Nonnull))handler {
    return [[self alloc] initOnContext:context handler:handler];
}

- (instancetype)initOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<id,id> * _Nonnull))handler {
    if ((self = [super init])) {
        _context = context;
        TWLResolver *childResolver;
        TWLPromise *childPromise = [[TWLPromise alloc] initWithResolver:&childResolver];
        _promise = childPromise;
        TWLPromise *promise = [[TWLPromise alloc] initDelayed];
        _box = promise->_box;
        _callback = ^(TWLResolver * _Nonnull resolver) {
            // We piped data from the inner promise to the outer promise at the end of -init
            // already, but we need to propagate cancellation the other way. We're deferring that
            // until now because cancelling a box in the delayed state is ignored. By waiting until
            // now, we ensure that the box is in the empty state instead and therefore will accept
            // cancellation. We're still running the handler, but this way the handler can check for
            // cancellation requests.
            __weak TWLObjCPromiseBox *box = promise->_box;
            [childResolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
                [box propagateCancel];
            }];
            // Seal the inner promise box now. This way cancellation will propagate if appropriate.
            // Note: We can't just nil out the promise unless we want to add autorelease pools.
            [promise->_box seal];
            // Now we can invoke the original handler.
            handler(resolver);
        };
        
        // Observe the promise now in order to set our operation state
        __weak typeof(self) weakSelf = self;
        [promise tapOnContext:TWLContext.immediate handler:^(id _Nullable value, id _Nullable error) {
            // Regardless of the result, mark ourselves as finished.
            // We can only get resolved if we've been started.
            weakSelf.state = TWLAsyncOperationStateFinished;
        }];
        // If someone requests cancellation of the promise, treat that as asking the operation
        // itself to cancel.
        [childResolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            typeof(self) this = weakSelf;
            if (this
                // -cancel invokes this callback; let's not invoke -cancel again.
                // It should be safe to do so, but it will fire duplicate KVO notices.
                && !this.cancelled)
            {
                [this cancel];
            }
        }];
        // Pipe data from the delayed box to our child promise now. This way if we never actually
        // execute the callback, we'll get informed of cancellation.
        [promise enqueueCallbackWithBox:childPromise->_box willPropagateCancel:YES]; // the propagateCancel happens in the callback
    }
    return self;
}

- (void)dealloc {
    // If we're thrown away without executing, we need to clean up.
    // Since the box is in the delayed state, it won't just cancel automatically.
    [self emptyAndCancel];
}

// We could probably synthesize this, but it's a const ivar past initialization, so we don't need
// the synthesized lock.
- (TWLPromise *)promise {
    return _promise;
}

- (void)cancel {
    // Call super first so .cancelled is true.
    [super cancel];
    // Now request cancellation of the promise.
    [_promise requestCancel];
    // This does mean a KVO observer of the "isCancelled" key can act on the change prior to our
    // promise being requested to cancel, but that should be meaningless; this is only even
    // externally observable if the KVO observer has access to the promise's resolver.
}

- (void)main {
    // Check if our promise has requested to cancel.
    // We're doing this over just testing self.cancelled to handle the super edge case where one
    // thread requests the promise to cancel at the same time as another thread starts the
    // operation. Requesting our promise to cancel places it in the cancelled state prior to setting
    // self.cancelled, which leaves a race where the promise is cancelled but the operation is not.
    // If we were checking self.cancelled we could get into a situation where the handler executes
    // and cannot tell that it was asked to cancel.
    // The opposite is safe, if we cancel the operation and the operation starts before the promise
    // is marked as cancelled, the cancellation will eventually be exposed to the handler, so it can
    // take action accordingly.
    if (_promise->_box.unfencedState == TWLPromiseBoxStateCancelling) {
        [self emptyAndCancel];
    } else {
        [self execute];
    }
}

- (void)execute {
    if ([_box transitionStateTo:TWLPromiseBoxStateEmpty]) {
        TWLResolver *resolver = [[TWLResolver alloc] initWithBox:_box];
        void (^callback)(TWLResolver *) = _callback;
        TWLContext *context = _context;
        _context = nil;
        _callback = nil;
        [context executeIsSynchronous:NO block:^{
            callback(resolver);
        }];
    }
}

- (void)emptyAndCancel {
    if ([_box transitionStateTo:TWLPromiseBoxStateEmpty]) {
        _context = nil;
        _callback = nil;
        [_box resolveOrCancelWithValue:nil error:nil];
    }
}

@end
