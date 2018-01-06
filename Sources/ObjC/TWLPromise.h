//
//  TWLPromise.h
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

#import <Foundation/Foundation.h>
#import <Tomorrowland/TWLDefines.h>

#if __cplusplus
#include <utility>
#include <tuple>
#endif

@class TWLContext;
@class TWLResolver<ValueType,ErrorType>;
@class TWLInvalidationToken;

#define TWL_WARN_UNUSED_RESULT __attribute__((warn_unused_result))

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
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)then:(void (^)(ValueType value))handler;
/// Registers a callback that is invoked when the promise is fulfilled.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)thenOnContext:(TWLContext *)context handler:(void (^)(ValueType value))handler NS_SWIFT_NAME(then(on:_:));
/// Registers a callback that is invoked when the promise is fulfilled.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)thenOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ValueType value))handler NS_SWIFT_NAME(then(on:token:_:));

/// Registers a callback that is invoked when the promise is fulfilled.
///
/// If the receiver is fulfilled, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must use \c
/// -mapOnContext:options:handler and pass the \c TWLPromiseOptionsEnforceContext option.
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
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must use \c
/// -mapOnContext:options:handler and pass the \c TWLPromiseOptionsEnforceContext option.
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
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must use \c
/// -mapOnContext:token:options:handler and pass the \c TWLPromiseOptionsEnforceContext option.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked. If the promise is fulfilled and the token
/// is invalidated, the returned promise will be cancelled.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is rejected or cancelled, the returned promise will also be rejected or cancelled.
- (TWLPromise *)mapOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:token:_:)) TWL_WARN_UNUSED_RESULT;
/// Registers a callback that is invoked when the promise is fulfilled.
///
/// If the receiver is fulfilled, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must pass the \c
/// TWLPromiseOptionsEnforceContext option.
///
/// \param context The context to invoke the callback on.
/// \param options Options which affect the cancellation and invalidation behavior of the returned
/// <tt>TWLPromise</tt>.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is rejected or cancelled, the returned promise will also be rejected or cancelled.
- (TWLPromise *)mapOnContext:(TWLContext *)context options:(TWLPromiseOptions)options handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:options:_:)) TWL_WARN_UNUSED_RESULT;
/// Registers a callback that is invoked when the promise is fulfilled.
///
/// If the receiver is fulfilled, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must pass the \c
/// TWLPromiseOptionsEnforceContext option.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked. If the promise is fulfilled and the token
/// is invalidated, the returned promise will be cancelled.
/// \param options Options which affect the cancellation and invalidation behavior of the returned
/// <tt>TWLPromise</tt>.
/// \param handler The callback that is invoked with the fulfilled value.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is rejected or cancelled, the returned promise will also be rejected or cancelled.
- (TWLPromise *)mapOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:token:options:_:)) TWL_WARN_UNUSED_RESULT;

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
/// \returns The same promise this method was invoked on. In most cases you should ignore the return
/// value, it's mainly provided so you can call \c -inspect: or \c -always: on it.
- (TWLPromise<ValueType,ErrorType> *)catch:(void (^)(ErrorType error))handler;
/// Registers a callback that is invoked when the promise is rejected.
///
/// This method (or <tt>-inspect:</tt>) should be used to terminate a promise chain in order to
/// ensure errors are handled.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the rejected error.
/// \returns The same promise this method was invoked on. In most cases you should ignore the return
/// value, it's mainly provided so you can call \c -inspect: or \c -always: on it.
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
/// \returns The same promise this method was invoked on. In most cases you should ignore the return
/// value, it's mainly provided so you can call \c -inspect: or \c -always: on it.
- (TWLPromise<ValueType,ErrorType> *)catchOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ErrorType error))handler NS_SWIFT_NAME(catch(on:token:_:));

/// Registers a callback that is invoked when the promise is rejected.
///
/// If the receiver is rejected, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must use \c
/// -recoverOnContext:token:handler: and pass the \c TWLPromiseOptionsEnforceContext option.
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
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must use \c
/// -recoverOnContext:token:handler: and pass the \c TWLPromiseOptionsEnforceContext option.
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
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must pass the \c
/// TWLPromiseOptionsEnforceContext option.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked. If the promise is rejected and the token
/// is invalidated, the returned promise will be cancelled.
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is fulfilled or cancelled, the returned promise will also be fulfilled or cancelled.
- (TWLPromise *)recoverOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:token:_:)) TWL_WARN_UNUSED_RESULT;
/// Registers a callback that is invoked when the promise is rejected.
///
/// If the receiver is rejected, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must use \c
/// -recoverOnContext:token:options:handler: and pass the \c TWLPromiseOptionsEnforceContext option.
///
/// \param context The context to invoke the callback on.
/// \param options Options which affect the cancellation and invalidation behavior of the returned
/// <tt>TWLPromise</tt>.
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is fulfilled or cancelled, the returned promise will also be fulfilled or cancelled.
- (TWLPromise *)recoverOnContext:(TWLContext *)context options:(TWLPromiseOptions)options handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:options:_:)) TWL_WARN_UNUSED_RESULT;
/// Registers a callback that is invoked when the promise is rejected.
///
/// If the receiver is rejected, the returned promise will be fulfilled using the result of the
/// handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// If \c handler is invoked and returns a <tt>TWLPromise</tt>, by default the returned promise will
/// be resolved immediately on the same context that the nested promise is resolved on. If you want
/// to ensure the returned promise resolves on \a context then you must pass the \c
/// TWLPromiseOptionsEnforceContext option.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked. If the promise is rejected and the token
/// is invalidated, the returned promise will be cancelled.
/// \param options Options which affect the cancellation and invalidation behavior of the returned
/// <tt>TWLPromise</tt>.
/// \param handler The callback that is invoked with the rejected error.
/// \returns A new promise that will be fulfilled with the return value of \a handler. If the
/// receiver is fulfilled or cancelled, the returned promise will also be fulfilled or cancelled.
- (TWLPromise *)recoverOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:token:options:_:)) TWL_WARN_UNUSED_RESULT;

