//
//  TWLDelayedPromise.h
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

#import <Foundation/Foundation.h>

@class TWLContext;
@class TWLResolver<ValueType,ErrorType>;
@class TWLPromise<ValueType,ErrorType>;

NS_ASSUME_NONNULL_BEGIN

/// \c TWLDelayedPromise is like a \c TWLPromise but it doesn't invoke its callback until the
/// \c .promise variable is accessed.
///
/// The purpose of \c TWLDelayedPromise is to allow functions to return calculations that aren't
/// performed if they're not needed.
///
/// Example:
///
///\code
///std::pair<NSString*,TWLDelayedPromise<UIImage*,NSError*>* getUserInfo() {
///    …
///}
///
///auto userInfo = getUserInfo();
///nameLabel.text = userInfo.first;
///__weak typeof(self) weakSelf = self;
///[userInfo.second.promise then:^(UIImage *image){
///    weakSelf.imageView.image = image;
///}];
///\endcode
@interface TWLDelayedPromise<ValueType,ErrorType> : NSObject

/// Returns a \c TWLPromise that asynchronously contains the value of the computation.
///
/// If the computation has not yet started, this is equivalent to creating a \c TWLPromise with the
/// same \c TWLContext and handler. If the computation has started, this returns the same
/// \c TWLPromise as the first time it was accessed.
@property (atomic, readonly) TWLPromise<ValueType,ErrorType> *promise;

/// Returns a new \c TWLDelayedPromise that can be resolved with the given handler.
///
/// The \c TWLDelayedPromise won't execute the block until the \c .promise property is accessed.
///
/// \param context The context to execute the handler on.
/// \param handler A block that may be executed in order to fulfill the promise.
/// \returns A \c TWLDelayedPromise.
+ (instancetype)newOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))handler NS_SWIFT_UNAVAILABLE("use init(on:_:)");

/// Returns a new \c TWLDelayedPromise that can be resolved with the given handler.
///
/// The \c TWLDelayedPromise won't execute the block until the \c .promise property is accessed.
///
/// \param context The context to execute the handler on.
/// \param handler A block that may be executed in order to fulfill the promise.
- (instancetype)initOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))handler NS_SWIFT_NAME(init(on:_:)) NS_DESIGNATED_INITIALIZER;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
