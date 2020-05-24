//
//  TWLPromise+Convenience.h
//  Tomorrowland
//
//  Created by Lily Ballard on 5/23/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
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

@interface TWLPromise<__covariant ValueType, __covariant ErrorType> (Convenience)

/// Registers callbacks that are invoked when the promise is fulfilled or rejected.
///
/// This is equivalent to chaining \c -then: and <tt>-catch:</tt>.
///
/// \note This method assumes a context of <tt>.automatic</tt>, which evaluates to \c .main when
/// invoked on the main thread, otherwise <tt>.defaultQoS</tt>. If you want to specify the context,
/// use \c -onContext:then:catch: instead.
///
/// \param thenHandler A callback that is invoked with the fulfilled value.
/// \param catchHandler A callback that is invoked with the rejected value.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)then:(void (^)(ValueType value))thenHandler catch:(void (^)(ErrorType error))catchHandler NS_SWIFT_UNAVAILABLE("Use then(…).catch(…)");

/// Registers callbacks that are invoked when the promise is fulfilled or rejected.
///
/// This is equivalent to chaining \c -thenOnContext:handler: and <tt>-catchOnContext:handler</tt>
/// with the same context.
///
/// \param context The context to invoke the callback on.
/// \param thenHandler A callback that is invoked with the fulfilled value.
/// \param catchHandler A callback that is invoked with the rejected value.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)onContext:(TWLContext *)context then:(void (^)(ValueType value))thenHandler catch:(void (^)(ErrorType error))catchHandler NS_SWIFT_UNAVAILABLE("Use then(…).catch(…)");

/// Registers callbacks that are invoked when the promise is fulfilled or rejected.
///
/// This is equivalent to chaining \c -thenOnContext:token:handler: and
/// <tt>-catchOnContext:token:handler</tt> with the same context and token.
///
/// \param context The context to invoke the callback on.
/// \param token An optional <tt>TWLInvalidationToken</tt>. If provided, calling \c -invalidate on
/// the token will prevent \a thenHandler or \a catchHandler from being invoked.
/// \param thenHandler A callback that is invoked with the fulfilled value.
/// \param catchHandler A callback that is invoked with the rejected value.
/// \returns A new promise that will resolve to the same value as the receiver. You may safely
/// ignore this value.
- (TWLPromise<ValueType,ErrorType> *)onContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token then:(void (^)(ValueType value))thenHandler catch:(void (^)(ErrorType error))catchHandler NS_SWIFT_UNAVAILABLE("Use then(…).catch(…)");

@end

NS_ASSUME_NONNULL_END
