//
//  TWLBlockOperation.m
//  Tomorrowland
//
//  Created by Lily Ballard on 11/22/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLBlockOperation.h"
#import <stdatomic.h>

@implementation TWLBlockOperation {
    atomic_bool _markedReady;
}

- (instancetype)init {
    if ((self = [super init])) {
        atomic_init(&_markedReady, false);
    }
    return self;
}

- (BOOL)isReady {
    return [super isReady] && atomic_load_explicit(&_markedReady, memory_order_relaxed);
}

- (void)markReady {
    [self willChangeValueForKey:@"isReady"];
    atomic_store_explicit(&_markedReady, true, memory_order_relaxed);
    [self didChangeValueForKey:@"isReady"];
}
@end
