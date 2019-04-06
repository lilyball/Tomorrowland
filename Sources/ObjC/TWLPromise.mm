//
//  TWLPromise.m
//  Tomorrowland
//
//  Created by Lily Ballard on 1/3/18.
//  Copyright © 2018 Lily Ballard.
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
#import <objc/runtime.h>
#import "objc_cast.h"

@interface TWLResolver<ValueType,ErrorType> () {
@public
    TWLObjCPromiseBox<ValueType,ErrorType> * _Nonnull _box;
}
@end

@interface TWLInvalidationToken (Private)
@property (atomic, readonly) NSUInteger generation;
@end

@interface TWLObjCPromiseBox<ValueType,ErrorType> () {
@public
    id _Nullable _value;
    id _Nullable _error;
}
- (void)resolveOrCancelWithValue:(nullable ValueType)value error:(nullable ErrorType)error;
- (void)requestCancel;
- (void)seal;
@end

@interface TWLThreadDictionaryKey : NSObject <NSCopying>
- (nonnull instancetype)initWithDescription:(nonnull NSString *)description;
@end

@implementation TWLPromise

+ (instancetype)newOnContext:(TWLContext *)context withBlock:(void (^)(TWLResolver<id,id> * _Nonnull))block {
    return [[self alloc] initOnContext:context withBlock:block];
}

+ (instancetype)newFulfilledWithValue:(id)value {
    return [[self alloc] initFulfilledWithValue:value];
}

+ (instancetype)newRejectedWithError:(id)error {
    return [[self alloc] initRejectedWithError:error];
}

+ (instancetype)newCancelled {
    return [[self alloc] initCancelled];
}

+ (std::pair<TWLPromise<id,id> *, TWLResolver<id,id> *>)makePromiseWithResolver {
    TWLResolver *resolver;
    TWLPromise *promise = [[TWLPromise alloc] initWithResolver:&resolver];
    return std::make_pair(promise, resolver);
}

- (instancetype)initOnContext:(TWLContext *)context withBlock:(void (^)(TWLResolver<id,id> * _Nonnull))block {
    if ((self = [super init])) {
        _box = [[TWLObjCPromiseBox alloc] init];
        TWLResolver *resolver = [[TWLResolver alloc] initWithBox:_box];
        [context executeBlock:^{
            block(resolver);
        }];
    }
    return self;
}

- (instancetype)initFulfilledWithValue:(id)value {
    if ((self = [super init])) {
        _box = [[TWLObjCPromiseBox alloc] initWithState:TWLPromiseBoxStateResolved];
        _box->_value = value;
    }
    return self;
}

- (instancetype)initRejectedWithError:(id)error {
    if ((self = [super init])) {
        _box = [[TWLObjCPromiseBox alloc] initWithState:TWLPromiseBoxStateResolved];
        _box->_error = error;
    }
    return self;
}

- (instancetype)initCancelled {
    if ((self = [super init])) {
        _box = [[TWLObjCPromiseBox alloc] initWithState:TWLPromiseBoxStateCancelled];
    }
    return self;
}

- (instancetype)initWithResolver:(TWLResolver<id,id> *__strong _Nullable *)outResolver {
    if ((self = [super init])) {
        _box = [[TWLObjCPromiseBox alloc] init];
        *outResolver = [[TWLResolver alloc] initWithBox:_box];
    }
    return self;
}

- (instancetype)initDelayed {
    if ((self = [super init])) {
        _box = [[TWLObjCPromiseBox alloc] initWithState:TWLPromiseBoxStateDelayed];
    }
    return self;
}

- (void)dealloc {
    [_box seal];
}

#pragma mark -

- (TWLPromise *)then:(void (^)(id _Nonnull))handler {
    return [self thenOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)thenOnContext:(TWLContext *)context handler:(void (^)(id _Nonnull))handler {
    return [self thenOnContext:context token:nil handler:handler];
}

- (TWLPromise *)thenOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(id _Nonnull))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(id)){
        if (value) {
            [context executeBlock:^{
                auto handler = oneshot();
                if (!token || generation == token.generation) {
                    handler(value);
                }
                [resolver fulfillWithValue:value];
            }];
        } else if (error) {
            [resolver rejectWithError:error];
        } else {
            [resolver cancel];
        }
    });
    propagateCancellation(resolver, self);
    return promise;
}

