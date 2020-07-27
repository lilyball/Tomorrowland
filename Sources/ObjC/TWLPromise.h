//
//  TWLPromise.h
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

#import <Foundation/Foundation.h>

#if __cplusplus
#include <utility>
#include <tuple>
#endif

@class TWLContext;
@class TWLResolver<ValueType,ErrorType>;
@class TWLInvalidationToken;

@protocol TWLCancellable;

#ifndef TWL_WARN_UNUSED_RESULT
#define TWL_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#endif

NS_ASSUME_NONNULL_BEGIN

/// A \c TWLPromise is an object that will eventually hold a value or an error, and can invoke
/// callbacks when that happens.
///
/// Example usage:
///
/// \code
///return [[TWLPromise<NSData*,NSError*> newOnContext:TWLContext.immediate withBlock:^(TWLResolver<NSData*,NSError*> * _Nonnull resolver) {
///    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
///        if (data) {
///            [resolver fulfillWithValue:data];
///        } else if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
///            [resolver cancel];
///        } else {
///            [resolver rejectWithError:error];
///        }
///    }];
///    [resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver<NSData*,NSError*> * _Nonnull resolver) {
///        [task cancel];
///    ];
///    [task resume];
///}] map:^(NSData * _Nonnull data) {
///    UIImage *image = [UIImage imageWithData:data];
///    if (image) {
///        return image;
///    } else {
///        return [TWLPromise newRejectedWithError:[NSError errorWithDomain:LoadErrorDomain code:LoadErrorDataIsNotImage userInfo:nil]];
///    }
///}];
/// \endcode
///
/// Promises can also be cancelled. With a \c TWLPromise object you can invoke \c -requestCancel.
/// This is merely advisory; the promise does not have to actually implemented cancellation and may
/// resolve anyway. But if a promise does implement cancellation, it can then call
/// <tt>[resolver cancel]</tt>. Note that even if the promise supports cancellation, calling
/// \c -requestCancel on an unresolved promise does not guarantee that it will cancel, as the
/// promise may be in the process of resolving when that method is invoked. Make sure to use the
/// invalidation token support if you need to ensure your registered callbacks aren't invoked past a
/// certain point.
///
/// \note If a registered callback is invoked (or would have been invoked if no token was provided)
/// it is guaranteed to be released on the context. This is important if the callback captures a
/// value whose deallocation must occur on a specific thread (such as the main thread). If the
/// callback is not invoked (ignoring tokens) it will be released on whatever thread the promise was
/// resolved on. For example, if a promise is fulfilled, any callback registered with \c
/// -thenOnContext:handler: will be released on the context, but callbacks registered with \c
/// -catchOnContext:handler: will not. If you need to guarantee the thread that the callback is
/// released on, you should use \c -inspectOnContext:handler: or \c -alwaysOnContext:handler:.
NS_SWIFT_NAME(ObjCPromise)
@interface TWLPromise<__covariant ValueType, __covariant ErrorType> : NSObject

+ (instancetype)new NS_UNAVAILABLE;
/// Returns a new \c TWLPromise that will be resolved using the given block.
///
/// \param context The context to execute the handler on.
/// \param block A block that is executed in order to fulfill the promise.
+ (instancetype)newOnContext:(TWLContext *)context withBlock:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))block NS_SWIFT_UNAVAILABLE("Use init(on:_:)");
/// Returns a new \c TWLPromise that is already fulfilled with the given value.
+ (instancetype)newFulfilledWithValue:(ValueType)value NS_SWIFT_UNAVAILABLE("Use init(fulfilled:)");
/// Returns a new \c TWLPromise that is already rejected with the given error.
+ (instancetype)newRejectedWithError:(ErrorType)error NS_SWIFT_UNAVAILABLE("Use init(rejected:)");
/// Returns a new \c TWLPromise that is already cancelled.
+ (instancetype)newCancelled NS_SWIFT_NAME(makeCancelled());

#if __cplusplus
/// Returns a new \c TWLPromise along with a \c TWLPromiseResolver that can be used to fulfill that
/// promise.
///
/// \note In most cases you want to use \c +newOnContext:withBlock: intead.
+ (std::pair<TWLPromise<ValueType,ErrorType> *,TWLResolver<ValueType,ErrorType> *>)makePromiseWithResolver;
#endif

