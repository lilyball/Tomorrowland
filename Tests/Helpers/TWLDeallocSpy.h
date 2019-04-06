//
//  TWLDeallocSpy.h
//  TomorrowlandTests
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A class that runs a given block when it deallocs.
@interface TWLDeallocSpy : NSObject
+ (instancetype)newWithHandler:(nonnull void (^)(void))handler;
- (instancetype)initWithHandler:(nonnull void (^)(void))handler NS_DESIGNATED_INITIALIZER;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
