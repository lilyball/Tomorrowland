//
//  TWLPromisePrivate.h
//  Tomorrowland
//
//  Created by Lily Ballard on 1/5/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Tomorrowland/TWLPromise.h>
#import "TWLPromiseBox.h"
#if __cplusplus
#include <tuple>
#endif

@class TWLPromiseBox;

NS_ASSUME_NONNULL_BEGIN

@interface TWLObjCPromiseBox<ValueType,ErrorType> : TWLPromiseBox <TWLCancellable>
#if __cplusplus
@property (atomic, readonly) std::tuple<BOOL,ValueType _Nullable,ErrorType _Nullable> result;
#endif
- (BOOL)getValue:(ValueType __strong _Nullable * _Nullable)outValue error:(ErrorType __strong _Nullable * _Nullable)outError;
- (void)propagateCancel;

@end

@interface TWLPromise<ValueType,ErrorType> () {
@public
    TWLObjCPromiseBox<ValueType,ErrorType> * _Nonnull _box;
}
- (instancetype)initDelayed NS_DESIGNATED_INITIALIZER;

- (void)enqueueCallbackWithoutOneshot:(void (^)(ValueType _Nullable value, ErrorType _Nullable error, BOOL isSynchronous))callback
                  willPropagateCancel:(BOOL)willPropagateCancel;
- (void)enqueueCallbackWithBox:(TWLObjCPromiseBox *)box willPropagateCancel:(BOOL)willPropagateCancel;
@end

@interface TWLResolver<ValueType,ErrorType> ()
- (nonnull instancetype)initWithBox:(nonnull TWLObjCPromiseBox<ValueType,ErrorType> *)box NS_DESIGNATED_INITIALIZER;
@end

#if __cplusplus
namespace {
template<class ValueType, class ErrorType, class OneshotType>
inline void enqueueCallback(TWLPromise<ValueType, ErrorType> * _Nonnull promise, BOOL willPropagateCancel,
                            OneshotType value, void (^ _Nonnull callback)(ValueType _Nullable value, ErrorType _Nullable error,
                                                                          OneshotType (^ _Nonnull oneshot)(void), BOOL isSynchronous))
{
    __block OneshotType oneshotValue = value;
    OneshotType (^oneshot)(void) = ^{
        OneshotType value = oneshotValue;
        oneshotValue = nil;
        return value;
    };
    [promise enqueueCallbackWithoutOneshot:^(ValueType _Nullable value, ErrorType _Nullable error, BOOL isSynchronous) {
        callback(value, error, oneshot, isSynchronous);
    } willPropagateCancel:willPropagateCancel];
}
}
#endif

NS_ASSUME_NONNULL_END