- (instancetype)init NS_UNAVAILABLE;
/// Returns a new \c TWLPromise that will be resolved using the given block.
///
/// \param context The context to execute the handler on.
/// \param block A block that is executed in order to fulfill the promise.
- (instancetype)initOnContext:(TWLContext *)context withBlock:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))block NS_SWIFT_NAME(init(on:_:)) NS_DESIGNATED_INITIALIZER;
/// Returns a new \c TWLPromise that is already fulfilled with the given value.
- (instancetype)initFulfilledWithValue:(ValueType)value NS_SWIFT_NAME(init(fulfilled:)) NS_DESIGNATED_INITIALIZER;
/// Returns a new \c TWLPromise that is already rejected with the given error.
- (instancetype)initRejectedWithError:(ErrorType)error NS_SWIFT_NAME(init(rejected:)) NS_DESIGNATED_INITIALIZER;
/// Returns a new \c TWLPromise that is already cancelled.
- (instancetype)initCancelled NS_SWIFT_UNAVAILABLE("Use .makeCancelled()") NS_DESIGNATED_INITIALIZER;

/// Returns a new \c TWLPromise along with a \c TWLPromiseResolver that can be used to fulfill that
/// promise.
///
/// \note In most cases you want to use \c +newOnContext:withBlock: intead.
///
/// \param[out] outResolver A pointer that will be filled in with a \c TWLResolver.
- (instancetype)initWithResolver:(TWLResolver<ValueType,ErrorType> * __strong _Nullable * _Nonnull)outResolver NS_DESIGNATED_INITIALIZER;

/// Registers a callback that is invoked when the promise is fulfilled.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -thenOnContext:handler: instead.
///
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)then:(void (^)(ValueType value))handler;
/// Registers a callback that is invoked when the promise is fulfilled.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)thenOnContext:(TWLContext *)context handler:(void (^)(ValueType value))handler NS_SWIFT_NAME(then(on:_:));
/// Registers a callback that is invoked when the promise is fulfilled.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)thenOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ValueType value))handler NS_SWIFT_NAME(then(on:token:_:));

/// Registers a callback that is invoked when the promise is fulfilled.
///
/// If the receiver is fulfilled, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -mapOnContext:handler: instead.
///
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is rejected or cancelled, the returned promise will also be rejected or cancelled.
- (TWLPromise *)map:(id (^)(ValueType value))handler TWL_WARN_UNUSED_RESULT;
/// Registers a callback that is invoked when the promise is fulfilled.
///
/// If the receiver is fulfilled, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is rejected or cancelled, the returned promise will also be rejected or cancelled.
- (TWLPromise *)mapOnContext:(TWLContext *)context handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:_:)) TWL_WARN_UNUSED_RESULT;
/// Registers a callback that is invoked when the promise is fulfilled.
///
/// If the receiver is fulfilled, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked. If the promise is fulfilled and the token
/// is invalidated, the returned promise will be cancelled.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is rejected or cancelled, the returned promise will also be rejected or cancelled.
- (TWLPromise *)mapOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:token:_:)) TWL_WARN_UNUSED_RESULT;

/// Registers a callback that is invoked when the promise is rejected.
///
/// This method (or <tt>-inspect:</tt>) should be used to terminate a promise chain in order to
/// ensure errors are handled.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -catchOnContext:handler: instead.
///
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)catch:(void (^)(ErrorType error))handler;
/// Registers a callback that is invoked when the promise is rejected.
///
/// This method (or <tt>-inspect:</tt>) should be used to terminate a promise chain in order to
/// ensure errors are handled.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)catchOnContext:(TWLContext *)context handler:(void (^)(ErrorType error))handler NS_SWIFT_NAME(catch(on:_:));
/// Registers a callback that is invoked when the promise is rejected.
///
/// This method (or <tt>-inspect:</tt>) should be used to terminate a promise chain in order to
/// ensure errors are handled.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked.
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)catchOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ErrorType error))handler NS_SWIFT_NAME(catch(on:token:_:));

/// Registers a callback that is invoked when the promise is rejected.
///
/// If the receiver is rejected, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -recoverOnContext:handler: instead.
///
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is fulfilled or cancelled, the returned promise will also be fulfilled or cancelled.
- (TWLPromise *)recover:(id (^)(ErrorType error))handler TWL_WARN_UNUSED_RESULT;
/// Registers a callback that is invoked when the promise is rejected.
///
/// If the receiver is rejected, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is fulfilled or cancelled, the returned promise will also be fulfilled or cancelled.
- (TWLPromise *)recoverOnContext:(TWLContext *)context handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:_:)) TWL_WARN_UNUSED_RESULT;
/// Registers a callback that is invoked when the promise is rejected.
///
/// If the receiver is rejected, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked. If the promise is rejected and the token
/// is invalidated, the returned promise will be cancelled.
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is fulfilled or cancelled, the returned promise will also be fulfilled or cancelled.
- (TWLPromise *)recoverOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:token:_:)) TWL_WARN_UNUSED_RESULT;

