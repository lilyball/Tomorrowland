//
//  TWLDefines.h
//  Tomorrowland
//
//  Created by Kevin Ballard on 12/30/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>

/// Options that can be passed to registered callbacks to affect the behavior of the returned
/// <tt>TWLPromise</tt>.
typedef NS_OPTIONS(NSInteger, TWLPromiseOptions) {
    /// This option links cancellation of the returned \c TWLPromise to the parent promise. When the
    /// new \c TWLPromise is requested to cancel, the \c TWLPromise it was created from is also
    /// requested to cancel.
    ///
    /// This should be used in cases where you create a cancellable \c TWPromise chain and can
    /// guarantee the parent promise isn't observable by anyone else.
    ///
    /// This option also works well with
    /// <tt>-[TWLPromiseInvalidationToken requestCancelOnInvalidate]</tt>.
    ///
    /// Example:
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
    ///}] mapOnContext:TWLContext.utility options:TWLPromiseOptionsLinkCancel handler:^(NSData * _Nonnull data) {
    ///    UIImage *image = [UIImage imageWithData:data];
    ///    if (image) {
    ///        return image;
    ///    } else {
    ///        return [TWLPromise newRejectedWithError:[NSError errorWithDomain:LoadErrorDomain code:LoadErrorDataIsNotImage userInfo:nil]];
    ///    }
    ///}];
    /// \endcode
    TWLPromiseOptionsLinkCancel = 1 << 0,
};
