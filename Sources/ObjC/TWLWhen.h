//
//  TWLWhen.h
//  Tomorrowland
//
//  Created by Lily Ballard on 1/7/18.
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

NS_ASSUME_NONNULL_BEGIN

@interface TWLPromise<ValueType,ErrorType> (When)

/// Waits on an array of promises and returns a \c TWLPromise that is fulfilled with an array of the
/// resulting fulfilled values.
///
/// The value of the returned promise is an array of the same length as the input array and where
/// each element in the resulting array corresponds to the same element in the input array.
///
/// If any input promise is rejected, the resulting promise is rejected with the same error. If any
/// input promise is cancelled, the resulting promise is cancelled. If multiple input promises are
/// rejected or cancelled, the first such one determines how the returned \c TWLPromise behaves.
///
/// \param promises An array of promises whose fulfilled values will be collected to fulfill the
/// returned <tt>TWLPromise</tt>.
/// \returns A \c TWLPromise that will be fulfilled with an array of the fulfilled values from each
/// input promise.
+ (TWLPromise<NSArray<ValueType>*,ErrorType> *)whenFulfilled:(NSArray<TWLPromise<ValueType,ErrorType>*> *)promises;
/// Waits on an array of promises and returns a \c TWLPromise that is fulfilled with an array of the
/// resulting fulfilled values.
///
/// The value of the returned promise is an array of the same length as the input array and where
/// each element in the resulting array corresponds to the same element in the input array.
///
/// If any input promise is rejected, the resulting promise is rejected with the same error. If any
/// input promise is cancelled, the resulting promise is cancelled. If multiple input promises are
/// rejected or cancelled, the first such one determines how the returned \c TWLPromise behaves.
///
/// \param promises An array of promises whose fulfilled values will be collected to fulfill the
/// returned <tt>TWLPromise</tt>.
/// \param qosClass The QoS class to use for the dispatch queues that coordinate the work.
/// \returns A \c TWLPromise that will be fulfilled with an array of the fulfilled values from each
/// input promise.
+ (TWLPromise<NSArray<ValueType>*,ErrorType> *)whenFulfilled:(NSArray<TWLPromise<ValueType,ErrorType>*> *)promises qos:(dispatch_qos_class_t)qosClass;
/// Waits on an array of promises and returns a \c TWLPromise that is fulfilled with an array of the
/// resulting fulfilled values.
///
/// The value of the returned promise is an array of the same length as the input array and where
/// each element in the resulting array corresponds to the same element in the input array.
///
/// If any input promise is rejected, the resulting promise is rejected with the same error. If any
/// input promise is cancelled, the resulting promise is cancelled. If multiple input promises are
/// rejected or cancelled, the first such one determines how the returned \c TWLPromise behaves.
///
/// \param promises An array of promises whose fulfilled values will be collected to fulfill the
/// returned <tt>TWLPromise</tt>.
/// \param cancelOnFailure If \c YES all input promises will be cancelled if any of them are
/// rejected or cancelled.
/// \returns A \c TWLPromise that will be fulfilled with an array of the fulfilled values from each
/// input promise.
+ (TWLPromise<NSArray<ValueType>*,ErrorType> *)whenFulfilled:(NSArray<TWLPromise<ValueType,ErrorType>*> *)promises cancelOnFailure:(BOOL)cancelOnFailure;
/// Waits on an array of promises and returns a \c TWLPromise that is fulfilled with an array of the
/// resulting fulfilled values.
///
/// The value of the returned promise is an array of the same length as the input array and where
/// each element in the resulting array corresponds to the same element in the input array.
///
/// If any input promise is rejected, the resulting promise is rejected with the same error. If any
/// input promise is cancelled, the resulting promise is cancelled. If multiple input promises are
/// rejected or cancelled, the first such one determines how the returned \c TWLPromise behaves.
///
/// \param promises An array of promises whose fulfilled values will be collected to fulfill the
/// returned <tt>TWLPromise</tt>.
/// \param qosClass The QoS class to use for the dispatch queues that coordinate the work.
/// \param cancelOnFailure If \c YES all input promises will be cancelled if any of them are
/// rejected or cancelled.
/// \returns A \c TWLPromise that will be fulfilled with an array of the fulfilled values from each
/// input promise.
+ (TWLPromise<NSArray<ValueType>*,ErrorType> *)whenFulfilled:(NSArray<TWLPromise<ValueType,ErrorType>*> *)promises qos:(dispatch_qos_class_t)qosClass cancelOnFailure:(BOOL)cancelOnFailure;

/// Returns a \c TWLPromise that is resolved with the result of the first resolved input <tt>Promise</tt>.
///
/// The first input promise that is either fulfilled or rejected causes the resulting \c TWLPromise
/// to be fulfilled or rejected. An input promise that is cancelled is ignored. If all input
/// promises are cancelled, the resulting \c TWLPromise is cancelled.
///
/// \param promises An array of promises.
/// \returns A \c TWLPromise that will be resolved with the value or error from the first fulfilled
/// or rejected input promise.
+ (TWLPromise<ValueType,ErrorType> *)race:(NSArray<TWLPromise<ValueType,ErrorType>*> *)promises;
/// Returns a \c TWLPromise that is resolved with the result of the first resolved input <tt>Promise</tt>.
///
/// The first input promise that is either fulfilled or rejected causes the resulting \c TWLPromise
/// to be fulfilled or rejected. An input promise that is cancelled is ignored. If all input
/// promises are cancelled, the resulting \c TWLPromise is cancelled.
///
/// \param promises An array of promises.
/// \param cancelRemaining If \c YES all remaining input promises will be cancelled as soon as the
/// first one is resolved.
/// \returns A \c TWLPromise that will be resolved with the value or error from the first fulfilled
/// or rejected input promise.
+ (TWLPromise<ValueType,ErrorType> *)race:(NSArray<TWLPromise<ValueType,ErrorType>*> *)promises cancelRemaining:(BOOL)cancelRemaining;

@end

NS_ASSUME_NONNULL_END
