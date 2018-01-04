//
//  TWLContextPrivate.h
//  Tomorrowland
//
//  Created by Kevin Ballard on 12/30/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

#import "TWLContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface TWLContext ()
@property (atomic, readonly) BOOL isImmediate;
- (void)executeBlock:(dispatch_block_t)block;
- (dispatch_queue_t)getQueue;
@end

NS_ASSUME_NONNULL_END
