//
//  TWLThreadLocal.m
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/2/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//

#import "TWLThreadLocal.h"

#if __has_feature(c_thread_local)
_Thread_local BOOL flag = NO;
#else
#include <pthread.h>
static pthread_key_t flagKey;
__attribute__((constructor)) static void constructFlagKey() {
    int err = pthread_key_create(&flagKey, NULL);
    assert(err == 0);
}
#endif

BOOL TWLGetMainContextThreadLocalFlag(void) {
#if __has_feature(c_thread_local)
    return flag;
#else
    return pthread_getspecific(flagKey) != NULL;
#endif
}

void TWLSetMainContextThreadLocalFlag(BOOL value) {
#if __has_feature(c_thread_local)
    flag = value;
#else
    int err = pthread_setspecific(flagKey, value ? kCFBooleanTrue : NULL);
    assert(err == 0);
#endif
}

void TWLExecuteBlockWithMainContextThreadLocalFlag(dispatch_block_t _Nonnull block) {
    TWLSetMainContextThreadLocalFlag(YES);
    @try {
        block();
    } @finally {
        TWLSetMainContextThreadLocalFlag(NO);
    }
}

typedef struct TWLThreadLocalLinkedListNode {
    struct TWLThreadLocalLinkedListNode * _Nullable next;
    void * _Nonnull data;
} TWLThreadLocalLinkedListNode;

#if __has_feature(c_thread_local)
_Thread_local TWLThreadLocalLinkedListNode * _Nullable linkedListHead;
_Thread_local TWLThreadLocalLinkedListNode * _Nullable linkedListTail;
#else
static pthread_key_t linkedListHeadKey;
static pthread_key_t linkedListTailKey;
__attribute__((constructor)) static void constructLinkedListKeys() {
    int err = pthread_key_create(&linkedListHeadKey, NULL);
    assert(err == 0);
    err = pthread_key_create(&linkedListTailKey, NULL);
    assert(err == 0);
}
#endif

void TWLEnqueueThreadLocalBlock(dispatch_block_t _Nonnull block) {
    TWLThreadLocalLinkedListNode * _Nonnull node = malloc(sizeof(TWLThreadLocalLinkedListNode));
    node->next = NULL;
    node->data = (__bridge_retained void *)block;
#if __has_feature(c_thread_local)
    if (linkedListTail) {
        linkedListTail->next = node;
    } else {
        linkedListHead = node;
    }
    linkedListTail = node;
#else
    TWLThreadLocalLinkedListNode * _Nullable linkedListTail = pthread_getspecific(linkedListTailKey);
    if (linkedListTail) {
        linkedListTail->next = node;
    } else {
        pthread_setspecific(linkedListHeadKey, node);
    }
    pthread_setspecific(linkedListTailKey, node);
#endif
}

dispatch_block_t _Nullable TWLDequeueThreadLocalBlock(void) {
#if __has_feature(c_thread_local)
    TWLThreadLocalLinkedListNode * _Nullable node = linkedListHead;
#else
    TWLThreadLocalLinkedListNode * _Nullable node = pthread_getspecific(linkedListHeadKey);
#endif
    if (node) {
#if __has_feature(c_thread_local)
        linkedListHead = node->next;
        if (!linkedListHead) {
            linkedListTail = NULL;
        }
#else
        pthread_setspecific(linkedListHeadKey, node->next);
        if (!node->next) {
            pthread_setspecific(linkedListTailKey, NULL);
        }
#endif
        dispatch_block_t block = (__bridge_transfer dispatch_block_t)node->data;
        free(node);
        return block;
    } else {
        return nil;
    }
}
