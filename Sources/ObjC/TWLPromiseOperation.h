//
//  TWLPromiseOperation.h
//  Tomorrowland
//
//  Created by Lily Ballard on 8/19/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>
#import <Tomorrowland/TWLAsyncOperation.h>

@class TWLContext;
@class TWLPromise<ValueType,ErrorType>;
@class TWLResolver<ValueType,ErrorType>;

NS_ASSUME_NONNULL_BEGIN

/// An \c NSOperation subclass that wraps a promise.
///
/// \c TWLPromiseOperation is an \c NSOperation subclass that wraps a promise. It doesn't invoke its
/// callback until the operation has been started, and the operation is marked as finished when the
/// promise is resolved.
///
/// The associated promise can be retrieved at any time with the \c .promise property, even before
/// the operation has started. Requesting cancellation of the promise will cancel the operation, but
/// if the operation has already started it's up to the provided handler to handle the cancellation
/// request.
///
/// \note Cancelling the operation or the associated promise before the operation has started will
/// always cancel the promise without executing the provided handler, regardless of whether the
/// handler itself supports cancellation.
NS_SWIFT_NAME(ObjCPromiseOperation)
@interface TWLPromiseOperation<__covariant ValueType, __covariant ErrorType> : TWLAsyncOperation

@property (atomic, readonly) TWLPromise<ValueType,ErrorType> *promise;

+ (instancetype)newOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))handler NS_SWIFT_UNAVAILABLE("use init(on:_:)");
- (instancetype)initOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))handler NS_SWIFT_NAME(init(on:_:)) NS_DESIGNATED_INITIALIZER;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (void)main NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
