//
//  TWLContext.h
//  Tomorrowland
//
//  Created by Kevin Ballard on 12/30/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
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

/// Returns \c .main when accessed from the main thread, otherwise <tt>.defaultQoS</tt>.
@property (class, readonly) TWLContext *automatic;

/// Returns the \c TWLContext that corresponds to a given Dispatch QoS class.
///
/// If the given QoS is \c QOS_CLASS_UNSPECIFIED then \c QOS_CLASS_DEFAULT is assumed.
+ (TWLContext *)contextForQoS:(dispatch_qos_class_t)qos;

- (instancetype)initWithQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithOperationQueue:(NSOperationQueue *)operationQueue NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
