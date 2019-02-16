//
//  TWLUtilities.h
//  Tomorrowland
//
//  Created by Lily Ballard on 1/5/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>
#import <Tomorrowland/TWLPromise.h>

@class TWLContext;
@class TWLTimeoutError<Wrapped>;

#ifndef TWL_WARN_UNUSED_RESULT
#define TWL_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#endif

NS_ASSUME_NONNULL_BEGIN

@interface TWLPromise<ValueType,ErrorType> (Utilities)

/// Returns a new \c TWLPromise that fulfills with the given value after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// This can be used as a sort of cancellable timer. It can also be used in conjunction with \c
/// +race:cancelRemaining: to implement a timeout that fulfills with a given value on timeout
/// instead of rejecting with a \c TWLTimeoutError.
///
/// \note The promise will be resolved using the \c .automatic context, which evaluates to \c .main
/// when invoked on the main thread, otherwise <tt>.default</tt>. See \c
/// +newFulfilledOnContext:withValue:afterDelay: to specify a different context.
///
/// \param value The value the promise will be fulfilled with.
/// \param delay The number of seconds to delay the promise by.
+ (instancetype)newFulfilledWithValue:(ValueType)value afterDelay:(NSTimeInterval)delay NS_SWIFT_UNAVAILABLE("Use init(fulfilled:after:)") TWL_WARN_UNUSED_RESULT;

/// Returns a new \c TWLPromise that fulfills with the given value after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// This can be used as a sort of cancellable timer. It can also be used in conjunction with \c
/// +race:cancelRemaining: to implement a timeout that fulfills with a given value on timeout
/// instead of rejecting with a <tt>TWLTimeoutError</tt>.
///
/// \param context The context to resolve the \c TWLPromise on. This is generally only important
/// when using callbacks registered with <tt>.immediate</tt>. If provided as \c +operationQueue: it
/// enqueues an operation on the operation queue immediately that becomes ready once the delay has
/// elapsed.
/// \param value The value the promise will be fulfilled with.
/// \param delay The number of seconds to delay the promise by.
+ (instancetype)newFulfilledOnContext:(TWLContext *)context withValue:(ValueType)value afterDelay:(NSTimeInterval)delay NS_SWIFT_UNAVAILABLE("Use init(on:fulfilled:after:)") TWL_WARN_UNUSED_RESULT;

/// Returns a new \c TWLPromise that rejects with the given error after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// \note The promise will be resolved using the \c .automatic context, which evaluates to \c .main
/// when invoked on the main thread, otherwise <tt>.default</tt>. See \c
/// +newFulfilledOnContext:withValue:afterDelay: to specify a different context.
///
/// \param error The error the promise will be rejected with.
/// \param delay The number of seconds to delay the promise by.
+ (instancetype)newRejectedWithError:(ErrorType)error afterDelay:(NSTimeInterval)delay NS_SWIFT_UNAVAILABLE("Use init(rejected:after:)") TWL_WARN_UNUSED_RESULT;

/// Returns a new \c TWLPromise that rejects with the given error after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// \param context The context to resolve the \c TWLPromise on. This is generally only important
/// when using callbacks registered with <tt>.immediate</tt>. If provided as \c +operationQueue: it
/// enqueues an operation on the operation queue immediately that becomes ready once the delay has
/// elapsed.
/// \param error The error the promise will be rejected with.
/// \param delay The number of seconds to delay the promise by.
+ (instancetype)newRejectedOnContext:(TWLContext *)context withError:(ErrorType)error afterDelay:(NSTimeInterval)delay NS_SWIFT_UNAVAILABLE("Use init(on:rejected:after:)") TWL_WARN_UNUSED_RESULT;

/// Returns a new \c TWLPromise that cancels after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// \note The promise will be resolved using the \c .automatic context, which evaluates to \c .main
/// when invoked on the main thread, otherwise <tt>.default</tt>. See \c
/// +newFulfilledOnContext:withValue:afterDelay: to specify a different context.
///
/// \param delay The number of seconds to delay the promise by.
+ (instancetype)newCancelledAfterDelay:(NSTimeInterval)delay NS_SWIFT_NAME(makeCancelled(after:)) TWL_WARN_UNUSED_RESULT;

/// Returns a new \c TWLPromise that cancels after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// \param context The context to resolve the \c TWLPromise on. This is generally only important
/// when using callbacks registered with <tt>.immediate</tt>. If provided as \c +operationQueue: it
/// enqueues an operation on the operation queue immediately that becomes ready once the delay has
/// elapsed.
/// \param delay The number of seconds to delay the promise by.
+ (instancetype)newCancelledOnContext:(TWLContext *)context afterDelay:(NSTimeInterval)delay NS_SWIFT_NAME(makeCancelled(on:after:)) TWL_WARN_UNUSED_RESULT;

