//
//  TWLPromiseInvalidationTokenBox.h
//  Tomorrowland
//
//  Created by Lily Ballard on 12/18/17.
//  Copyright © 2017 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>

@interface TWLPromiseInvalidationTokenBox : NSObject
/// Returns the callback linked list pointer.
///
/// \note The callback linked list pointer initially holds a tagged integer. The tag is the low bit
/// of the pointer.
@property (atomic, readonly, nonnull) void *callbackLinkedList;

/// Pushes a new node onto the callback linked list.
///
/// \note The callback linked list pointer initially holds a tagged integer. The tag is the low bit
/// of the pointer. This can be observed in the pointer given to \c linkBlock.
///
/// \param node The node to push onto the head of the list.
/// \param linkBlock A block that is invoked with the previous head prior to pushing the new node
/// on. This block should modify the new node to link to the previous head. If multiple threads are
/// swapping the list at the same time, this block may be invoked multiple times.
- (void)pushNodeOntoCallbackLinkedList:(nonnull void *)node linkBlock:(nonnull void (NS_NOESCAPE ^)(void * _Nonnull nextNode))linkBlock;

/// Resets the callback linked list pointer to the integral value returned by the given block.
///
/// The returned value is adjusted using <code>(x << 1) | 1</code> to turn it into a tagged integer.
///
/// \param block A block that is called with the old value of the list to return the new value. This
///              block may be invoked multiple times if the list changes concurrently.
/// \returns The old value of the linked list.
- (nonnull void *)resetCallbackLinkedListUsing:(nonnull NSUInteger (NS_NOESCAPE ^)(void * _Nonnull))block __attribute__((warn_unused_result));

@end
