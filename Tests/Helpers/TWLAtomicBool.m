//
//  TWLAtomicBool.m
//  Tomorrowland
//
//  Created by Lily Ballard on 4/5/19.
//  Copyright © 2019 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLAtomicBool.h"
#import "stdatomic.h"

@implementation TWLAtomicBool {
    atomic_bool _value;
#if ATOMIC_BOOL_LOCK_FREE != 2
#warning Atomic bool may not be lock-free; what kind of architecture are you compiling on?
#endif
}

- (instancetype)init {
    return [self initWithValue:NO];
}

- (instancetype)initWithValue:(BOOL)value {
    if ((self = [super init])) {
        atomic_init(&_value, false);
    }
    return self;
}

// Clang should be able to synthesize an atomic property for us.
// But just to be certain it's got the semantics we want, we'll do it manually.
- (BOOL)value {
    return (BOOL)atomic_load_explicit(&_value, memory_order_relaxed);
}

- (void)setValue:(BOOL)value {
    atomic_store_explicit(&_value, (_Bool)value, memory_order_relaxed);
}

@end
