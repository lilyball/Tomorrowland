//
//  TWLContext.h
//  Tomorrowland
//
//  Created by Lily Ballard on 12/30/17.
//  Copyright © 2017 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The context in which a \c TWLPromise body or callback is evaluated.
///
/// Most of these contexts correspond with Dispatch QoS classes.
@interface TWLContext : NSObject
/// Execute synchronously.
///
/// \warning This is rarely what you want and great care should be taken when using it.
@property (class, readonly) TWLContext *immediate;

/// Execute on the main queue.
///
/// \note Chained callbacks on the \c .main context guarantee that they all execute within the same
/// run loop pass. This means UI manipulations in chained callbacks on \c .main will all occur
/// within the same CoreAnimation transaction. The only exception is if a callback returns an
/// unresolved nested promise, as the subsequent callbacks must wait for that promise to resolve
/// first.
@property (class, readonly) TWLContext *main;

/// Execute on a dispatch queue with the \c QOS_CLASS_BACKGROUND QoS.
@property (class, readonly) TWLContext *background;
/// Execute on a dispatch queue with the \c QOS_CLASS_UTILITY QoS.
@property (class, readonly) TWLContext *utility;
/// Execute on a dispatch queue with the \c QOS_CLASS_DEFAULT QoS.
@property (class, readonly) TWLContext *defaultQoS;
/// Execute on a dispatch queue with the \c QOS_CLASS_USER_INITIATED QoS.
@property (class, readonly) TWLContext *userInitiated;
/// Execute on a dispatch queue with the \c QOS_CLASS_USER_INTERACTIVE QoS.
@property (class, readonly) TWLContext *userInteractive;

/// Execute on the specified dispatch queue.
+ (TWLContext *)queue:(dispatch_queue_t)queue;
/// Execute on the specified operation queue.
+ (TWLContext *)operationQueue:(NSOperationQueue *)operationQueue;

/// Execute synchronously if the promise is already resolved, otherwise use another context.
///
/// This is a convenience for a pattern where you check a promise's \c result to see if it's already
/// resolved and only attach a callback if it hasn't resolved yet. Passing this context to a
/// callback will execute it synchronously before returning to the caller if and only if the promise
/// has already resolved.
///
/// If this is passed to a promise initializer it acts like \c .immediate. If passed to a
/// \c TWLDelayedPromise initializer it acts like the given context.
+ (TWLContext *)nowOrContext:(TWLContext *)context;

/// Returns \c .main when accessed from the main thread, otherwise <tt>.defaultQoS</tt>.
@property (class, readonly) TWLContext *automatic;

/// Returns whether a \c +nowOrContext: context is executing synchronously.
///
/// When accessed from within a callback registered with \c +nowOrContext: this returns \c YES if
/// the callback is executing synchronously or \c NO if it's executing on the wrapped context. When
/// accessed from within a callback (including <tt>[TWLPromise newOnContext:withBlock:]</tt>
/// registered with \c .immediate this returns \c YES if and only if the callback is executing
/// synchronously and is nested within a \c +nowOrContext: context that is executing synchronously.
/// When accessed from any other scenario this always returns \c NO.
///
/// \note The behavior of \c .immediate is intended to allow <tt>[TWLPromise
/// newOnContext:withBlock:]</tt> registered with \c .immediate to query the synchronous state of
/// its surrounding scope.
///
/// \note This flag will return \c NO when executed from within a dispatch sync to the main queue
/// nested inside a \c +nowOrContext: callback, or any similar construct that blocks the current
/// thread and runs code on another thread.
@property (class, readonly) BOOL isExecutingNow;

/// Returns the \c TWLContext that corresponds to a given Dispatch QoS class.
///
/// If the given QoS is \c QOS_CLASS_UNSPECIFIED then \c QOS_CLASS_DEFAULT is assumed.
+ (TWLContext *)contextForQoS:(dispatch_qos_class_t)qos;

- (instancetype)initWithQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithOperationQueue:(NSOperationQueue *)operationQueue NS_DESIGNATED_INITIALIZER;
- (instancetype)initAsNowOrContext:(TWLContext *)context NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
