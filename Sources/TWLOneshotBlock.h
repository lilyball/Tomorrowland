//
//  TWLOneshotBlock.h
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

#import <Foundation/Foundation.h>

/// A wrapper around a block that can only be invoked once.
@interface TWLOneshotBlock : NSObject
- (nonnull instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)initWithBlock:(nonnull void (^)(void))block NS_DESIGNATED_INITIALIZER;
- (void)invoke;
@end
