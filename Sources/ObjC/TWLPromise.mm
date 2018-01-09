//
//  TWLPromise.m
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/3/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLPromisePrivate.h"
#import <Tomorrowland/Tomorrowland-Swift.h>
#import "TWLContextPrivate.h"
#import "TWLPromiseBox.h"
#import "objc_cast.h"

@interface TWLResolver () {
@public
    TWLPromise * _Nonnull _promise;
}
@end

@interface TWLInvalidationToken (Private)
@property (atomic, readonly) NSUInteger generation;
@end

@implementation TWLPromise {
@public
    id _Nullable _value;
    id _Nullable _error;
}

+ (instancetype)newOnContext:(TWLContext *)context withBlock:(void (^)(TWLResolver<id,id> * _Nonnull))block {
    return [[self alloc] initOnContext:context withBlock:block];
}

+ (instancetype)newFulfilledWithValue:(id)value {
    return [[self alloc] initFulfilledWithValue:value];
}

+ (instancetype)newRejectedWithError:(id)error {
    return [[self alloc] initRejectedWithError:error];
}

+ (std::pair<TWLPromise<id,id> *, TWLResolver<id,id> *>)makePromiseWithResolver {
    TWLResolver *resolver;
    TWLPromise *promise = [[TWLPromise alloc] initWithResolver:&resolver];
    return std::make_pair(promise, resolver);
}

- (instancetype)initOnContext:(TWLContext *)context withBlock:(void (^)(TWLResolver<id,id> * _Nonnull))block {
    if ((self = [super init])) {
        _box = [[TWLPromiseBox alloc] init];
        TWLResolver *resolver = [[TWLResolver alloc] initWithPromise:self];
        [context executeBlock:^{
            block(resolver);
        }];
    }
    return self;
}

- (instancetype)initFulfilledWithValue:(id)value {
    if ((self = [super init])) {
        _box = [[TWLPromiseBox alloc] initWithState:TWLPromiseBoxStateResolved];
        _value = value;
    }
    return self;
}

- (instancetype)initRejectedWithError:(id)error {
    if ((self = [super init])) {
        _box = [[TWLPromiseBox alloc] initWithState:TWLPromiseBoxStateResolved];
        _error = error;
    }
    return self;
}

- (instancetype)initWithResolver:(TWLResolver<id,id> *__strong _Nullable *)outResolver {
    if ((self = [super init])) {
        _box = [[TWLPromiseBox alloc] init];
        *outResolver = [[TWLResolver alloc] initWithPromise:self];
    }
    return self;
}

- (instancetype)initDelayed {
    if ((self = [super init])) {
        _box = [[TWLPromiseBox alloc] initWithState:TWLPromiseBoxStateDelayed];
    }
    return self;
}

