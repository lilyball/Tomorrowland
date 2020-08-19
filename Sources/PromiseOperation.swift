//
//  PromiseOperation.swift
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

import Tomorrowland.Private

/// `StdPromiseOperation` is an alias for a `PromiseOperation` whose error type is `Swift.Error`.
public typealias StdPromiseOperation<Value> = PromiseOperation<Value,Swift.Error>

/// An `Operation` subclass that wraps a `Promise`.
///
/// `PromiseOperation` is an `Operation` subclass that wraps a `Promise`. It doesn't invoke its
/// callback until the operation has been started, and the operation is marked as finished when the
/// promise is resolved.
///
/// The associated promise can be retrieved at any time with the `.promise` property, even before
/// the operation has started. Requesting cancellation of the promise will cancel the operation, but
/// if the operation has already started it's up to the provided handler to handle the cancellation
/// request.
///
/// - Note: Cancelling the operation or the associated promise before the operation has started will
///   always cancel the promise without executing the provided handler, regardless of whether the
///   handler itself supports cancellation.
public final class PromiseOperation<Value,Error>: TWLAsyncOperation {
    /// The type of the promise resolver. See `Promise<Value,Error>.Resolver`.
    public typealias Resolver = Promise<Value,Error>.Resolver
    
    // Re-use DelayedPromiseBox here as it does everything we need it to
    private let _box: DelayedPromiseBox<Value,Error>
    
    /// The actual promise we return to callers.
    ///
    /// This is a child of our internal promise. This way we can observe cancellation requests while
    /// our `_box` is still in `.delayed`, and when we go out of scope the promise will get
    /// cancelled if the callback was never invoked.
    private let _promise: Promise<Value,Error>
    
    /// Returns a new `PromiseOperation` that can be resolved with the given block.
    ///
    /// The `PromiseOperation` won't execute the block until it has been started, either by adding
    /// it to an `OperationQueue` or by invoking the `start()` method directly.
    ///
    /// - Parameter context: The context to execute the handler on. If `.immediate`, the handler is
    ///   invoked on the thread that starts the operation; if the `start()` method is called
    ///   directly it's the current thread, if the operation is added to an `OperationQueue` it's
    ///   will be invoked on the queue.
    /// - Parameter handler: A block that will be executed when the operation starts in order to
    ///   fulfill the promise. The operation will not be marked as finished until the promise
    ///   resolves, even if the handler returns before then.
    /// - Parameter resolver: The `Resolver` used to resolve the promise.
    public init(on context: PromiseContext, _ handler: @escaping (_ resolver: Resolver) -> Void) {
        let (childPromise, childResolver) = Promise<Value,Error>.makeWithResolver()
        var seal: PromiseSeal<Value,Error>!
        _box = DelayedPromiseBox(context: context, callback: { (resolver) in
            // We piped data from the inner promise to the outer promise at the end of `init`
            // already, but we need to propagate cancellation the other way. We're deferring that
            // until now because cancelling a box in the `.delayed` state is ignored. By waiting
            // until now, we ensure that the box is in the `.empty` state instead and therefore will
            // accept cancellation. We're still running the handler, but this way the handler can
            // check for cancellation requests.
            childResolver.propagateCancellation(to: Promise(seal: seal))
            // Throw away the seal now, to seal the box. We won't be using it again. This way
            // cancellation will propagate if appropriate.
            seal = nil
            // Now we can invoke the original handler.
            handler(resolver)
        })
        seal = PromiseSeal(delayedBox: _box)
        _promise = childPromise
        super.init()
        // Observe the promise now in order to set our operation state.
        childPromise.tap(on: .immediate) { [weak self] (result) in
            // Regardless of the result, mark ourselves as finished.
            // We can only get resolved if we've been started.
            self?.__state = .finished
        }
        // If someone requests cancellation of the promise, treat that as asking the operation
        // itself to cancel.
        childResolver.onRequestCancel(on: .immediate) { [weak self] (_) in
            guard let self = self,
                // cancel() invokes this callback; let's not invoke cancel() again.
                // It should be safe to do so, but it will fire duplicate KVO notices.
                !self.isCancelled
                else { return }
            self.cancel()
        }
        // Pipe data from the delayed box to our child promise now. This way if we never actually
        // execute the callback, we'll get informed of cancellation.
        seal._enqueue(box: childPromise._box) // the propagateCancel happens in the DelayedPromiseBox callback
    }
    
    deinit {
        // If we're thrown away without executing, we need to clean up.
        // Since the box is in the delayed state, it won't just cancel automatically.
        _box.emptyAndCancel()
    }
    
    /// Returns a `Promise` that asynchronously contains the value of the computation.
    ///
    /// The `.promise` property may be accessed at any time, but the promise will not be resolved
    /// until after the operation has started, either by adding it to an operation queue or by
    /// invoking the `start()` method.
    ///
    /// The same `Promise` is returned every time.
    public var promise: Promise<Value,Error> {
        return _promise
    }
    
    public override func cancel() {
        // Call super first so `isCancelled` is true.
        super.cancel()
        // Now request cancellation of the promise.
        _promise.requestCancel()
        // This does mean a KVO observer of the "isCancelled" key can act on the change prior to our
        // promise being requested to cancel, but that should be meaningless; this is only even
        // externally observable if the KVO observer has access to the promise's resolver.
    }
    
    @available(*, unavailable) // disallow direct invocation through this type
    public override func main() {
        // Check if our promise has requested to cancel.
        // We're doing this over just testing `self.isCancelled` to handle the super edge case where
        // one thread requests the promise to cancel at the same time as another thread starts the
        // operation. Requesting our promise to cancel places it in the cancelled state prior to
        // setting `isCancelled`, which leaves a race where the promise is cancelled but the
        // operation is not. If we were checking `isCancelled` we could get into a situation where
        // the handler executes and cannot tell that it was asked to cancel.
        // The opposite is safe, if we cancel the operation and the operation starts before the
        // promise is marked as cancelled, the cancellation will eventually be exposed to the
        // handler, so it can take action accordingly.
        if _promise._box.unfencedState == .cancelling {
            _box.emptyAndCancel()
        } else {
            _box.execute()
        }
    }
}