- (TWLPromise *)map:(id _Nonnull (^)(id _Nonnull))handler {
    return [self mapOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)mapOnContext:(TWLContext *)context handler:(id (^)(id _Nonnull))handler {
    return [self mapOnContext:context token:nil handler:handler];
}

- (TWLPromise *)mapOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(id _Nonnull (^)(id _Nonnull))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, id (^(^oneshot)(void))(id)){
        if (value) {
            [context executeBlock:^{
                auto handler = oneshot();
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
            }];
        } else if (error) {
            [resolver rejectWithError:error];
        } else {
            [resolver cancel];
        }
    });
    propagateCancellation(resolver, self);
    return promise;
}

- (TWLPromise *)catch:(void (^)(id _Nonnull))handler {
    return [self catchOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)catchOnContext:(TWLContext *)context handler:(void (^)(id _Nonnull))handler {
    return [self catchOnContext:context token:nil handler:handler];
}

- (TWLPromise *)catchOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(id _Nonnull))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(id)){
        if (value) {
            [resolver fulfillWithValue:value];
        } else if (error) {
            [context executeBlock:^{
                auto handler = oneshot();
                if (!token || generation == token.generation) {
                    handler(error);
                }
                [resolver rejectWithError:error];
            }];
        } else {
            [resolver cancel];
        }
    });
    propagateCancellation(resolver, self);
    return promise;
}

- (TWLPromise *)recover:(id _Nonnull (^)(id _Nonnull))handler {
    return [self recoverOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)recoverOnContext:(TWLContext *)context handler:(id  _Nonnull (^)(id _Nonnull))handler {
    return [self recoverOnContext:context token:nil handler:handler];
}

- (TWLPromise *)recoverOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(id _Nonnull (^)(id _Nonnull))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, id (^(^oneshot)(void))(id)){
        if (value) {
            [resolver fulfillWithValue:value];
        } else if (error) {
            [context executeBlock:^{
                auto handler = oneshot();
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
            }];
        } else {
            [resolver cancel];
        }
    });
    propagateCancellation(resolver, self);
    return promise;
}

- (TWLPromise *)inspect:(void (^)(id _Nullable, id _Nullable))handler {
    return [self inspectOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)inspectOnContext:(TWLContext *)context handler:(void (^)(id _Nullable, id _Nullable))handler {
    return [self inspectOnContext:context token:nil handler:handler];
}

- (TWLPromise *)inspectOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(id _Nullable, id _Nullable))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(id,id)){
        [context executeBlock:^{
            auto handler = oneshot();
            if (!token || generation == token.generation) {
                handler(value, error);
            }
            [resolver resolveWithValue:value error:error];
        }];
    });
    propagateCancellation(resolver, self);
    return promise;
}

- (TWLPromise *)always:(TWLPromise * _Nonnull (^)(id _Nullable, id _Nullable))handler {
    return [self alwaysOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)alwaysOnContext:(TWLContext *)context handler:(TWLPromise * _Nonnull (^)(id _Nullable, id _Nullable))handler {
    return [self alwaysOnContext:context token:nil handler:handler];
}

- (TWLPromise *)alwaysOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(TWLPromise * _Nonnull (^)(id _Nullable, id _Nullable))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, TWLPromise *(^(^oneshot)(void))(id,id)){
        [context executeBlock:^{
            auto handler = oneshot();
            if (token && generation != token.generation) {
                [resolver cancel];
            } else {
                auto nextPromise = handler(value, error);
                [nextPromise pipeToResolver:resolver];
            }
        }];
    });
    propagateCancellation(resolver, self);
    return promise;
}