/// Returns a new \c TWLPromise that fulfills with the given value after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// This can be used as a sort of cancellable timer. It can also be used in conjunction with \c
/// +race:cancelRemaining: to implement a timeout that fulfills with a given value on timeout
/// instead of rejecting with a \c TWLTimeoutError.
///
/// \note The promise will be resolved using the \c .automatic context, which evaluates to \c .main
/// when invoked on the main thread, otherwise <tt>.default</tt>. See \c
/// -initFulfilledOnContext:withValue:afterDelay: to specify a different context.
///
/// \param value The value the promise will be fulfilled with.
/// \param delay The number of seconds to delay the promise by.
- (instancetype)initFulfilledWithValue:(ValueType)value afterDelay:(NSTimeInterval)delay NS_SWIFT_NAME(init(fulfilled:after:));

/// Returns a new \c TWLPromise that fulfills with the given value after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// This can be used as a sort of cancellable timer. It can also be used in conjunction with \c
/// +race:cancelRemaining: to implement a timeout that fulfills with a given value on timeout
/// instead of rejecting with a <tt>TWLTimeoutError</tt>.
///
/// \param context The context to resolve the \c TWLPromise on. This is generally only important
/// when using callbacks registered with <tt>.immediate</tt>. If provided as \c +operationQueue: it
/// enqueues an operation on the operation queue immediately that becomes ready once the delay has
/// elapsed.
/// \param value The value the promise will be fulfilled with.
/// \param delay The number of seconds to delay the promise by.
- (instancetype)initFulfilledOnContext:(TWLContext *)context withValue:(ValueType)value afterDelay:(NSTimeInterval)delay NS_SWIFT_NAME(init(on:fulfilled:after:));

/// Returns a new \c TWLPromise that rejects with the given error after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// \note The promise will be resolved using the \c .automatic context, which evaluates to \c .main
/// when invoked on the main thread, otherwise <tt>.default</tt>. See \c
/// -initFulfilledOnContext:withValue:afterDelay: to specify a different context.
///
/// \param error The error the promise will be rejected with.
/// \param delay The number of seconds to delay the promise by.
- (instancetype)initRejectedWithError:(ErrorType)error afterDelay:(NSTimeInterval)delay NS_SWIFT_NAME(init(rejected:after:));

/// Returns a new \c TWLPromise that rejects with the given error after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// \param context The context to resolve the \c TWLPromise on. This is generally only important
/// when using callbacks registered with <tt>.immediate</tt>. If provided as \c +operationQueue: it
/// enqueues an operation on the operation queue immediately that becomes ready once the delay has
/// elapsed.
/// \param error The error the promise will be rejected with.
/// \param delay The number of seconds to delay the promise by.
- (instancetype)initRejectedOnContext:(TWLContext *)context withError:(ErrorType)error afterDelay:(NSTimeInterval)delay NS_SWIFT_NAME(init(on:rejected:after:));

/// Returns a new \c TWLPromise that cancels after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// \note The promise will be resolved using the \c .automatic context, which evaluates to \c .main
/// when invoked on the main thread, otherwise <tt>.default</tt>. See \c
/// +newFulfilledOnContext:withValue:afterDelay: to specify a different context.
///
/// \param delay The number of seconds to delay the promise by.
- (instancetype)initCancelledAfterDelay:(NSTimeInterval)delay NS_SWIFT_UNAVAILABLE("Use makeCancelled(after:)");

/// Returns a new \c TWLPromise that cancels after a delay.
///
/// Requesting that the promise be cancelled prior to it resolving will immediately cancel the promise.
///
/// \param context The context to resolve the \c TWLPromise on. This is generally only important
/// when using callbacks registered with <tt>.immediate</tt>. If provided as \c +operationQueue: it
/// enqueues an operation on the operation queue immediately that becomes ready once the delay has
/// elapsed.
/// \param delay The number of seconds to delay the promise by.
- (instancetype)initCancelledOnContext:(TWLContext *)context afterDelay:(NSTimeInterval)delay NS_SWIFT_UNAVAILABLE("Use makeCancelled(on:after:)");

// MARK: -

