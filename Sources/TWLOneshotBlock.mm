//
//  TWLOneshotBlock.m
//  Tomorrowland
//
//  Created by Ballard, Kevin on 12/20/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLOneshotBlock.h"
#include <atomic>

// NB: Using C++ here because the C++ atomic_flag type has a trivial default constructor that leaves
// the value in an unspecified state, which we can then clear. In C, an uninitialized atomic_flag
// has an undefined value (rather than unspecified), and we can't initialize it as an ivar.

@implementation TWLOneshotBlock {
    void (^ _Nullable _block)(void);
    std::atomic_flag _flag;
}

- (instancetype)initWithBlock:(void (^)(void))block {
    if ((self = [super init])) {
        _block = [block copy];
        std::atomic_flag_clear_explicit(&_flag, std::memory_order_relaxed);
    }
    return self;
}

- (void)invoke {
    if (!std::atomic_flag_test_and_set_explicit(&_flag, std::memory_order_relaxed)) {
        _block();
        _block = nil;
    }
}

@end
