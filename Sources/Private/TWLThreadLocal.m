//
//  TWLThreadLocal.m
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/2/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//

#import "TWLThreadLocal.h"

_Thread_local BOOL flag = NO;

BOOL TWLGetMainContextThreadLocalFlag(void) {
    return flag;
}

void TWLSetMainContextThreadLocalFlag(BOOL value) {
    flag = value;
}

void TWLExecuteBlockWithMainContextThreadLocalFlag(dispatch_block_t _Nonnull block) {
    flag = YES;
    @try {
        block();
    } @finally {
        flag = NO;
    }
}

typedef struct TWLThreadLocalLinkedListNode {
    struct TWLThreadLocalLinkedListNode * _Nullable next;
    void * _Nonnull data;
} TWLThreadLocalLinkedListNode;

_Thread_local TWLThreadLocalLinkedListNode * _Nullable linkedListHead;
_Thread_local TWLThreadLocalLinkedListNode * _Nullable linkedListTail;

void TWLEnqueueThreadLocalBlock(dispatch_block_t _Nonnull block) {
    TWLThreadLocalLinkedListNode * _Nonnull node = malloc(sizeof(TWLThreadLocalLinkedListNode));
    node->next = NULL;
    node->data = (__bridge_retained void *)block;
    if (linkedListTail) {
        linkedListTail->next = node;
    } else {
        linkedListHead = node;
    }
    linkedListTail = node;
}

dispatch_block_t _Nullable TWLDequeueThreadLocalBlock(void) {
    TWLThreadLocalLinkedListNode * _Nullable node = linkedListHead;
    if (node) {
        linkedListHead = node->next;
        if (!linkedListHead) {
            linkedListTail = NULL;
        }
        dispatch_block_t block = (__bridge_transfer dispatch_block_t)node->data;
        free(node);
        return block;
    } else {
        return nil;
    }
}