/// Registers a callback that will be invoked with the promise result, no matter what it is.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -inspectOnContext:handler: instead.
///
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)inspect:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler;
/// Registers a callback that will be invoked with the promise result, no matter what it is.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)inspectOnContext:(TWLContext *)context handler:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(inspect(on:_:));
/// Registers a callback that will be invoked with the promise result, no matter what it is.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)inspectOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(inspect(on:token:_:));

/// Registers a callback that will be invoked with the promise result, no matter what it is, and
/// returns a new promise to wait on.
///
/// When the receiver is resolved, the returned promise will be fulfilled using the result of
/// the handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -alwaysOnContext:handler: instead.
///
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns A new promise that is resolved with the promise returned by \a handler.
- (TWLPromise *)always:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler TWL_WARN_UNUSED_RESULT;
/// Registers a callback that will be invoked with the promise result, no matter what it is, and
/// returns a new promise to wait on.
///
/// When the receiver is resolved, the returned promise will be fulfilled using the result of
/// the handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns A new promise that is resolved with the promise returned by \a handler.
- (TWLPromise *)alwaysOnContext:(TWLContext *)context handler:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(always(on:_:)) TWL_WARN_UNUSED_RESULT;
/// Registers a callback that will be invoked with the promise result, no matter what it is, and
/// returns a new promise to wait on.
///
/// When the receiver is resolved, the returned promise will be fulfilled using the result of
/// the handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked and will cause the returned promise to be
/// cancelled.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns A new promise that is resolved with the promise returned by \a handler.
- (TWLPromise *)alwaysOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(always(on:token:_:)) TWL_WARN_UNUSED_RESULT;

/// Registers a callback that will be invoked when the promise is resolved without affecting
/// behavior.
///
/// This is similar to an \c -inspect callback except it doesn't create a new promise and instead
/// returns its receiver. This means it won't delay any chained callbacks and it won't affect
/// automatic cancellation propagation behavior.
///
/// This is similar to <tt>[[promise tap] always:…]</tt> except it can be inserted into any promise
/// chain without affecting the chain.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -tapOnContext:handler: instead.
///
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns The receiver.
///
/// \see -tap
- (TWLPromise<ValueType,ErrorType> *)tap:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler;
/// Registers a callback that will be invoked when the promise is resolved without affecting
/// behavior.
///
/// This is similar to an \c -inspect callback except it doesn't create a new promise and instead
/// returns its receiver. This means it won't delay any chained callbacks and it won't affect
/// automatic cancellation propagation behavior.
///
/// This is similar to <tt>[[promise tap] always:…]</tt> except it can be inserted into any promise
/// chain without affecting the chain.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns The receiver.
///
/// \see -tap
- (TWLPromise<ValueType,ErrorType> *)tapOnContext:(TWLContext *)context handler:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(tap(on:_:));
/// Registers a callback that will be invoked when the promise is resolved without affecting
/// behavior.
///
/// This is similar to an \c -inspect callback except it doesn't create a new promise and instead
/// returns its receiver. This means it won't delay any chained callbacks and it won't affect
/// automatic cancellation propagation behavior.
///
/// This is similar to <tt>[[promise tap] always:…]</tt> except it can be inserted into any promise
/// chain without affecting the chain.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns The receiver.
///
/// \see -tap
- (TWLPromise<ValueType,ErrorType> *)tapOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(tap(on:token:_:));

/// Returns a new promise that adopts the result of the receiver without affecting its behavior.
///
/// The returned promise will always resolve with the same value that its receiver does, but it
/// won't affect the timing of any of the receiver's other observers and it won't affect automatic
/// cancellation propagation behavior. Requesting cancellation of the returned promise does nothing.
///
/// <tt>[[promise tap] always:…]</tt> behaves the same as \c -tap: except it returns a new promise
/// whereas \c -tap: returns the receiver and can be inserted into any promise chain without
/// affecting the chain.
///
/// \returns A new \c TWLPromise that adopts the same result as the receiver. Requesting this new
/// promise to cancel does nothing.
///
/// \see -tapOnContext:token:handler:
- (TWLPromise<ValueType,ErrorType> *)tap;