- (void)dealloc {
    [_box issueDeinitFence];
    if (auto nodePtr = CallbackNode::castPointer([_box swapCallbackLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
        // If we actually have a callback list, we must not have been resolved, so inform our
        // callbacks that we've cancelled.
        // NB: No need to actually transition to the cancelled state first, if anyone still had
        // a reference to us to look at that, we wouldn't be in deinit.
        nodePtr = CallbackNode::reverseList(nodePtr);
        @try {
            for (auto current = nodePtr; current; current = current->next) {
                current->callback(nil,nil);
            }
        } @finally {
            CallbackNode::destroyPointer(nodePtr);
        }
    }
    if (auto nodePtr = RequestCancelNode::castPointer([_box swapRequestCancelLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
        // NB: We can't fire these callbacks because they take a TWLResolver and we can't have them
        // resurrecting ourselves. We could work around this, but the only reason to even have these
        // callbacks at this point is if the promise handler drops the last reference to the
        // resolver, and since that means it's a buggy implementation, we don't need to support it.
        RequestCancelNode::destroyPointer(nodePtr);
    }
}

#pragma mark -

- (TWLPromise *)then:(void (^)(id _Nonnull))handler {
    return [self thenOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)thenOnContext:(TWLContext *)context handler:(void (^)(id _Nonnull))handler {
    return [self thenOnContext:context token:nil handler:handler];
}

- (TWLPromise *)thenOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(id _Nonnull))handler {
    auto generation = token.generation;
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        if (value) {
            [context executeBlock:^{
                if (token && generation != token.generation) return;
                handler(value);
            }];
        }
    }];
    return self;
}

- (TWLPromise *)map:(id _Nonnull (^)(id _Nonnull))handler {
    return [self mapOnContext:TWLContext.automatic token:nil options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)mapOnContext:(TWLContext *)context handler:(id (^)(id _Nonnull))handler {
    return [self mapOnContext:context token:nil options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)mapOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(id _Nonnull (^)(id _Nonnull))handler {
    return [self mapOnContext:context token:token options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)mapOnContext:(TWLContext *)context options:(TWLPromiseOptions)options handler:(id _Nonnull (^)(id _Nonnull))handler {
    return [self mapOnContext:context token:nil options:options handler:handler];
}

- (TWLPromise *)mapOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(id _Nonnull (^)(id _Nonnull))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        [context executeBlock:^{
            if (value) {
                if (token && generation != token.generation) {
                    [resolver cancel];
                } else {
                    id newValue = handler(value);
                    if (auto nextPromise = objc_cast<TWLPromise>(newValue)) {
                        [nextPromise pipeToResolver:resolver];
                    } else {
                        [resolver fulfillWithValue:newValue];
                    }
                }
            } else if (error) {
                [resolver rejectWithError:error];
            } else {
                [resolver cancel];
            }
        }];
    }];
    if (options & TWLPromiseOptionsLinkCancel) {
        __weak typeof(self) weakSelf = self;
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [weakSelf requestCancel];
        }];
    }
    return promise;
}

- (TWLPromise *)catch:(void (^)(id _Nonnull))handler {
    return [self catchOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)catchOnContext:(TWLContext *)context handler:(void (^)(id _Nonnull))handler {
    return [self catchOnContext:context token:nil handler:handler];
}

- (TWLPromise *)catchOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(id _Nonnull))handler {
    auto generation = token.generation;
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        if (error) {
            [context executeBlock:^{
                if (token && generation != token.generation) return;
                handler(error);
            }];
        }
    }];
    return self;
}

- (TWLPromise *)recover:(id _Nonnull (^)(id _Nonnull))handler {
    return [self recoverOnContext:TWLContext.automatic token:nil options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)recoverOnContext:(TWLContext *)context handler:(id  _Nonnull (^)(id _Nonnull))handler {
    return [self recoverOnContext:context token:nil options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)recoverOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(id _Nonnull (^)(id _Nonnull))handler {
    return [self recoverOnContext:context token:token options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)recoverOnContext:(TWLContext *)context options:(TWLPromiseOptions)options handler:(id _Nonnull (^)(id _Nonnull))handler {
    return [self recoverOnContext:context token:nil options:options handler:handler];
}

- (TWLPromise *)recoverOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(id _Nonnull (^)(id _Nonnull))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        [context executeBlock:^{
            if (value) {
                [resolver fulfillWithValue:value];
            } else if (error) {
                if (token && generation != token.generation) {
                    [resolver cancel];
                } else {
                    id newValue = handler(error);
                    if (auto nextPromise = objc_cast<TWLPromise>(newValue)) {
                        [nextPromise pipeToResolver:resolver];
                    } else {
                        [resolver fulfillWithValue:newValue];
                    }
                }
            } else {
                [resolver cancel];
            }
        }];
    }];
    if (options & TWLPromiseOptionsLinkCancel) {
        __weak typeof(self) weakSelf = self;
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [weakSelf requestCancel];
        }];
    }
    return promise;
}

- (TWLPromise *)inspect:(void (^)(id _Nullable, id _Nullable))handler {
    return [self inspectOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)inspectOnContext:(TWLContext *)context handler:(void (^)(id _Nullable, id _Nullable))handler {
    return [self inspectOnContext:context token:nil handler:handler];
}

- (TWLPromise *)inspectOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(id _Nullable, id _Nullable))handler {
    auto generation = token.generation;
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        [context executeBlock:^{
            if (token && generation != token.generation) return;
            handler(value, error);
        }];
    }];
    return self;
}

