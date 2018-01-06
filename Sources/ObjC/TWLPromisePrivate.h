//
//  TWLPromisePrivate.h
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/5/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Tomorrowland/TWLPromise.h>

@class TWLPromiseBox;

NS_ASSUME_NONNULL_BEGIN

@interface TWLPromise () {
@public
    TWLPromiseBox * _Nonnull _box;
}
- (instancetype)initDelayed NS_DESIGNATED_INITIALIZER;
@end

@interface TWLResolver ()
- (nonnull instancetype)initWithPromise:(nonnull TWLPromise<id,id> *)promise NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
