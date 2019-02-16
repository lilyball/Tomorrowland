//
//  TWLDelayedPromise.m
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
        TWLResolver *resolver = [[TWLResolver alloc] initWithBox:_promise->_box];
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
