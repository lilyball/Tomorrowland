//
//  TWLBlockThread.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// -[NSThread initWithBlock:] doesn't exist on our minimum deployment target, so we have to do it by hand.
NS_SWIFT_NAME(BlockThread)
@interface TWLBlockThread : NSThread
@property (nonatomic, readonly) void (^block)(void);

- (instancetype)initWithBlock:(void (^)(void))block NS_DESIGNATED_INITIALIZER;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
