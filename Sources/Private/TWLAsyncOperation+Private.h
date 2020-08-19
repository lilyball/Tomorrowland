//
//  TWLAsyncOperation+Private.h
//  Tomorrowland
//
//  Created by Lily Ballard on 8/18/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import <Foundation/Foundation.h>
#import "TWLAsyncOperation.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TWLAsyncOperationState) {
    TWLAsyncOperationStateInitial = 0,
    TWLAsyncOperationStateExecuting,
    TWLAsyncOperationStateFinished,
};

/// An operation class to subclass for writing asynchronous operations.
///
/// This operation clss is marked as asynchronous by default and maintains an atomic \c state
/// property that is used to send the appropriate KVO notifications.
///
/// Subclasses should override \c -main which will be called automatically by \c -start when the
/// operation is ready. When the \c -main method is complete it must set \c state to
/// \c TWLAsyncOperationStateFinished. It must also check for cancellation and handle this
/// appropriately. When the \c -main method is executed the \c state will already be set to
/// \c TWLAsyncOperationStateExecuting.
@interface TWLAsyncOperation ()

/// The state property that controls the \c isExecuting and \c isFinished properties.
///
/// Setting this automatically sends the KVO notices for those other properties.
///
/// \note This property uses relaxed memory ordering. If the operation writes state that must be
/// visible to observers from other threads it needs to manage the synchronization itself.
@property (atomic) TWLAsyncOperationState state __attribute__((swift_private));

// Do not override this method.
- (void)start;

// Override this method. When the operation is complete, set \c state to
// \c TWLAsyncOperationStateFinished. Do not call \c super.
- (void)main;

@end

NS_ASSUME_NONNULL_END
