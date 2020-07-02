//
//  BlockThread.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 7/1/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Foundation

// Thread.init(block:) doesn't exist on our minimum deployment target, so we have to do it by hand.
final class BlockThread: Thread {
    let block: () -> Void
    init(block: @escaping () -> Void) {
        self.block = block
    }
    override func main() {
        block()
    }
}
