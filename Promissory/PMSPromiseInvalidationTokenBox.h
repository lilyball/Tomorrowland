//
//  PMSPromiseInvalidationTokenBox.h
//  Promissory
//
//  Created by Kevin Ballard on 12/18/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PMSPromiseInvalidationTokenBox : NSObject
@property (atomic, readonly) uint64_t generation;
/// Increments the generation and returns the new value.
- (uint64_t)incrementGeneration;
@end
