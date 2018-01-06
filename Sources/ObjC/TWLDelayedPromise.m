//
//  TWLDelayedPromise.m
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/5/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//

#import "TWLDelayedPromise.h"
#import "TWLPromisePrivate.h"
#import "TWLPromiseBox.h"
#import "TWLContextPrivate.h"

@implementation TWLDelayedPromise {
    TWLContext * _Nullable _context;
    void (^ _Nullable _callback)(TWLResolver * _Nonnull);
    TWLPromise * _Nonnull _promise;
}

+ (instancetype)newOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<id,id> * _Nonnull))handler {
    return [[self alloc] initOnContext:context handler:handler];
}

- (instancetype)initOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<id,id> * _Nonnull))handler {
    if ((self = [super init])) {
        _context = context;
        _callback = [handler copy];
        _promise = [[TWLPromise alloc] initDelayed];
    } return self;
}

- (TWLPromise *)promise {
    if ([_promise->_box transitionStateTo:TWLPromiseBoxStateEmpty]) {
        TWLResolver *resolver = [[TWLResolver alloc] initWithPromise:_promise];
        void (^callback)(TWLResolver *) = _callback;
        TWLContext *context = _context;
        _context = nil;
        _callback = nil;
        [context executeBlock:^{
            callback(resolver);
        }];
    }
    return _promise;
}

@end
