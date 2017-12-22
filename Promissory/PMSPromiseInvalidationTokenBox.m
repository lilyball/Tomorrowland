//
//  PMSPromiseInvalidationTokenBox.m
//  Promissory
//
//  Created by Kevin Ballard on 12/18/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "PMSPromiseInvalidationTokenBox.h"
#import <stdatomic.h>

@implementation PMSPromiseInvalidationTokenBox {
    atomic_uint_fast64_t _generation;
}

- (instancetype)init {
    if ((self = [super init])) {
        atomic_init(&_generation, 0);
    }
    return self;
}

- (uint64_t)generation {
    return (uint64_t)atomic_load_explicit(&_generation, memory_order_relaxed);
}

- (uint64_t)incrementGeneration {
    return (uint64_t)atomic_fetch_add_explicit(&_generation, 1, memory_order_relaxed) + 1;
}

@end
