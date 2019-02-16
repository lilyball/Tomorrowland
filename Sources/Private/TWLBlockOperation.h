//
//  TWLBlockOperation.h
//  Tomorrowland
//
//  Created by Lily Ballard on 11/22/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A block operation that isn't ready until `-markReady` is invoked.
@interface TWLBlockOperation : NSBlockOperation
/// Marks the block operation as ready (assuming all dependencies are satisfied).
///
/// Calling this multiple times does nothing.
- (void)markReady;
@end

NS_ASSUME_NONNULL_END
