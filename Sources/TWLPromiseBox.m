//
//  TWLPromiseBox.m
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

#import "TWLPromiseBox.h"
#import <stdatomic.h>

@implementation TWLPromiseBox {
    atomic_int _state;
    atomic_uintptr_t _callbackList;
    atomic_uintptr_t _requestCancelLinkedList;
}

- (instancetype)init {
    if ((self = [super init])) {
        atomic_init(&_state, TWLPromiseBoxStateEmpty);
        atomic_init(&_callbackList, 0);
        atomic_init(&_requestCancelLinkedList, 0);
    }
    return self;
}

- (instancetype)initWithState:(TWLPromiseBoxState)state {
    if ((self = [super init])) {
        atomic_init(&_state, state);
        switch (state) {
            case TWLPromiseBoxStateEmpty:
            case TWLPromiseBoxStateCancelling:
            case TWLPromiseBoxStateResolving:
                atomic_init(&_callbackList, 0);
                atomic_init(&_requestCancelLinkedList, 0);
                break;
            case TWLPromiseBoxStateResolved:
            case TWLPromiseBoxStateCancelled:
                atomic_init(&_callbackList, (uintptr_t)TWLLinkedListSwapFailed);
                atomic_init(&_requestCancelLinkedList, (uintptr_t)TWLLinkedListSwapFailed);
                break;
        }
    }
    return self;
}

- (TWLPromiseBoxState)state {
    TWLPromiseBoxState state = (TWLPromiseBoxState)atomic_load_explicit(&_state, memory_order_relaxed);
    if (state == TWLPromiseBoxStateResolved) {
        // if we're fulfilled, our client is about to read the value, so issue a fence
        atomic_thread_fence(memory_order_acquire); // forms edge with the cmpxchg in -transitionStateTo:
    }
    return state;
}

- (TWLPromiseBoxState)unfencedState {
    return (TWLPromiseBoxState)atomic_load_explicit(&_state, memory_order_relaxed);
}

- (void *)callbackList {
    void *list = (void *)atomic_load_explicit(&_callbackList, memory_order_relaxed);
    if (list != TWLLinkedListSwapFailed) {
        atomic_thread_fence(memory_order_acquire);
    }
    return list;
}

- (void *)requestCancelLinkedList {
    void *list = (void *)atomic_load_explicit(&_requestCancelLinkedList, memory_order_relaxed);
    if (list != TWLLinkedListSwapFailed) {
        atomic_thread_fence(memory_order_acquire);
    }
    return list;
}

- (BOOL)transitionStateTo:(TWLPromiseBoxState)state {
    memory_order successOrder = memory_order_relaxed;
    if (state == TWLPromiseBoxStateResolved) {
        successOrder = memory_order_release; // forms edge with the fence in -state
    }
    TWLPromiseBoxState oldState = (TWLPromiseBoxState)atomic_load_explicit(&_state, memory_order_relaxed);
    while (1) {
        switch (oldState) {
            case TWLPromiseBoxStateEmpty:
                if (state != TWLPromiseBoxStateResolving &&
                    state != TWLPromiseBoxStateCancelling &&
                    state != TWLPromiseBoxStateCancelled) return NO;
                break;
            case TWLPromiseBoxStateResolving:
                if (state != TWLPromiseBoxStateResolved) return NO;
                break;
            case TWLPromiseBoxStateResolved:
                return NO;
            case TWLPromiseBoxStateCancelling:
                if (state != TWLPromiseBoxStateResolving && state != TWLPromiseBoxStateCancelled) return NO;
                break;
            case TWLPromiseBoxStateCancelled:
                return NO;
        }
        if (atomic_compare_exchange_strong_explicit(&_state, &oldState, state, successOrder, memory_order_relaxed)) return YES;
    }
}

- (void *)swapCallbackLinkedListWith:(void *)node linkBlock:(nullable void (^)(void * _Nullable))linkBlock {
    return swapLinkedList(&_callbackList, node, linkBlock);
}

- (void *)swapRequestCancelLinkedListWith:(void *)node linkBlock:(nullable void (^)(void * _Nullable))linkBlock {
    return swapLinkedList(&_requestCancelLinkedList, node, linkBlock);
}

static void * _Nullable swapLinkedList(atomic_uintptr_t * _Nonnull list, void * _Nullable node, void (^ _Nullable linkBlock)(void * _Nullable)) {
    memory_order successMemoryOrder = memory_order_release;
    if (node == TWLLinkedListSwapFailed) {
        successMemoryOrder = memory_order_acq_rel;
    }
    uintptr_t oldValue = atomic_load_explicit(list, memory_order_relaxed);
    while (1) {
        if (oldValue == (uintptr_t)TWLLinkedListSwapFailed) {
            atomic_thread_fence(memory_order_acquire);
            return (void *)oldValue;
        }
        if (linkBlock) linkBlock((void *)oldValue);
        if (atomic_compare_exchange_weak_explicit(list, &oldValue, (uintptr_t)node, successMemoryOrder, memory_order_relaxed)) {
            return (void *)oldValue;
        }
    }
}

- (void)issueDeinitFence {
    atomic_thread_fence(memory_order_acquire);
}

@end
