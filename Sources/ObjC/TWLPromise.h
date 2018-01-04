//
//  TWLPromise.h
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/3/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
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
+ (instancetype)newOnContext:(TWLContext *)context withBlock:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))block NS_SWIFT_UNAVAILABLE("Use init(on:_:)");
+ (instancetype)newFulfilledWithValue:(ValueType)value NS_SWIFT_UNAVAILABLE("Use init(fulfilled:)");
+ (instancetype)newRejectedWithError:(ErrorType)error NS_SWIFT_UNAVAILABLE("Use init(rejected:)");

#if __cplusplus
+ (std::pair<TWLPromise<ValueType,ErrorType> *,TWLResolver<ValueType,ErrorType> *>)makePromiseWithResolver;
#endif

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initOnContext:(TWLContext *)context withBlock:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))block NS_SWIFT_NAME(init(on:_:)) NS_DESIGNATED_INITIALIZER;
- (instancetype)initFulfilledWithValue:(ValueType)value NS_SWIFT_NAME(init(fulfilled:)) NS_DESIGNATED_INITIALIZER;
- (instancetype)initRejectedWithError:(ErrorType)error NS_SWIFT_NAME(init(rejected:)) NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithResolver:(TWLResolver<ValueType,ErrorType> * __strong _Nullable * _Nonnull)outResolver NS_DESIGNATED_INITIALIZER;

- (TWLPromise<ValueType,ErrorType> *)then:(void (^)(ValueType value))handler;
- (TWLPromise<ValueType,ErrorType> *)thenOnContext:(TWLContext *)context handler:(void (^)(ValueType value))handler NS_SWIFT_NAME(then(on:_:));
- (TWLPromise<ValueType,ErrorType> *)thenOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ValueType value))handler NS_SWIFT_NAME(then(on:token:_:));

- (TWLPromise *)map:(id (^)(ValueType value))handler TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)mapOnContext:(TWLContext *)context handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)mapOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:token:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)mapOnContext:(TWLContext *)context options:(TWLPromiseOptions)options handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:options:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)mapOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(id (^)(ValueType value))handler NS_SWIFT_NAME(map(on:token:options:_:)) TWL_WARN_UNUSED_RESULT;

- (TWLPromise<ValueType,ErrorType> *)catch:(void (^)(ErrorType error))handler;
- (TWLPromise<ValueType,ErrorType> *)catchOnContext:(TWLContext *)context handler:(void (^)(ErrorType error))handler NS_SWIFT_NAME(catch(on:_:));
- (TWLPromise<ValueType,ErrorType> *)catchOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ErrorType error))handler NS_SWIFT_NAME(catch(on:token:_:));

- (TWLPromise *)recover:(id (^)(ErrorType error))handler TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)recoverOnContext:(TWLContext *)context handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)recoverOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:token:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)recoverOnContext:(TWLContext *)context options:(TWLPromiseOptions)options handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:options:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)recoverOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(id (^)(ErrorType error))handler NS_SWIFT_NAME(recover(on:token:options:_:)) TWL_WARN_UNUSED_RESULT;

- (TWLPromise<ValueType,ErrorType> *)inspect:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler;
- (TWLPromise<ValueType,ErrorType> *)inspectOnContext:(TWLContext *)context handler:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(inspect(on:_:));
- (TWLPromise<ValueType,ErrorType> *)inspectOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(void (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(inspect(on:token:_:));

- (TWLPromise *)always:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)alwaysOnContext:(TWLContext *)context handler:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(always(on:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)alwaysOnContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token handler:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(always(on:token:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)alwaysOnContext:(TWLContext*)context options:(TWLPromiseOptions)options handler:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(always(on:options:_:)) TWL_WARN_UNUSED_RESULT;
- (TWLPromise *)alwaysOnContext:(TWLContext*)context token:(nullable TWLInvalidationToken *)token options:(TWLPromiseOptions)options handler:(TWLPromise * _Nonnull (^)(ValueType _Nullable value, ErrorType _Nullable error))handler NS_SWIFT_NAME(always(on:token:options:_:)) TWL_WARN_UNUSED_RESULT;

- (TWLPromise<ValueType,ErrorType> *)whenCancelled:(void (^)(void))handler NS_SWIFT_NAME(onCancel(_:));
- (TWLPromise<ValueType,ErrorType> *)whenCancelledOnContext:(TWLContext *)context handler:(void (^)(void))handler NS_SWIFT_NAME(onCancel(on:_:));
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

- (void)requestCancel;

- (TWLPromise<ValueType,ErrorType> *)ignoringCancel TWL_WARN_UNUSED_RESULT;

@end

@interface TWLResolver<__contravariant ValueType, __contravariant ErrorType> : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (void)fulfillWithValue:(ValueType)value NS_SWIFT_NAME(fulfill(with:));
- (void)rejectWithError:(ErrorType)error NS_SWIFT_NAME(reject(with:));
- (void)cancel;

- (void)resolveWithValue:(nullable ValueType)value error:(nullable ValueType)error;

- (void)whenCancelRequestedOnContext:(TWLContext *)context handler:(void (^)(TWLResolver<ValueType,ErrorType> *resolver))handler NS_SWIFT_NAME(onRequestCancel(on:_:));

@end

NS_ASSUME_NONNULL_END
