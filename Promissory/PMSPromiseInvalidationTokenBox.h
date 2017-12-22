//
//  PMSPromiseInvalidationTokenBox.h
//  Promissory
//
//  Created by Kevin Ballard on 12/18/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>

@interface PMSPromiseInvalidationTokenBox : NSObject
@property (atomic, readonly) uint64_t generation;
/// Increments the generation and returns the new value.
- (uint64_t)incrementGeneration;
@end