/// Registers a callback that will be invoked when the promise is cancelled.
///
/// \note Like <code>-tap</code>, \c -whenCancelled does not prevent automatic cancellation
/// propagation if the parent has multiple children and all other children have requested
/// cancellation. Unlike <code>-tap</code>, requesting cancellation of \c -whenCancelled will cancel
/// the parent if the parent has no other children. <code>-whenCancelled</code>'s behavior differs
/// from the other standard obsrevers here as attaching a \c -whenCancelled observer to a promise
/// that would otherwise be cancelled should not prevent the cancellation.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -whenCancelledOnContext:handler: instead.
///
/// \param handler The callback that is invoked when the promise is cancelled.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)whenCancelled:(void (^)(void))handler NS_SWIFT_NAME(onCancel(_:));
/// Registers a callback that will be invoked when the promise is cancelled.
///
/// \note Like <code>-tap</code>, \c -whenCancelled does not prevent automatic cancellation
/// propagation if the parent has multiple children and all other children have requested
/// cancellation. Unlike <code>-tap</code>, requesting cancellation of \c -whenCancelled will cancel
/// the parent if the parent has no other children. <code>-whenCancelled</code>'s behavior differs
/// from the other standard obsrevers here as attaching a \c -whenCancelled observer to a promise
/// that would otherwise be cancelled should not prevent the cancellation.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked when the promise is cancelled.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)whenCancelledOnContext:(TWLContext *)context handler:(void (^)(void))handler NS_SWIFT_NAME(onCancel(on:_:));
/// Registers a callback that will be invoked when the promise is cancelled.
///
/// \note Like <code>-tap</code>, \c -whenCancelled does not prevent automatic cancellation
/// propagation if the parent has multiple children and all other children have requested
/// cancellation. Unlike <code>-tap</code>, requesting cancellation of \c -whenCancelled will cancel
/// the parent if the parent has no other children. <code>-whenCancelled</code>'s behavior differs
/// from the other standard obsrevers here as attaching a \c -whenCancelled observer to a promise
/// that would otherwise be cancelled should not prevent the cancellation.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked.
/// \param handler The callback that is invoked when the promise is cancelled.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)whenCancelledOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(void))handler NS_SWIFT_NAME(onCancel(on:token:_:));

/// Returns a promise that adopts the same value as the receiver, and propagates cancellation
/// from its children upwards even when it still exists.
///
/// Normally cancellation is only propagated from children upwards when the parent promise is no
/// longer held on to directly. This allows more children to be attached to the parent later,
/// and only after the parent has been dropped will cancellation requests from its children
/// propagate up to its own parent.
///
/// This method returns a promise that ignores that logic and propagates cancellation upwards
/// even while it still exists. As soon as all existing children have requested cancellation,
/// the cancellation request will propagate to the receiver. A callback is provided to allow you
/// to drop the returned promise at that point, so you don't try to attach new children.
///
/// The intent of this method is to allow you to deduplicate requests for a long-lived resource
/// (such as a network load) without preventing cancellation of the load in the event that no
/// children care about it anymore.
///
/// \param context The context to invoke the callback on.
/// \param cancelRequested The callback that is invoked when the promise is requested to cancel,
/// either because \c .requestCancel() was invoked on it directly or because all children have
/// requested cancellation. This callback is executed immediately prior to the cancellation request
/// being propagated to the receiver. The argument to the callback is the same promise that's
/// returned from this method.
/// \returns A new promise that will resolve to the same value as the receiver.
- (TWLPromise<ValueType,ErrorType> *)propagatingCancellationOnContext:(TWLContext *)context cancelRequestedHandler:(void (^)(TWLPromise<ValueType,ErrorType> *promise))cancelRequested NS_SWIFT_NAME(propagatingCancellation(on:cancelRequested:));

/// Returns a promise that adopts the same value as the receiver.
///
/// This method is used in order to hand back child promises to callers so that they cannot directly
/// request cancellation of a shared parent promise. This is most useful in conjunction with
/// \c -propagatingCancellationOnContext:cancelRequestedHandler: but could also be used any time a
/// shared promise is given to multiple callers.
///
/// \returns A new promise that will resolve to the same value as the receiver.
- (TWLPromise<ValueType,ErrorType> *)makeChild;

