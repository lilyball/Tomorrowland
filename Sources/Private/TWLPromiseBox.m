//
//  TWLPromiseBox.m
//  Tomorrowland
//
//  Created by Lily Ballard on 12/12/17.
//  Copyright © 2017 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLPromiseBox.h"
#import <stdatomic.h>

typedef NS_OPTIONS(uint64_t, ObserveCountFlag) {
    ObserverCountFlagUnsealed = (uint64_t)1 << 63,
    ObserverCountFlagUnobserved = (uint64_t)1 << 62,
    ObserverCountFlagMask = (uint64_t)3 << 62
};

@implementation TWLPromiseBox {
    atomic_int _state;
    atomic_uintptr_t _callbackList;
    atomic_uintptr_t _requestCancelLinkedList;
    atomic_uint_fast64_t _observerCount;
}

- (instancetype)init {
    if ((self = [super init])) {
        atomic_init(&_state, TWLPromiseBoxStateEmpty);
        atomic_init(&_callbackList, 0);
        atomic_init(&_requestCancelLinkedList, 0);
        atomic_init(&_observerCount, ObserverCountFlagUnsealed | ObserverCountFlagUnobserved);
    }
    return self;
}

- (instancetype)initWithState:(TWLPromiseBoxState)state {
    if ((self = [super init])) {
        atomic_init(&_state, state);
        switch (state) {
            case TWLPromiseBoxStateDelayed:
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
        atomic_init(&_observerCount, ObserverCountFlagUnsealed | ObserverCountFlagUnobserved);
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

- (BOOL)hasCallbackList {
    void *list = (void *)atomic_load_explicit(&_callbackList, memory_order_relaxed);
    return list != NULL && list != TWLLinkedListSwapFailed;
}

- (void *)requestCancelLinkedList {
    void *list = (void *)atomic_load_explicit(&_requestCancelLinkedList, memory_order_relaxed);
    if (list != TWLLinkedListSwapFailed) {
        atomic_thread_fence(memory_order_acquire);
    }
    return list;
}

- (uint64_t)flaggedObserverCount {
    return (uint64_t)atomic_load_explicit(&_observerCount, memory_order_relaxed);
}

- (BOOL)transitionStateTo:(TWLPromiseBoxState)state {
    memory_order successOrder = memory_order_relaxed;
    if (state == TWLPromiseBoxStateResolved) {
        successOrder = memory_order_release; // forms edge with the fence in -state
    }
    TWLPromiseBoxState oldState = (TWLPromiseBoxState)atomic_load_explicit(&_state, memory_order_relaxed);
    while (1) {
        switch (oldState) {
            case TWLPromiseBoxStateDelayed:
                if (state != TWLPromiseBoxStateEmpty) return NO;
                break;
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

- (void *)swapCallbackLinkedListWith:(void *)node linkBlock:(nullable void (NS_NOESCAPE ^)(void * _Nullable))linkBlock {
    return swapLinkedList(&_callbackList, node, linkBlock);
}

- (void *)swapRequestCancelLinkedListWith:(void *)node linkBlock:(nullable void (NS_NOESCAPE ^)(void * _Nullable))linkBlock {
    return swapLinkedList(&_requestCancelLinkedList, node, linkBlock);
}

static void * _Nullable swapLinkedList(atomic_uintptr_t * _Nonnull list, void * _Nullable node, void (NS_NOESCAPE ^ _Nullable linkBlock)(void * _Nullable)) {
    // NB: We don't have to worry about ordering wrt. the retain count operations, because the Obj-C
    // runtime decrements the retain count with a release operation arleady, and issues a full
    // memory barrier prior to -dealloc.
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

- (void)incrementObserverCount {
    uint64_t count = (uint64_t)atomic_load_explicit(&_observerCount, memory_order_relaxed);
    while (1) {
        uint64_t newCount = (count & ~ObserverCountFlagUnobserved) + 1;
        if (atomic_compare_exchange_weak_explicit(&_observerCount, &count, newCount, memory_order_relaxed, memory_order_relaxed)) {
            break;
        }
    }
}

- (BOOL)decrementObserverCount {
    uint64_t oldCount = atomic_fetch_sub_explicit(&_observerCount, 1, memory_order_relaxed);
    NSAssert((oldCount & ~ObserverCountFlagMask) != 0, @"observer count underflow");
    return oldCount == 1;
}

- (BOOL)sealObserverCount {
    uint64_t count = (uint64_t)atomic_load_explicit(&_observerCount, memory_order_relaxed);
    while (1) {
        uint64_t newCount = count & ~ObserverCountFlagUnsealed;
        if (newCount == count // we already sealed the box
            || atomic_compare_exchange_weak_explicit(&_observerCount, &count, newCount, memory_order_relaxed, memory_order_relaxed))
        {
            return newCount == 0;
        }
    }
}

@end
