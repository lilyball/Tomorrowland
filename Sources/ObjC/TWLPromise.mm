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
#import "TWLPromiseInvalidationTokenBox.h"
#import <objc/runtime.h>
#import "objc_cast.h"

@interface TWLResolver<ValueType,ErrorType> () {
@public
    TWLObjCPromiseBox<ValueType,ErrorType> * _Nonnull _box;
}
@end

@interface TWLInvalidationToken (Private)
@property (atomic, readonly) TWLPromiseInvalidationTokenBox *box;
@end

@interface TWLPromiseInvalidationTokenBox (Private)
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
        [context executeIsSynchronous:YES block:^{
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
    auto tokenBox = token.box;
    auto generation = tokenBox.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(id), BOOL isSynchronous){
        if (value) {
            [context executeIsSynchronous:isSynchronous block:^{
                auto handler = oneshot();
                if (!tokenBox || generation == tokenBox.generation) {
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
    auto tokenBox = token.box;
    auto generation = tokenBox.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, id (^(^oneshot)(void))(id), BOOL isSynchronous){
        if (value) {
            [context executeIsSynchronous:isSynchronous block:^{
                auto handler = oneshot();
                if (tokenBox && generation != tokenBox.generation) {
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
    auto tokenBox = token.box;
    auto generation = tokenBox.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(id), BOOL isSynchronous){
        if (value) {
            [resolver fulfillWithValue:value];
        } else if (error) {
            [context executeIsSynchronous:isSynchronous block:^{
                auto handler = oneshot();
                if (!tokenBox || generation == tokenBox.generation) {
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
    auto tokenBox = token.box;
    auto generation = tokenBox.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, id (^(^oneshot)(void))(id), BOOL isSynchronous){
        if (value) {
            [resolver fulfillWithValue:value];
        } else if (error) {
            [context executeIsSynchronous:isSynchronous block:^{
                auto handler = oneshot();
                if (tokenBox && generation != tokenBox.generation) {
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
    auto tokenBox = token.box;
    auto generation = tokenBox.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(id,id), BOOL isSynchronous){
        [context executeIsSynchronous:isSynchronous block:^{
            auto handler = oneshot();
            if (!tokenBox || generation == tokenBox.generation) {
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
    auto tokenBox = token.box;
    auto generation = tokenBox.generation;
    enqueueCallback(self, YES, handler, ^(id _Nullable value, id _Nullable error, TWLPromise *(^(^oneshot)(void))(id,id), BOOL isSynchronous){
        [context executeIsSynchronous:isSynchronous block:^{
            auto handler = oneshot();
            if (tokenBox && generation != tokenBox.generation) {
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
    auto tokenBox = token.box;
    auto generation = tokenBox.generation;
    enqueueCallback(self, NO, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(id,id), BOOL isSynchronous){
        [context executeIsSynchronous:isSynchronous block:^{
            auto handler = oneshot();
            if (!tokenBox || generation == tokenBox.generation) {
                handler(value, error);
            }
        }];
    });
    return self;
}

- (TWLPromise *)tap {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    [self enqueueCallbackWithBox:resolver->_box willPropagateCancel:NO];
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
    auto tokenBox = token.box;
    auto generation = tokenBox.generation;
    enqueueCallback(self, NO, handler, ^(id _Nullable value, id _Nullable error, void (^(^oneshot)(void))(void), BOOL isSynchronous){
        if (value) {
            [resolver fulfillWithValue:value];
        } else if (error) {
            [resolver rejectWithError:error];
        } else {
            [context executeIsSynchronous:isSynchronous block:^{
                auto handler = oneshot();
                if (!tokenBox || generation == tokenBox.generation) {
                    handler();
                }
                [resolver cancel];
            }];
        }
    });
    __weak TWLObjCPromiseBox *box = _box;
    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
        // We told the parent that we weren't going to propagate cancellation, in order to prevent
        // whenCancelled from interfering with cancellation of other children. But if cancellation
        // of whenCancelled is requested, we want to behave as though we did mark ourselves as
        // propagating cancellation. We can do that by incrementing the observer count now. This is
        // safe to do even if the parent has resolved as propagating cancellation at that point does
        // nothing.
        TWLObjCPromiseBox *strongBox = box;
        [strongBox incrementObserverCount];
        [strongBox propagateCancel];
    }];
    return promise;
}

- (TWLPromise *)propagatingCancellationOnContext:(TWLContext *)context cancelRequestedHandler:(void (^)(TWLPromise<id,id> *promise))cancelRequested {
    TWLResolver *resolver;
    auto promise = [[TWLPromise alloc] initWithResolver:&resolver];
    [self enqueueCallbackWithBox:resolver->_box willPropagateCancel:YES];
    // Replicate the "oneshot" behavior from enqueueCallback, as -whenCancelRequestedOnContext: does not have this same behavior.
    void (__block ^ _Nullable oneshotValue)(TWLPromise *) = cancelRequested;
    auto oneshot = ^{
        auto value = oneshotValue;
        oneshotValue = nil;
        return value;
    };
    __weak TWLObjCPromiseBox *box = _box;
    [resolver whenCancelRequestedOnContext:context handler:^(TWLResolver * _Nonnull resolver) {
        // Retaining promise in its own callback will keep it alive until it's resolved. This is
        // safe because our box is kept alive by the parent promise until it's resolved, and the
        // seal doesn't matter as we already sealed it.
        oneshot()(promise);
        [box propagateCancel];
    }];
    // Seal the promise now. This allows cancellation propagation.
    [promise->_box seal];
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
    // NB: We don't need an autorelease pool here because objc_getAssociatedObject only autoreleases
    // the returned value when using an atomic association policy, and we're using a nonatomic one.
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
    [self enqueueCallbackWithBox:resolver->_box willPropagateCancel:YES];
    return promise;
}

- (id<TWLCancellable>)cancellable {
    return _box;
}

#pragma mark - Private

- (void)enqueueCallbackWithoutOneshot:(void (^)(id _Nullable value, id _Nullable error, BOOL isSynchronous))callback
                  willPropagateCancel:(BOOL)willPropagateCancel
{
    _enqueue(_box, willPropagateCancel, callback);
}

- (void)enqueueCallbackWithBox:(TWLObjCPromiseBox *)box willPropagateCancel:(BOOL)willPropagateCancel {
    _enqueue(_box, willPropagateCancel, box);
}

- (void)pipeToResolver:(nonnull TWLResolver *)resolver {
    [self enqueueCallbackWithBox:resolver->_box willPropagateCancel:YES];
    propagateCancellation(resolver, self);
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
        struct Value {
            using Callback = void (^ _Nonnull)(id _Nullable value, id _Nullable error, BOOL isSynchronous);
            // Note: Can't use std::variant because it has minimum OS restrictions.
            union {
                Callback callback;
                TWLObjCPromiseBox * _Nonnull box;
            };
            enum{CALLBACK, BOX} tag;
            
            Value(Callback callback) : callback{callback}, tag{CALLBACK} {}
            Value(TWLObjCPromiseBox * _Nonnull box) : box{box}, tag{BOX} {}
            Value(const Value& value) : tag{value.tag} {
                switch (tag) {
                    case CALLBACK: new(&callback) auto(value.callback); break;
                    case BOX: new(&box) auto(value.box); break;
                }
            }
            
            ~Value() {
                switch (tag) {
                    case CALLBACK: callback.~Callback(); break;
                    case BOX: box.~decltype(box)(); break;
                }
            }
        };
        
        Value value;
        
        CallbackNode(Value value) : LinkedListNode(), value{value} {}
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
                [this->context executeIsSynchronous:NO block:^{
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
    
    void _enqueue(TWLObjCPromiseBox * _Nonnull box, BOOL willPropagateCancel, CallbackNode::Value value) {
        if (willPropagateCancel) {
            // If the subsequent swap fails, that means we've already resolved (or started resolving)
            // the promise, so the observer count modification is harmless.
            [box incrementObserverCount];
        }
        
        auto nodePtr = new CallbackNode(value);
        if ([box swapCallbackLinkedListWith:reinterpret_cast<void *>(nodePtr) linkBlock:^(void * _Nullable nextNode) {
            nodePtr->next = reinterpret_cast<CallbackNode *>(nextNode);
        }] == TWLLinkedListSwapFailed) {
            delete nodePtr;
            switch (box.state) {
                case TWLPromiseBoxStateResolved:
                case TWLPromiseBoxStateCancelled:
                    break;
                case TWLPromiseBoxStateDelayed:
                case TWLPromiseBoxStateEmpty:
                case TWLPromiseBoxStateResolving:
                case TWLPromiseBoxStateCancelling:
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"TWLPromise callback list empty but state isn't actually resolved" userInfo:nil];
            }
            switch (value.tag) {
                case CallbackNode::Value::CALLBACK: value.callback(box->_value, box->_error, YES); break;
                case CallbackNode::Value::BOX: [value.box resolveOrCancelWithValue:box->_value error:box->_error]; break;
            }
        }
    }
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
                [context executeIsSynchronous:YES block:^{
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

- (BOOL)cancelRequested {
    switch (_box.unfencedState) {
        case TWLPromiseBoxStateCancelling:
        case TWLPromiseBoxStateCancelled:
            return YES;
        case TWLPromiseBoxStateDelayed:
        case TWLPromiseBoxStateEmpty:
        case TWLPromiseBoxStateResolving:
        case TWLPromiseBoxStateResolved:
            return NO;
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
    auto nodePtr = [self markResolvedOrCancelledWithValue:value error:error];
    if (!nodePtr) return;
    nodePtr = CallbackNode::reverseList(nodePtr);
    @try {
        for (auto current = nodePtr; current; current = current->next) {
            switch (current->value.tag) {
                case CallbackNode::Value::CALLBACK:
                    current->value.callback(value, error, NO);
                    break;
                case CallbackNode::Value::BOX:
                    // Transition the nested box by hand and stitch its callbacks into ours
                    if (auto boxNodePtr = [current->value.box markResolvedOrCancelledWithValue:value error:error]) {
                        auto tailPtr = boxNodePtr; // this becomes the tail after we reverse it
                        boxNodePtr = CallbackNode::reverseList(boxNodePtr);
                        NSAssert(tailPtr->next == nullptr, @"Reversed list tail has next pointer");
                        tailPtr->next = current->next;
                        current->next = boxNodePtr;
                        // current->next now points to the box's nodes, and chains back into the rest of our list
                    }
            }
        }
    } @finally {
        CallbackNode::destroyPointer(nodePtr);
    }
}

- (nullable CallbackNode *)markResolvedOrCancelledWithValue:(nullable id)value error:(nullable id)error {
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
    return NULL;
    
handleCallbacks:
    if (auto nodePtr = RequestCancelNode::castPointer([self swapRequestCancelLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil])) {
        RequestCancelNode::destroyPointer(nodePtr);
    }
    return CallbackNode::castPointer([self swapCallbackLinkedListWith:TWLLinkedListSwapFailed linkBlock:nil]);
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
    // If we haven't been resolved yet, we should inform all our callbacks that we've cancelled.
    // This will do nothing if we've already resolved.
    [self resolveOrCancelWithValue:nil error:nil];
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
