//
//  TWLBlockThread.m
//  TomorrowlandTests
//
//  Created by Lily Ballard on 7/3/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLBlockThread.h"

@implementation TWLBlockThread

- (instancetype)initWithBlock:(void (^)(void))block {
    if ((self = [super init])) {
        _block = block;
    }
    return self;
}

- (void)main {
    _block();
}

@end
