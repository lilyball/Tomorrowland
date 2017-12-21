//
//  PMSOneshotBlock.h
//  Promissory
//
//  Created by Ballard, Kevin on 12/20/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

#import <Foundation/Foundation.h>

/// A wrapper around a block that can only be invoked once.
@interface PMSOneshotBlock : NSObject
- (nonnull instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)initWithBlock:(nonnull void (^)(void))block NS_DESIGNATED_INITIALIZER;
- (void)invoke;
@end
