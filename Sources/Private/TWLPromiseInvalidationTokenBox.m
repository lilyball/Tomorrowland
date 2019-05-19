//
//  TWLPromiseInvalidationTokenBox.m
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

#import "TWLPromiseInvalidationTokenBox.h"
#import <stdatomic.h>

@implementation TWLPromiseInvalidationTokenBox {
    atomic_uintptr_t _callbackLinkedList;
    atomic_uintptr_t _tokenChainLinkedList;
}

- (instancetype)init {
    if ((self = [super init])) {
        atomic_init(&_callbackLinkedList, 1);
        atomic_init(&_tokenChainLinkedList, 0);
    }
    return self;
}

- (void *)callbackLinkedList {
    uintptr_t list = atomic_load_explicit(&_callbackLinkedList, memory_order_relaxed);
    if ((list & 1) == 0) {
        // it's an actual node
        atomic_thread_fence(memory_order_acquire);
    }
    return (void *)list;
}

- (void *)tokenChainLinkedList {
    uintptr_t list = atomic_load_explicit(&_tokenChainLinkedList, memory_order_relaxed);
    if (list != 0) {
        // it's an actual node
        atomic_thread_fence(memory_order_acquire);
    }
    return (void *)list;
}

- (void)pushNodeOntoCallbackLinkedList:(void *)node linkBlock:(void (NS_NOESCAPE ^)(void * _Nonnull))linkBlock {
    uintptr_t oldValue = atomic_load_explicit(&_callbackLinkedList, memory_order_acquire);
    while (1) {
        linkBlock((void *)oldValue);
        if (atomic_compare_exchange_weak_explicit(&_callbackLinkedList, &oldValue, (uintptr_t)node, memory_order_release, memory_order_acquire)) {
            return;
        }
    }
}

- (nonnull void *)resetCallbackLinkedListUsing:(nonnull NSUInteger (NS_NOESCAPE ^)(void * _Nonnull))block {
    uintptr_t oldValue = atomic_load_explicit(&_callbackLinkedList, memory_order_acquire);
    while (1) {
        NSUInteger newValue = block((void *)oldValue);
        uintptr_t taggedValue = ((uintptr_t)newValue << 1) | 1;
        if (atomic_compare_exchange_weak_explicit(&_callbackLinkedList, &oldValue, taggedValue, memory_order_relaxed, memory_order_relaxed)) {
            if ((oldValue & 1) == 0) {
                // it's an actual node
                atomic_thread_fence(memory_order_acquire);
            }
            return (void *)oldValue;
        }
    }
}

- (void)pushNodeOntoTokenChainLinkedList:(void *)node linkBlock:(void (NS_NOESCAPE ^)(void * _Nonnull))linkBlock {
    uintptr_t oldValue = atomic_load_explicit(&_tokenChainLinkedList, memory_order_acquire);
    while (1) {
        if (oldValue != 0) {
            linkBlock((void *)oldValue);
        }
        if (atomic_compare_exchange_weak_explicit(&_tokenChainLinkedList, &oldValue, (uintptr_t)node, memory_order_release, memory_order_acquire)) {
            return;
        }
    }
}

@end