/// Returns a new \c TWLPromise that adopts the receiver's result after a delay.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -delay:onContext: instead.
///
/// \param delay The number of seconds to delay the resulting promise by.
/// \returns A \c TWLPromise that adopts the same result as the receiver after a delay.
- (TWLPromise<ValueType,ErrorType> *)delay:(NSTimeInterval)delay TWL_WARN_UNUSED_RESULT;
/// Returns a new \c TWLPromise that adopts the receiver's result after a delay.
///
/// \param context The context to resolve the new promise on. This is generally only important when
/// using callbacks registered with <tt>.immediate</tt>. If provided as \c .immediate it behaves the
/// same as <tt>.automatic</tt>.
/// If provided as \c +operationQueue: it enqueues an operation on the operation queue immediately
/// that becomes ready once the delay has elapsed.
/// \param delay The number of seconds to delay the resulting promise by.
/// \returns A \c TWLPromise that adopts the same result as the receiver after a delay.
- (TWLPromise<ValueType,ErrorType> *)delay:(NSTimeInterval)delay onContext:(TWLContext *)context TWL_WARN_UNUSED_RESULT;

/// Returns a \c TWLPromise that is rejected with an error if the receiver does not resolve within
/// the given interval.
///
/// The returned promise will adopt the receiver's value if it resolves within the given interval.
/// Otherwise it will be rejected with a \c TWLTimeoutError where \c .timedOut is <tt>YES</tt>. If
/// the receiver is rejected, the returned promise will be rejected with a \c TWLTimeoutError where
/// the \c .rejectedError property contains the underlying promise's rejection value.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -timeoutOnContext:withDelay: instead.
///
/// \param delay The delay before the returned promise times out. If less than or equal to zero, the
/// returned promise will be timed out at once unless the receiver is already resolved.
/// \returns A new <tt>TWLPromise</tt>.
- (TWLPromise<ValueType,TWLTimeoutError<ErrorType>*> *)timeoutWithDelay:(NSTimeInterval)delay TWL_WARN_UNUSED_RESULT;
/// Returns a \c TWLPromise that is rejected with an error if the receiver does not resolve within
/// the given interval.
///
/// The returned promise will adopt the receiver's value if it resolves within the given interval.
/// Otherwise it will be rejected with a \c TWLTimeoutError where \c .timedOut is <tt>YES</tt>. If
/// the receiver is rejected, the returned promise will be rejected with a \c TWLTimeoutError where
/// the \c .rejectedError property contains the underlying promise's rejection value.
///
/// \param context The context to invoke the callback on. If provided as \c .immediate it behaves
/// the same as <tt>.automatic</tt>.
/// If the promise times out, the returned promise will be rejected using the same context. In this
/// event, \c .immediate is treated the same as <tt>.automatic</tt>. If provided as \c
/// +operationQueue: it enqueues an operation on the operation queue immediately that becomes ready
/// once the promise times out.
/// \param delay The delay before the returned promise times out. If less than or equal to zero, the
/// returned promise will be timed out at once unless the receiver is already resolved.
/// \returns A new <tt>TWLPromise</tt>.
- (TWLPromise<ValueType,TWLTimeoutError<ErrorType>*> *)timeoutOnContext:(TWLContext *)context withDelay:(NSTimeInterval)delay TWL_WARN_UNUSED_RESULT;

@end

/// The error type returned from <tt>-[TWLPromise timeoutWithDelay:]</tt>.
///
/// This object either holds a wrapped error value or indicates that the operation timed out.
@interface TWLTimeoutError<Wrapped> : NSObject

/// \c YES if the operation timed out, otherwise <tt>NO</tt>.
///
/// If \c YES the \c rejectedError property is \c nil and if \c NO the \c rejectedError property is
/// non-<tt>nil</tt>.
@property (readonly) BOOL timedOut;
/// If the parent promise was rejected, this holds the rejected error, otherwise <tt>nil</tt>.
///
/// If this is \c nil then \c timedOut will be <tt>YES</tt>.
@property (readonly, nullable) Wrapped rejectedError;

/// Returns a new \c TWLTimeoutError where \c timedOut is <tt>YES</tt>.
/// \returns A <tt>TWLTimeoutError</tt>.
+ (instancetype)newTimedOut NS_SWIFT_UNAVAILABLE("use init(timedOut: ()) instead");
/// Returns a new \c TWLTimeoutError that wraps an underlying error value.
/// \param error The underlying error value to wrap.
/// \returns A <tt>TWLTimeoutError</tt>.
+ (instancetype)newWithRejectedError:(Wrapped)error NS_SWIFT_UNAVAILABLE("use init(rejected:) instead");

/// Returns a new \c TWLTimeoutError where \c timedOut is <tt>YES</tt>.
/// \returns A <tt>TWLTimeoutError</tt>.
- (instancetype)initTimedOut NS_DESIGNATED_INITIALIZER;
/// Returns a new \c TWLTimeoutError that wraps an underlying error value.
/// \param error The underlying error value to wrap.
/// \returns A <tt>TWLTimeoutError</tt>.
- (instancetype)initWithRejectedError:(Wrapped)error NS_SWIFT_NAME(init(rejected:)) NS_DESIGNATED_INITIALIZER;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
