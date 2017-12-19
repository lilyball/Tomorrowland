//
//  PMSPromiseBox.m
//  Promissory
//
//  Created by Kevin Ballard on 12/12/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

#import "PMSPromiseBox.h"
#import <stdatomic.h>

@implementation PMSPromiseBox {
    atomic_int _state;
    atomic_uintptr_t _callbackList;
    atomic_uintptr_t _requestCancelLinkedList;
}

- (instancetype)init {
    if ((self = [super init])) {
        atomic_init(&_state, PMSPromiseBoxStateEmpty);
        atomic_init(&_callbackList, 0);
        atomic_init(&_requestCancelLinkedList, 0);
    }
    return self;
}

- (instancetype)initWithState:(PMSPromiseBoxState)state {
    if ((self = [super init])) {
        atomic_init(&_state, state);
    }
    return self;
}

- (PMSPromiseBoxState)state {
    PMSPromiseBoxState state = (PMSPromiseBoxState)atomic_load_explicit(&_state, memory_order_relaxed);
    if (state == PMSPromiseBoxStateResolved) {
        // if we're fulfilled, our client is about to read the value, so issue a fence
        atomic_thread_fence(memory_order_acquire); // forms edge with the cmpxchg in -transitionStateTo:
    }
    return state;
}

- (PMSPromiseBoxState)unfencedState {
    return (PMSPromiseBoxState)atomic_load_explicit(&_state, memory_order_relaxed);
}

- (BOOL)transitionStateTo:(PMSPromiseBoxState)state {
    memory_order successOrder = memory_order_relaxed;
    if (state == PMSPromiseBoxStateResolved) {
        successOrder = memory_order_release; // forms edge with the fence in -state
    }
    PMSPromiseBoxState oldState = (PMSPromiseBoxState)atomic_load_explicit(&_state, memory_order_relaxed);
    while (1) {
        switch (oldState) {
            case PMSPromiseBoxStateEmpty:
                if (state != PMSPromiseBoxStateResolving &&
                    state != PMSPromiseBoxStateCancelling &&
                    state != PMSPromiseBoxStateCancelled) return NO;
                break;
            case PMSPromiseBoxStateResolving:
                if (state != PMSPromiseBoxStateResolved) return NO;
                break;
            case PMSPromiseBoxStateResolved:
                return NO;
            case PMSPromiseBoxStateCancelling:
                if (state != PMSPromiseBoxStateResolving && state != PMSPromiseBoxStateCancelled) return NO;
                break;
            case PMSPromiseBoxStateCancelled:
                return NO;
        }
        if (atomic_compare_exchange_strong_explicit(&_state, &oldState, state, successOrder, memory_order_relaxed)) return YES;
    }
}

- (void *)swapCallbackLinkedListWith:(void *)node linkBlock:(nullable void (^)(void * _Nullable))linkBlock {
    uintptr_t oldValue = atomic_load_explicit(&_callbackList, memory_order_relaxed);
    while (1) {
        if (oldValue == (uintptr_t)PMSLinkedListSwapFailed) {
            atomic_thread_fence(memory_order_acquire);
            return (void *)oldValue;
        }
        if (linkBlock) linkBlock((void *)oldValue);
        if (atomic_compare_exchange_weak_explicit(&_callbackList, &oldValue, (uintptr_t)node, memory_order_acq_rel, memory_order_relaxed)) {
            return (void *)oldValue;
        }
    }
}

- (void *)swapRequestCancelLinkedListWith:(void *)node linkBlock:(nullable void (^)(void * _Nullable))linkBlock {
    uintptr_t oldValue = atomic_load_explicit(&_requestCancelLinkedList, memory_order_relaxed);
    while (1) {
        if (oldValue == (uintptr_t)PMSLinkedListSwapFailed) {
            atomic_thread_fence(memory_order_acquire);
            return (void *)oldValue;
        }
        if (linkBlock) linkBlock((void *)oldValue);
        if (atomic_compare_exchange_weak_explicit(&_requestCancelLinkedList, &oldValue, (uintptr_t)node, memory_order_acq_rel, memory_order_relaxed)) {
            return (void *)oldValue;
        }
    }
}

- (void)issueDeinitFence {
    atomic_thread_fence(memory_order_acquire);
}

@end