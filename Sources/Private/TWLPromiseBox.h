//
//  TWLPromiseBox.h
//  Tomorrowland
//
//  Created by Kevin Ballard on 12/12/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(int, TWLPromiseBoxState) {
    TWLPromiseBoxStateDelayed,
    TWLPromiseBoxStateEmpty,
    TWLPromiseBoxStateResolving,
    TWLPromiseBoxStateResolved,
    TWLPromiseBoxStateCancelling,
    TWLPromiseBoxStateCancelled
};

/// This is a sentinel value. DO NOT DEREFERENCE.
static void * const _Nonnull TWLLinkedListSwapFailed = (void *)0x1;

@interface TWLPromiseBox : NSObject
@property (atomic, readonly) TWLPromiseBoxState state;
/// Return the state without issuing a fence.
@property (atomic, readonly) TWLPromiseBoxState unfencedState;

@property (atomic, readonly, nullable) void *callbackList;
/// Returns \c YES if we have a non-<tt>NULL</tt> \a callbackList that isn't equal to <tt>TWLLinkedListSwapFailed</tt>.
@property (atomic, readonly) BOOL hasCallbackList;
@property (atomic, readonly, nullable) void *requestCancelLinkedList;

/// The observer count plus the 2 flags <tt>(1 << 63)</tt> for seal and <tt>(1 << 62)</tt> for
/// whether we have any propagating observers.
@property (atomic, readonly) uint64_t flaggedObserverCount;

- (nonnull instancetype)init NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithState:(TWLPromiseBoxState)state NS_DESIGNATED_INITIALIZER;

/// Returns \c YES if the state is transitioned successfully or \c NO if it is not.
///
/// Valid state transitions:
///
/// \li Delayed -> Empty
/// \li Empty -> Resolving
/// \li Empty -> Cancelling
/// \li Empty -> Cancelled
/// \li Resolving -> Resolved
/// \li Cancelling -> Resolving
/// \li Cancelling -> Cancelled
///
/// Transitioning to the current state is considered a failure and \c NO is returned.
- (BOOL)transitionStateTo:(TWLPromiseBoxState)state __attribute__((warn_unused_result));

/// Atomically swaps the callback linked list pointer.
///
/// If the existing linked list pointer is \c TWLLinkedListSwapFailed no swap is performed.
///
/// \param node The node to push onto the head of the list.
/// \param linkBlock A block that is invoked with the previous head prior to pushing the new node
/// on. This block should modify the new node to link to the previous head. If multiple threads are
/// swapping the list at the same time, this block may be invoked multiple times.
/// \returns The old value of the linked list, or \c TWLLinkedListSwapFailed if the swap failed.
- (nullable void *)swapCallbackLinkedListWith:(nullable void *)node linkBlock:(nullable void (NS_NOESCAPE ^)(void * _Nullable nextNode))linkBlock __attribute__((warn_unused_result));
/// Atomically swaps the request cancel linked list pointer.
///
/// If the existing linked list pointer is \c TWLLinkedListSwapFailed no swap is performed.
///
/// \param node The node to push onto the head of the list.
/// \param linkBlock A block that is invoked with the previous head prior to pushing the new node
/// on. This block should modify the new node to link to the previous head. If multiple threads are
/// swapping the list at the same time, this block may be invoked multiple times.
/// \returns The old value of the linked list, or \c TWLLinkedListSwapFailed if the swap failed.
- (nullable void *)swapRequestCancelLinkedListWith:(nullable void *)node linkBlock:(nullable void (NS_NOESCAPE ^)(void * _Nullable nextNode))linkBlock __attribute__((warn_unused_result));

- (void)incrementObserverCount;
/// \returns \c YES if this drops the count to zero.
- (BOOL)decrementObserverCount;
/// \returns \c YES if this drops the count to zero.
- (BOOL)sealObserverCount;
@end