- (TWLPromise *)always:(TWLPromise * _Nonnull (^)(id _Nullable, id _Nullable))handler {
    return [self alwaysOnContext:TWLContext.automatic token:nil options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)alwaysOnContext:(TWLContext *)context handler:(TWLPromise * _Nonnull (^)(id _Nullable, id _Nullable))handler {
    return [self alwaysOnContext:context token:nil options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)alwaysOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(TWLPromise * _Nonnull (^)(id _Nullable, id _Nullable))handler {
    return [self alwaysOnContext:context token:token options:(TWLPromiseOptions)0 handler:handler];
}

- (TWLPromise *)alwaysOnContext:(TWLContext *)context options:(TWLPromiseOptions)options handler:(TWLPromise * _Nonnull (^)(id _Nullable, id _Nullable))handler {
    return [self alwaysOnContext:context token:nil options:options handler:handler];
}

- (TWLPromise *)alwaysOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(TWLPromise * _Nonnull (^)(id _Nullable, id _Nullable))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        [context executeBlock:^{
            if (token && generation != token.generation) {
                [resolver cancel];
            } else {
                auto nextPromise = handler(value, error);
                [nextPromise pipeToResolver:resolver];
            }
        }];
    }];
    if (options & TWLPromiseOptionsLinkCancel) {
        __weak typeof(self) weakSelf = self;
        [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
            [weakSelf requestCancel];
        }];
    }
    return promise;
}

- (TWLPromise *)whenCancelled:(void (^)(void))handler {
    return [self whenCancelledOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)whenCancelledOnContext:(TWLContext *)context handler:(void (^)(void))handler {
    return [self whenCancelledOnContext:context token:nil handler:handler];
}

- (TWLPromise *)whenCancelledOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(void))handler {
    auto generation = token.generation;
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        if (!value && !error) {
            [context executeBlock:^{
                if (token && generation != token.generation) return;
                handler();
            }];
        }
    }];
    return self;
}

- (BOOL)getValue:(id  _Nullable __strong *)outValue error:(id  _Nullable __strong *)outError {
    auto result = self.result;
    if (std::get<BOOL>(result)) {
        if (outValue) *outValue = std::get<1>(result);
        if (outError) *outError = std::get<2>(result);
        return YES;
    } else {
        return NO;
    }
}

- (std::tuple<BOOL, id _Nullable, id _Nullable>)result {
    switch (_box.state) {
        case TWLPromiseBoxStateDelayed:
        case TWLPromiseBoxStateEmpty:
        case TWLPromiseBoxStateResolving:
        case TWLPromiseBoxStateCancelling:
            return std::make_tuple(NO,nil,nil);
        case TWLPromiseBoxStateResolved:
            NSAssert(_value != nil || _error != nil, @"TWLPromise held nil value/error while in fulfilled state");
            NSAssert(_value == nil || _error == nil, @"TWLPromise held both a value and an error simultaneously");
            return std::make_tuple(YES,_value,_error);
        case TWLPromiseBoxStateCancelled:
            return std::make_tuple(YES,nil,nil);
    }
}

- (void)requestCancel {
    if ([_box transitionStateTo:TWLPromiseBoxStateCancelling]) {
        if (auto nodePtr = RequestCancelNode::castPointer([_box swapRequestCancelLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
            nodePtr = RequestCancelNode::reverseList(nodePtr);
            @try {
                auto resolver = [[TWLResolver alloc] initWithPromise:self];
                for (auto current = nodePtr; current; current = current->next) {
                    current->invoke(resolver);
                }
            } @finally {
                RequestCancelNode::destroyPointer(nodePtr);
            }
        }
    }
}

- (TWLPromise *)ignoringCancel {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        [resolver resolveWithValue:value error:error];
    }];
    return promise;
}

#pragma mark - Private

