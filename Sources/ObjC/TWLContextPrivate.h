//
//  TWLContextPrivate.h
//  Tomorrowland
//
//  Created by Kevin Ballard on 12/30/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface TWLContext ()
@property (atomic, readonly) BOOL isImmediate;
- (void)executeBlock:(dispatch_block_t)block;
- (nullable dispatch_queue_t)getQueue;
@end

NS_ASSUME_NONNULL_END
