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

@interface TWLPromise<ValueType,ErrorType> () {
@public
    TWLPromiseBox * _Nonnull _box;
}
- (instancetype)initDelayed NS_DESIGNATED_INITIALIZER;

- (void)enqueueCallback:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))callback;
@end

@interface TWLResolver<ValueType,ErrorType> ()
- (nonnull instancetype)initWithPromise:(nonnull TWLPromise<ValueType,ErrorType> *)promise NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
