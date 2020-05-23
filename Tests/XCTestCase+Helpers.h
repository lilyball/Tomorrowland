//
//  XCTestCase+Helpers.h
//  Tomorrowland
//
//  Created by Lily Ballard on 5/22/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TomorrowlandTests-Swift.h"

/// Asserts that wer'e running on the test queue identified by the given identifier.
/// The identifier is a \c TestQueueIdentifier case or the numeric equivalent.
#define AssertOnTestQueue(ident) XCTAssertEqualObjects(TestQueue.currentQueue, [TestQueue queueForIdentifier:ident], @"current queue")
