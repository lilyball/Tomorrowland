//
//  Compatibility.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 12/28/17.
//  Copyright © 2017 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

// Swift 4.0 Compatibility

#if swift(>=4.1)
#else
    internal extension UnsafeMutablePointer {
        func initialize(repeating value: Pointee, count: Int) {
            initialize(to: value, count: count)
        }
        
        func deallocate() {
            deallocate(capacity: 1)
        }
    }
#endif