- (TWLPromise *)tap:(void (^)(id _Nullable, id _Nullable))handler {
    return [self tapOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)tapOnContext:(TWLContext *)context handler:(void (^)(id _Nullable, id _Nullable))handler {
    return [self tapOnContext:context token:nil handler:handler];
}

- (TWLPromise *)tapOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(id _Nullable, id _Nullable))handler {
    auto generation = token.generation;
    enqueueCallback(self, NO, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(id,id)){
        [context executeBlock:^{
            auto handler = oneshot();
            if (!token || generation == token.generation) {
                handler(value, error);
            }
        }];
    });
    return self;
}

- (TWLPromise *)tap {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    [self enqueueCallbackWithoutOneshot:^(id _Nullable value, id _Nullable error) {
        [resolver resolveWithValue:value error:error];
    } willPropagateCancel:NO];
    return promise;
}

- (TWLPromise *)whenCancelled:(void (^)(void))handler {
    return [self whenCancelledOnContext:TWLContext.automatic token:nil handler:handler];
}

- (TWLPromise *)whenCancelledOnContext:(TWLContext *)context handler:(void (^)(void))handler {
    return [self whenCancelledOnContext:context token:nil handler:handler];
}

- (TWLPromise *)whenCancelledOnContext:(TWLContext *)context token:(TWLInvalidationToken *)token handler:(void (^)(void))handler {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    auto generation = token.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(void)){
        if (value) {
            [resolver fulfillWithValue:value];
        } else if (error) {
            [resolver rejectWithError:error];
        } else {
            [context executeBlock:^{
                auto handler = oneshot();
                if (!token || generation == token.generation) {
                    handler();
                }
                [resolver cancel];
            }];
        }
    });
    propagateCancellation(resolver, self);
    return promise;
}

- (BOOL)getValue:(id  _Nullable __strong *)outValue error:(id  _Nullable __strong *)outError {
    return [_box getValue:outValue error:outError];
}

- (std::tuple<BOOL, id _Nullable, id _Nullable>)result {
    return _box.result;
}

- (void)requestCancel {
    [_box requestCancel];
}

- (TWLPromise *)requestCancelOnInvalidate:(TWLInvalidationToken *)token {
    [token requestCancelOnInvalidate:self];
    return self;
}

- (TWLPromise *)requestCancelOnDealloc:(id)object {
    // We store a TWLInvalidationToken on the object using associated objects.
    // As an optimization, we try to reuse tokens when possible. For safety's sake we can't just use
    // a single associated object key or we'll have a problem in a multithreaded scenario.
    // So instead we'll use a separate key per thread.
    static TWLThreadDictionaryKey *threadKey;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        threadKey = [[TWLThreadDictionaryKey alloc] initWithDescription:@"key for TWLInvalidationToken"];
    });
    id keyObject = NSThread.currentThread.threadDictionary[threadKey];
    if (!keyObject) {
        keyObject = [NSObject new];
        NSThread.currentThread.threadDictionary[threadKey] = keyObject;
    }
    TWLInvalidationToken *token = objc_getAssociatedObject(object, (__bridge void *)keyObject);
    if (!token) {
        token = [TWLInvalidationToken new];
        objc_setAssociatedObject(object, (__bridge void *)keyObject, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [self requestCancelOnInvalidate:token];
    return self;
}

- (TWLPromise *)ignoringCancel {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    [self enqueueCallbackWithoutOneshot:^(id _Nullable value, id _Nullable error) {
        [resolver resolveWithValue:value error:error];
    } willPropagateCancel:YES];
    return promise;
}

- (id<TWLCancellable>)cancellable {
    return _box;
}

#pragma mark - Private

- (void)enqueueCallbackWithoutOneshot:(void (^)(id _Nullable value, id _Nullable error))callback willPropagateCancel:(BOOL)willPropagateCancel {
    if (willPropagateCancel) {
        // If the subsequent swap fails, that means we've already resolved (or started resolving)
        // the promise, so the observer count modification is harmless.
        [_box incrementObserverCount];
    }
    
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
        callback(_box->_value, _box->_error);
    }
}