- (void)resolveOrCancelWithValue:(nullable id)value error:(nullable id)error {
    NSParameterAssert(value == nil || error == nil);
    if (!value && !error) {
        if ([_box transitionStateTo:TWLPromiseBoxStateCancelled]) {
            goto handleCallbacks;
        }
    } else if ([_box transitionStateTo:TWLPromiseBoxStateResolving]) {
        _value = value;
        _error = error;
        if ([_box transitionStateTo:TWLPromiseBoxStateResolved]) {
            goto handleCallbacks;
        } else {
            NSAssert(NO, @"Couldn't transition TWLPromiseBox to TWLPromiseBoxStateResolved after transitioning to TWLPromiseBoxStateResolving");
        }
    }
    return;
    
handleCallbacks:
    if (auto nodePtr = RequestCancelNode::castPointer([_box swapRequestCancelLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
        RequestCancelNode::destroyPointer(nodePtr);
    }
    if (auto nodePtr = CallbackNode::castPointer([_box swapCallbackLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
        nodePtr = CallbackNode::reverseList(nodePtr);
        @try {
            for (auto current = nodePtr; current; current = current->next) {
                current->callback(value,error);
            }
        } @finally {
            CallbackNode::destroyPointer(nodePtr);
        }
    }
}

- (void)enqueueCallback:(void (^)(id _Nullable value, id _Nullable error))callback {
    auto nodePtr = new CallbackNode(callback);
    if ([_box swapCallbackLinkedListWith:reinterpret_cast<void *>(nodePtr) linkBlock:^(void * _Nullable nextNode) {
        nodePtr->next = reinterpret_cast<CallbackNode *>(nextNode);
    }] == TWLLinkedListSwapFailed) {
        delete nodePtr;
        switch (_box.state) {
            case TWLPromiseBoxStateResolved:
            case TWLPromiseBoxStateCancelled:
                break;
            case TWLPromiseBoxStateDelayed:
            case TWLPromiseBoxStateEmpty:
            case TWLPromiseBoxStateResolving:
            case TWLPromiseBoxStateCancelling:
                @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"TWLPromise callback list empty but state isn't actually resolved" userInfo:nil];
        }
        callback(_value, _error);
    }
}

- (void)pipeToResolver:(nonnull TWLResolver *)resolver {
    [self enqueueCallback:^(id _Nullable value, id _Nullable error) {
        [resolver resolveWithValue:value error:error];
    }];
    __weak typeof(self) weakSelf = self;
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        [weakSelf requestCancel];
    }];
}

- (NSString *)debugDescription {
    NSInteger callbackCount = CallbackNode::countNodes(_box.callbackList);
    NSInteger requestCancelCount = RequestCancelNode::countNodes(_box.requestCancelLinkedList);
    auto describe = [](NSInteger count) -> NSString * _Nonnull {
        return [NSString stringWithFormat:@"%zd node%@", count, count == 1 ? @"" : @"s"];
    };
    NSString *stateName;
    switch (_box.unfencedState) {
        case TWLPromiseBoxStateDelayed: stateName = @"delayed"; break;
        case TWLPromiseBoxStateEmpty: stateName = @"empty"; break;
        case TWLPromiseBoxStateResolving: stateName = @"resolving"; break;
        case TWLPromiseBoxStateResolved: stateName = @"resolved"; break;
        case TWLPromiseBoxStateCancelling: stateName = @"cancelling"; break;
        case TWLPromiseBoxStateCancelled: stateName = @"cancelled"; break;
    }
    return [NSString stringWithFormat:@"<%@: %p state=%@ callbackList=%zd requestCancelList=%zd>", NSStringFromClass([self class]), self, stateName, describe(callbackCount), describe(requestCancelCount)];
}

namespace {
    template<typename Self> struct LinkedListNode {
        Self * _Nullable next = nullptr;
        
        static Self * _Nullable castPointer(void * _Nullable ptr) {
            if (!ptr || ptr == TWLLinkedListSwapFailed) { return nullptr; }
            return reinterpret_cast<Self *>(ptr);
        }
        
        /// Destroys the linked list.
        ///
        /// \pre The pointer must be initialized.
        /// \post The pointer is deinitialized using \c delete.
        static void destroyPointer(Self * _Nonnull ptr) {
            auto nextPointer = ptr->next;
            delete ptr;
            while (auto current = nextPointer) {
                nextPointer = current->next;
                delete current;
            }
        }
        
        static Self * _Nonnull reverseList(Self * _Nonnull ptr) {
            auto nextPointer = ptr->next;
            ptr->next = nullptr;
            auto previous = ptr;
            while (auto current = nextPointer) {
                nextPointer = current->next;
                current->next = previous;
                previous = current;
            }
            return previous;
        }
        
        static NSInteger countNodes(void * _Nullable ptr) {
            auto nodePtr = castPointer(ptr);
            NSInteger count = 0;
            while (nodePtr) {
                ++count;
                nodePtr = nodePtr->next;
            }
            return count;
        }
    };
    
    struct CallbackNode: LinkedListNode<CallbackNode> {
        void (^ _Nonnull callback)(id _Nullable value, id _Nullable error);
        
        CallbackNode(void (^ _Nonnull callback)(id _Nullable,id _Nullable)) : LinkedListNode(), callback(callback) {}
    };
    
    struct RequestCancelNode: LinkedListNode<RequestCancelNode> {
        TWLContext * _Nonnull context;
        void (^ _Nonnull callback)(TWLResolver * _Nonnull resolver);
        
        RequestCancelNode(TWLContext * _Nonnull context, void (^ _Nonnull callback)(TWLResolver * _Nonnull)) : LinkedListNode(), context(context), callback(callback) {}
        
        void invoke(TWLResolver * _Nonnull resolver) {
            if (this->context.isImmediate) {
                // skip the state check
                this->callback(resolver);
            } else {
                auto callback = this->callback;
                [this->context executeBlock:^{
                    switch (resolver->_promise->_box.unfencedState) {
                        case TWLPromiseBoxStateDelayed:
                        case TWLPromiseBoxStateEmpty:
                            NSCAssert(NO, @"We shouldn't be invoking a whenCancelRequested callback on an empty promise");
                            break;
                        case TWLPromiseBoxStateCancelling:
                        case TWLPromiseBoxStateCancelled:
                            callback(resolver);
                            break;
                        case TWLPromiseBoxStateResolving:
                        case TWLPromiseBoxStateResolved:
                            // if the promise has been resolved, skip the cancel callback
                            break;
                    }
                }];
            }
        }
    };
}

@end

@implementation TWLResolver

- (instancetype)initWithPromise:(TWLPromise<id,id> *)promise {
    if ((self = [super init])) {
        _promise = promise;
    }
    return self;
}

- (void)fulfillWithValue:(id)value {
    [_promise resolveOrCancelWithValue:value error:nil];
}

- (void)rejectWithError:(id)error {
    [_promise resolveOrCancelWithValue:nil error:error];
}

- (void)cancel {
    [_promise resolveOrCancelWithValue:nil error:nil];
}

- (void)resolveWithValue:(id)value error:(id)error {
    [_promise resolveOrCancelWithValue:value error:error];
}

- (void)whenCancelRequestedOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<id,id> * _Nonnull))handler {
    auto nodePtr = new RequestCancelNode(context, handler);
    if ([_promise->_box swapRequestCancelLinkedListWith:nodePtr linkBlock:^(void * _Nullable nextNode) {
        nodePtr->next = reinterpret_cast<RequestCancelNode *>(nextNode);
    }] == TWLLinkedListSwapFailed) {
        delete nodePtr;
        switch (_promise->_box.unfencedState) {
            case TWLPromiseBoxStateCancelling:
            case TWLPromiseBoxStateCancelled: {
                [context executeBlock:^{
                    handler(self);
                }];
                break;
            }
            case TWLPromiseBoxStateDelayed:
            case TWLPromiseBoxStateEmpty:
            case TWLPromiseBoxStateResolving:
            case TWLPromiseBoxStateResolved:
                break;
        }
    }
}

@end