/// Registers a callback that will be invoked with the promise result, no matter what it is.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -inspectOnContext:handler: instead.
///
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)inspect:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler;
/// Registers a callback that will be invoked with the promise result, no matter what it is.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)inspectOnContext:(TWLContext *)context handler:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(inspect(on:_:));
/// Registers a callback that will be invoked with the promise result, no matter what it is.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)inspectOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(inspect(on:token:_:));

/// Registers a callback that will be invoked with the promise result, no matter what it is, and
/// returns a new promise to wait on.
///
/// When the receiver is resolved, the returned promise will be fulfilled using the result of
/// the handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// By default the returned promise will be resolved immediately on the same context that the nested
/// promise is resolved on. If you want to ensure the returned promise resolves on \a context then
/// you must use \c -alwaysOnContext:token:handler: and pass the \c TWLPromiseOptionsEnforceContext
/// option.
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
/// \warning
/// By default the returned promise will be resolved immediately on the same context that the nested
/// promise is resolved on. If you want to ensure the returned promise resolves on \a context then
/// you must use \c -alwaysOnContext:token:handler: and pass the \c TWLPromiseOptionsEnforceContext
/// option.
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
/// \warning
/// By default the returned promise will be resolved immediately on the same context that the nested
/// promise is resolved on. If you want to ensure the returned promise resolves on \a context then
/// you must pass the \c TWLPromiseOptionsEnforceContext option.
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
/// Registers a callback that will be invoked with the promise result, no matter what it is, and
/// returns a new promise to wait on.
///
/// When the receiver is resolved, the returned promise will be fulfilled using the result of
/// the handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// By default the returned promise will be resolved immediately on the same context that the nested
/// promise is resolved on. If you want to ensure the returned promise resolves on \a context then
/// you must use \c -alwaysOnContext:token:options:handler: and pass the \c
/// TWLPromiseOptionsEnforceContext option.
///
/// \param context The context to invoke the callback on.
/// \param options Options which affect the cancellation and invalidation behavior of the returned
/// <tt>TWLPromise</tt>.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns A new promise that is resolved with the promise returned by \a handler.
- (TWLPromise *)alwaysOnContext:(TWLContext*)context options:(TWLPromiseOptions)options handler:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(always(on:options:_:)) TWL_WARN_UNUSED_RESULT;
/// Registers a callback that will be invoked with the promise result, no matter what it is, and
/// returns a new promise to wait on.
///
/// When the receiver is resolved, the returned promise will be fulfilled using the result of
/// the handler. If the handler returns a <tt>TWLPromise</tt>, the returned promise will instead be
/// resolved using the result of that nested promise.
///
/// \warning
/// By default the returned promise will be resolved immediately on the same context that the nested
/// promise is resolved on. If you want to ensure the returned promise resolves on \a context then
/// you must pass the \c TWLPromiseOptionsEnforceContext option.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked and will cause the returned promise to be
/// cancelled.
/// \param options Options which affect the cancellation and invalidation behavior of the returned
/// <tt>TWLPromise</tt>.
/// \param handler The callback that is invoked with the promise's result. The first parameter is
/// the fulfilled value, the second is the rejected error. If both are \c nil then the promise was
/// cancelled.
/// \returns A new promise that is resolved with the promise returned by \a handler.
- (TWLPromise *)alwaysOnContext:(TWLContext*)context token:(nullable TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(always(on:token:options:_:)) TWL_WARN_UNUSED_RESULT;

/// Registers a callback that will be invoked when the promise is cancelled.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -whenCancelledOnContext:handler: instead.
///
/// \param handler The callback that is invoked when the promise is cancelled.
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)whenCancelled:(void (^)(void))handler NS_SWIFT_NAME(onCancel(_:));
/// Registers a callback that will be invoked when the promise is cancelled.
///
/// \param context The context to invoke the callback on.
/// \param handler The callback that is invoked when the promise is cancelled.
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)whenCancelledOnContext:(TWLContext *)context handler:(void (^)(void))handler NS_SWIFT_NAME(onCancel(on:_:));
/// Registers a callback that will be invoked when the promise is cancelled.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a handler from being invoked.
/// \param handler The callback that is invoked when the promise is cancelled.
/// \returns The same promise this method was invoked on.
- (TWLPromise<ValueType,ErrorType> *)whenCancelledOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(void))handler NS_SWIFT_NAME(onCancel(on:token:_:));

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

/// Returns a new promise that adopts the value of the receiver but ignores cancel requests.
///
/// This is primarily useful when returning a nested promise in a callback handler in order to
/// unlink cancellation of the outer promise with the inner one.
///
/// \note The returned promise will still be cancelled if its parent promise is cancelled.
- (TWLPromise<ValueType,ErrorType> *)ignoringCancel TWL_WARN_UNUSED_RESULT;

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
- (void)resolveWithValue:(nullable ValueType)value error:(nullable ValueType)error;

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

@end

NS_ASSUME_NONNULL_END