- (void)pipeToResolver:(nonnull TWLResolver *)resolver {
    [self enqueueCallbackWithoutOneshot:^(id _Nullable value, id _Nullable error) {
        [resolver resolveWithValue:value error:error];
    } willPropagateCancel:YES];
    __weak TWLObjCPromiseBox *box = _box;
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        [box requestCancel];
    }];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@: %p box=%@>", NSStringFromClass([self class]), self, [_box debugDescription]];
}

static void propagateCancellation(TWLResolver *resolver, TWLPromise *promise) {
    __weak TWLObjCPromiseBox *box = promise->_box;
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        [box propagateCancel];
    }];
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
                    switch (resolver->_box.unfencedState) {
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

- (instancetype)initWithBox:(TWLObjCPromiseBox<id,id> *)box {
    if ((self = [super init])) {
        _box = box;
    }
    return self;
}

- (void)fulfillWithValue:(id)value {
    [_box resolveOrCancelWithValue:value error:nil];
}

- (void)rejectWithError:(id)error {
    [_box resolveOrCancelWithValue:nil error:error];
}

- (void)cancel {
    [_box resolveOrCancelWithValue:nil error:nil];
}

- (void)resolveWithValue:(id)value error:(id)error {
    [_box resolveOrCancelWithValue:value error:error];
}

- (void)resolveWithPromise:(TWLPromise *)promise {
    [promise pipeToResolver:self];
}

- (void)whenCancelRequestedOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<id,id> * _Nonnull))handler {
    auto nodePtr = new RequestCancelNode(context, handler);
    if ([_box swapRequestCancelLinkedListWith:nodePtr linkBlock:^(void * _Nullable nextNode) {
        nodePtr->next = reinterpret_cast<RequestCancelNode *>(nextNode);
    }] == TWLLinkedListSwapFailed) {
        delete nodePtr;
        switch (_box.unfencedState) {
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

- (void (^)(id _Nullable, id _Nullable))handleCallback {
    return [self handleCallbackWithCancelPredicate:^(id _Nonnull error) { return NO; }];
}

- (void (^)(id _Nullable, id _Nullable))handleCallbackWithCancelPredicate:(BOOL (^)(id _Nonnull))predicate {
    return ^(id _Nullable value, id _Nullable error) {
        if (value) {
            [self fulfillWithValue:value];
        } else if (error) {
            if (predicate(error)) {
                [self cancel];
            } else {
                [self rejectWithError:error];
            }
        } else {
            NSError *apiError = [NSError errorWithDomain:TWLPromiseCallbackErrorDomain code:TWLPromiseCallbackErrorAPIMismatch userInfo:nil];
            [self rejectWithError:apiError];
        }
    };
}

@end

#pragma mark -

@implementation TWLObjCPromiseBox

- (std::tuple<BOOL, id _Nullable, id _Nullable>)result {
    switch (self.state) {
        case TWLPromiseBoxStateDelayed:
        case TWLPromiseBoxStateEmpty:
        case TWLPromiseBoxStateResolving:
        case TWLPromiseBoxStateCancelling:
            return std::make_tuple(NO,nil,nil);
        case TWLPromiseBoxStateResolved:
            NSAssert(_value != nil || _error != nil, @"TWLObjCPromiseBox held nil value/error while in fulfilled state");
            NSAssert(_value == nil || _error == nil, @"TWLObjCPromiseBox held both a value and an error simultaneously");
            return std::make_tuple(YES,_value,_error);
        case TWLPromiseBoxStateCancelled:
            return std::make_tuple(YES,nil,nil);
    }
}

- (BOOL)getValue:(id __strong _Nullable * _Nullable)outValue error:(id __strong _Nullable * _Nullable)outError {
    auto result = self.result;
    if (std::get<BOOL>(result)) {
        if (outValue) *outValue = std::get<1>(result);
        if (outError) *outError = std::get<2>(result);
        return YES;
    } else {
        return NO;
    }
}

- (void)resolveOrCancelWithValue:(nullable id)value error:(nullable id)error {
    if (!value && !error) {
        if ([self transitionStateTo:TWLPromiseBoxStateCancelled]) {
            goto handleCallbacks;
        }
    } else if ([self transitionStateTo:TWLPromiseBoxStateResolving]) {
        _value = value;
        _error = value != nil ? nil : error;
        if ([self transitionStateTo:TWLPromiseBoxStateResolved]) {
            goto handleCallbacks;
        } else {
            NSAssert(NO, @"Couldn't transition TWLPromiseBox to TWLPromiseBoxStateResolved after transitioning to TWLPromiseBoxStateResolving");
        }
    }
    return;
    
handleCallbacks:
    if (auto nodePtr = RequestCancelNode::castPointer([self swapRequestCancelLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
        RequestCancelNode::destroyPointer(nodePtr);
    }
    if (auto nodePtr = CallbackNode::castPointer([self swapCallbackLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
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

- (void)requestCancel {
    if ([self transitionStateTo:TWLPromiseBoxStateCancelling]) {
        if (auto nodePtr = RequestCancelNode::castPointer([self swapRequestCancelLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
            nodePtr = RequestCancelNode::reverseList(nodePtr);
            @try {
                auto resolver = [[TWLResolver alloc] initWithBox:self];
                for (auto current = nodePtr; current; current = current->next) {
                    current->invoke(resolver);
                }
            } @finally {
                RequestCancelNode::destroyPointer(nodePtr);
            }
        }
    }
}

- (void)propagateCancel {
    if ([self decrementObserverCount]) {
        [self requestCancel];
    }
}

- (void)seal {
    if ([self sealObserverCount]) {
        [self requestCancel];
    }
}

- (NSString *)debugDescription {
    NSInteger callbackCount = CallbackNode::countNodes(self.callbackList);
    NSInteger requestCancelCount = RequestCancelNode::countNodes(self.requestCancelLinkedList);
    auto describe = [](NSInteger count) -> NSString * _Nonnull {
        return [NSString stringWithFormat:@"%ld node%@", (long)count, count == 1 ? @"" : @"s"];
    };
    NSString *stateName;
    switch (self.unfencedState) {
        case TWLPromiseBoxStateDelayed: stateName = @"delayed"; break;
        case TWLPromiseBoxStateEmpty: stateName = @"empty"; break;
        case TWLPromiseBoxStateResolving: stateName = @"resolving"; break;
        case TWLPromiseBoxStateResolved: stateName = @"resolved"; break;
        case TWLPromiseBoxStateCancelling: stateName = @"cancelling"; break;
        case TWLPromiseBoxStateCancelled: stateName = @"cancelled"; break;
    }
    uint64_t flaggedCount = self.flaggedObserverCount;
    uint64_t observerCount = flaggedCount & ~((uint64_t)3 << 62);
    uint64_t sealed = (flaggedCount & ((uint64_t)1 << 63)) == 0;
    return [NSString stringWithFormat:@"<%@: %p state=%@ callbackList=%@ requestCancelList=%@ observerCount=%llu%@>", NSStringFromClass([self class]), self, stateName, describe(callbackCount), describe(requestCancelCount), (unsigned long long)observerCount, sealed ? @" sealed" : @""];
}

- (void)dealloc {
    if (auto nodePtr = CallbackNode::castPointer([self swapCallbackLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
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
    if (auto nodePtr = RequestCancelNode::castPointer([self swapRequestCancelLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
        // NB: We can't fire these callbacks because they take a TWLResolver and we can't have them
        // resurrecting ourselves. We could work around this, but the only reason to even have these
        // callbacks at this point is if the promise handler drops the last reference to the
        // resolver, and since that means it's a buggy implementation, we don't need to support it.
        RequestCancelNode::destroyPointer(nodePtr);
    }
}

@end

@implementation TWLThreadDictionaryKey {
    NSString * _Nonnull _description;
}

- (instancetype)initWithDescription:(NSString *)description {
    if ((self = [super init])) {
        _description = [description copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p %@>", NSStringFromClass([self class]), self, _description];
}

@end