/// Returns the promise's value if it's already been resolved.
///
/// If the return value is \c YES and both \a *outValue and \a *outError are \c nil this means the
/// promise was cancelled.
///
/// \note If the promise has not been resolved yet, \a outValue and \a outError are unmodified.
///
/// \param outValue A pointer that is filled in with the value if the promise has been fulfilled,
///        otherwise \c nil. This pointer may be \c NULL.
/// \param outError A pointer that is filled in with the error if the promise has been rejected,
///        otherwise \c nil. This pointer may be \c NULL.
/// \returns \c YES if the promise has been resolved, otherwise \c NO.
- (BOOL)getValue:(ValueType __strong _Nullable * _Nullable)outValue error:(ErrorType __strong _Nullable * _Nullable)outError;

#if __cplusplus
/// Returns the promise's result if it's already been resolved.
///
/// \returns A tuple where the first element is whether the promise has been resolved, the second is
/// the value (if any), and the third is the error (if any). If the promise hasn't been resolved,
/// returns \c (NO,nil,nil). If the promise has been cancelled, returns \c (YES,nil,nil).
@property (atomic, readonly) std::tuple<BOOL,ValueType _Nullable,ErrorType _Nullable> result;
#endif

/// Requests that the promise should be cancelled.
///
/// If the promise is already resolved, this does nothing. Otherwise, if the promise registers any
/// \c -whenCancelRequestedOnContext:handler: handlers, those handlers will be called.
///
/// \note Requesting that a promise should be cancelled doesn't guarantee it will be. If you need to
/// ensure your \c -then: block isn't invoked, also use a \c TWLInvalidationToken and call \c
/// -invalidate on it.
- (void)requestCancel;

/// Requests that the promise should be cancelled when the token is invalidated.
///
/// This is equivalent to calling \c -requestCancelOnInvalidate: on the token and is intended to be
/// used to terminate a promise chain. For example:
///
///\code
///[[[[urlSession promiseDataTaskForURL:url] thenOnContext:TWLContext.automatic token:token handler:^(NSData * _Nonnull data) {
///    …
///] catchOnContext:TWLContext.automatic token:token handler:^(NSError * _Nonnull error) {
///    …
///] requestCancelOnInvalidate:token];
///\endcode
///
/// \param token A <tt>TWLInvalidationToken</tt>. When the token is invalidated the receiver will be
/// requested to cancel.
/// \returns The receiver. This value can be ignored.
- (TWLPromise<ValueType,ErrorType> *)requestCancelOnInvalidate:(TWLInvalidationToken *)token;

/// Requests that the promise should be cancelled when the object deallocates.
///
/// This is equivalent to having the object hold a \c TWLInvalidationToken in a property (configured
/// to invalidate on dealloc) and requesting the promise cancel on that token.
///
/// \param object Any object. When the object deallocates the receiver will be requested to cancel.
/// \returns The receiver. This value can be ignored.
- (TWLPromise<ValueType,ErrorType> *)requestCancelOnDealloc:(id)object;

/// Returns a new promise that adopts the value of the receiver but ignores cancel requests.
///
/// This is primarily useful when returning a nested promise in a callback handler in order to
/// unlink cancellation of the outer promise with the inner one.
///
/// \note The returned promise will still be cancelled if its parent promise is cancelled.
- (TWLPromise<ValueType,ErrorType> *)ignoringCancel TWL_WARN_UNUSED_RESULT;

/// Returns an object that can be used to request cancellation of this promise.
///
/// You should use this property instead of holding a weak reference to the \c TWLPromise as the \c
/// TWLPromise object can deallocate before the promise has actually resolved. The return value of
/// \a cancellable will stay alive until the promise ha resolved and notified all of its observers.
///
/// You should hold onto the cancellable object weakly. For example:
///
///\code
///__weak id<TWLCancellable> cancellable = promise.cancellable;
///[resolver whenCancelRequestedOnContext:TWLContext.immediate handler:^(TWLResolver * _Nonnull resolver) {
///    [cancellable requestCancel];
///}];
///\endcode
@property (atomic, readonly, nonnull) id<TWLCancellable> cancellable;

@end

/// A \c TWLResolver is used to fulfill, reject, or cancel its associated <tt>TWLPromise</tt>.
@interface TWLResolver<__contravariant ValueType, __contravariant ErrorType> : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/// Fulfills the promise with the given value.
///
/// If the promise has already been resolved or cancelled, this does nothing.
- (void)fulfillWithValue:(ValueType)value NS_SWIFT_NAME(fulfill(with:));
/// Rejects the promise with the given error.
///
/// If the promise has already been resolved or canelled, this does nothing.
- (void)rejectWithError:(ErrorType)error NS_SWIFT_NAME(reject(with:));
/// Cancels the promise.
///
/// If the promise has already been resolved or cancelled, this does nothing.
- (void)cancel;

/// Resolves the promise with the given value or error.
///
/// If both \a value and \a error are \c nil the promise is cancelled.
///
/// If the promise has already been resolved or cancelled, this does nothing.
- (void)resolveWithValue:(nullable ValueType)value error:(nullable ErrorType)error;

/// Resolves the promise with another promise.
///
/// If \a promise has already been resolved, the receiver will be resolved immediately. Otherwise
/// the receiver will wait until \a promise is resolved and resolve to the same result.
///
/// If the receiver is cancelled, it will also propagate the cancellation to \a promise the same way
/// that a child promise does. If this is not desired, then either use
/// <code>[resolver resolveWithPromise:[promise ignoringCancel]]</code> or add an \c -inspect:
/// observer and resolve manually.
- (void)resolveWithPromise:(nonnull TWLPromise<ValueType,ErrorType> *)promise;

/// Registers a block that will be invoked if \c -requestCancel is invoked on the promise before the
/// promise is resolved.
///
/// If the promise has already had cancellation requested (and is not resolved), the callback is
/// invoked on the context at once.
///
/// \note If you register the callback for a serial queue and resolve the promise on that same
/// serial queue, the callback is guaranted to not execute after the promise is resolved.
///
/// \param context The context that the callback is invoked on.
/// \param handler The callback to invoke.
- (void)whenCancelRequestedOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))handler NS_SWIFT_NAME(onRequestCancel(on:_:));

/// Returns whether the promise has already been requested to cancel.
///
/// This can be used when a promise init method does long-running work that can't easily be
/// interrupted with a \c whenCancelRequested handler.
@property (atomic, readonly) BOOL cancelRequested;

/// Convenience method for handling framework callbacks.
///
/// This method returns a block that can be passed to a framework method as a callback in order to
/// resolve the promise. For example:
///
///\code
///[geocoder reverseGeocodeLocation:location completionHandler:[resolver handleCallback]];
///\endcode
///
/// If both \a value and \a error passed to the block are \c nil the promise is rejected with
/// <tt>TWLPromiseCallbackErrorAPIMismatch</tt>. If they're both non-<tt>nil</tt> this should be
/// considered an error, but the promise will be fulfilled with the value and the error will be
/// ignored.
///
/// \seealso -handleCallback
- (void (^)(ValueType _Nullable value, ErrorType _Nullable error))handleCallback;

/// Convenience method for handling framework callbacks.
///
/// This method returns a block that can be passed to a framework method as a callback in order to
/// resolve the promise. It takes a block that can be used to determine when the error represents
/// cancellation. For example:
///
///\code
///[geocoder reverseGeocodeLocation:location completionHandler:[resolver handleCallbackWithCancelPredicate:^(NSError * _Nonnull error) {
///    return [error.domain isEqualToString:kCLErrorDomain] && error.code == kCLErrorGeocodeCanceled;
///}]];
///\endcode
///
/// If both \a value and \a error passed to the block are \c nil the promise is rejected with
/// <tt>TWLPromiseCallbackErrorAPIMismatch</tt>. If they're both non-<tt>nil</tt> this should be
/// considered an error, but the promise will be fulfilled with the value and the error will be
/// ignored.
///
/// \param predicate A block that is executed if the framework method returns an error. If the
/// predicate returns \c YES the promise is cancelled instead of rejected.
/// \returns A block that can be passed to a framework method as a callback.
///
/// \seealso -handleCallback
- (void (^)(ValueType _Nullable value, ErrorType _Nullable error))handleCallbackWithCancelPredicate:(BOOL (^)(ErrorType _Nonnull error))predicate;

@end

/// A protocol that can be used to cancel a promise without holding onto the full promise.
///
/// This protocol is used by the return type of \c TWLPromise.cancellable and should always be used
/// instead of holding onto the promise weakly. This allows you to cancel a promise without
/// interfering with automatic cancel propagation.
///
/// This protocol should be held weakly.
@protocol TWLCancellable <NSObject>
/// Requests cancellation of the promise this \c TWLCancellable was created from.
- (void)requestCancel;
@end

NS_ASSUME_NONNULL_END
