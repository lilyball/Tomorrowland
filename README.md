# Tomorrowland

[![Version](https://img.shields.io/badge/version-v1.3.0-blue.svg)](https://github.com/lilyball/Tomorrowland/releases/latest)
![Platforms](https://img.shields.io/badge/platforms-ios%20%7C%20macos%20%7C%20watchos%20%7C%20tvos-lightgrey.svg)
![Languages](https://img.shields.io/badge/languages-swift%20%7C%20objc-orange.svg)
![License](https://img.shields.io/badge/license-MIT%2FApache-blue.svg)
![CocoaPods](https://img.shields.io/cocoapods/v/Tomorrowland.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)][Carthage]

[Carthage]: https://github.com/carthage/carthage

Tomorrowland is an implementation of [Promises](https://en.wikipedia.org/wiki/Futures_and_promises) for Swift and Objective-C. A Promise is a wrapper around an
asynchronous task that provides a standard way of subscribing to task resolution as well as chaining promises together.

```swift
UIApplication.shared.isNetworkActivityIndicatorVisible = true
MyAPI.requestFeed(for: user).then { (feedItems) in
    self.refreshUI(with: feedItems)
}.catch { (error) in
    self.showError(error)
}.always { _ in
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
}
```

It is loosely based on both [PromiseKit][] and [Hydra][], with a few key distinctions:

[PromiseKit]: http://promisekit.org/
[Hydra]: https://github.com/malcommac/Hydra

* It uses atomics internally instead of creating a separate `DispatchQueue` for each promise. This means it's faster and uses fewer resources.
* It provides full support for cancellable promises. PromiseKit supports detection of "cancelled" errors but has no way to request cancellation of a promise. Hydra
  supports cancelling a promise, but it can't actually stop any work being done by the promise unless the promise body itself polls for the cancellation status (so e.g.
  a promise wrapping a network task can't reasonably cancel the network task). Tomorrowland improves on this by allowing the promise body to observe the
  cancelled state, and allows linking cancellation of a child promise to its parent.
* Its Obj-C support makes use of generics for improved type safety and better documentation.
* Like Hydra but unlike PromiseKit, it provides a way to suppress a registered callback (e.g. because you don't care about the result anymore and don't want stale
  data affecting your UI). This is distinct from promise cancellation.
* Tomorrowland promises are fully generic over the error type, whereas both PromiseKit and Hydra only support using `Error` as the error type. This may result in
  more typing to construct a promise but it allows for much more powerful error handling. Tomorrowland also has some affordances for working with promises that
  use `Error` as the error type.
* Tomorrowland is fully thread-safe. I have no reason to believe PromiseKit isn't, but (at the time of this writing) there are parts of Hydra that are incorrectly
  implemented in a non-thread-safe manner.

## Installation

### Manually

You can add Tomorrowland to your workspace manually like any other project and add the resulting `Tomorrowland.framework` to your application's frameworks.

### Carthage

```
github "lilyball/Tomorrowland" ~> 1.0
```

The project file is configured to use Swift 5. The code can be compiled against Swift 4.2 instead, but I'm not aware of any way to instruct Carthage to override the
swift version during compilation.

### CocoaPods

```ruby
pod 'Tomorrowland', '~> 1.0'
```

The podspec declares support for both Swift 4.2 and Swift 5.0, but selecting the Swift version requires using CoocaPods 1.7.0 or later. When using CocoaPods 1.6
or earlier the Swift version will default to 5.0.

### SwiftPM

Tomorrowland currently relies on a private Obj-C module for its atomics. This arrangement means it is not compatible with Swift Package Manager (as adding
compatibility would necessitate publicly exposing the private Obj-C module).

## Usage

### Creating Promises

Promises can be created using code like the following:

```swift
let promise = Promise<String,Error>(on: .utility, { (resolver) in
    let value = try expensiveCalculation()
    resolver.fulfill(with: value)
})
```

The body of this promise runs on the specified `PromiseContext`, which in this case is `.utility` (which means `DispatchQueue.global(qos: .utility)`).
Unlike callbacks, all created promises must specify a context, so as to avoid accidentally running expensive computations on the main thread. The available contexts
include `.main`, every Dispatch QoS, a specific `DispatchQueue`, a specific `OperationQueue`, or the value `.immediate` which means to run the block
synchronously. There's also the special context `.auto`, which evaluates to `.main` on the main thread and `.default` otherwise.

**Note:** The `.immediate` context can be dangerous to use for callback handlers and should be avoided in most cases. It's primarily intended for creating
promises, and whenever it's used with a callback handler the handler must be prepared to execute on *any thread*. For callbacks it's usually only useful for short
thread-agnostic callbacks, such as an `.onRequestCancel` that does nothing more than cancelling a `URLSessionTask`.

The body of a `Promise` receives a "resolver", which it must use to fulfill, reject, or cancel the promise. If the resolver goes out of scope without being used, the
promise is automatically cancelled. If the promise's error type is `Error`, the promise body may also throw an error (as seen above), which is then used to reject the
promise. This resolver can also be used to observe cancellation requests using `resolver.onRequestCancel`, as seen here:

```swift
let promise = Promise<Data,Error>(on: .immediate, { (resolver) in
    let task = urlSession.dataTask(with: url, completionHandler: { (data, response, error) in
        if let data = data {
            resolver.fulfill(with: data)
        } else if case URLError.cancelled? = error {
            resolver.cancel()
        } else {
            resolver.reject(with: error!)
        }
    })
    resolver.onRequestCancel(on: .immediate, { _ in
        task.cancel()
    })
    task.resume()
})
```

Resolvers also have a convenience method `handleCallback()` that is intended to make it easy to wrap framework callbacks in promises. This method returns a
closure that can be used as a callback directly. It also takes an optional `isCancelError` parameter that can be used to indicate when an error represents
cancellation. For example:

```swift
geocoder.reverseGeocodeLocation(location, completionHandler: resolver.handleCallback(isCancelError: { CLError.geocodeCanceled ~= $0 }))
```

### Using Promises

Once you have a promise, you can register callbacks to be executed when the promise is resolved. Most callback methods require a context, but for some of them
(`then`, `catch`, `always`, and `tryThen`) you can omit the context and it will default to `.auto`, which means the main thread if the callback is registered from the
main thread, otherwise the dispatch queue with QoS `.default`.

When you register a callback, the method also returns a `Promise`. All callback registration methods return a new `Promise` even if the callback doesn't affect the
value of the promise. The reason for this is so chained callbacks always guarantee that the previous callback finished executing before the new one starts, even
when using concurrent contexts (e.g. `.utility`), and so cancelling the returned promise doesn't cancel the original one if any other callbacks were registered on
it.

Most callback registration methods also have versions that allow you to return a `Promise` from your callback. In this event, the resulting `Promise` waits for the
promise you returned to resolve before adopting its value. This allows for easy composition of promises.

```swift
showLoadingIndicator()
fetchUserCredentials().flatMap(on: .default) { (credentials) in
    // This returns a new promise
    return MyAPI.login(name: credentials.name, password: credentials.password)
}.then { [weak self] (apiKey) in
    // this is invoked when the promise returned by MyAPI.login fulfills.
    MyAPI.apiKey = apiKey
    self?.transitionToLoggedInState()
}.always { [weak self] _ in
    // This is always invoked regardless of whether the previous chain was
    // fulfilled, rejected, or cancelled.
    self?.hideLoadingIndicator()
}.catch { [weak self] (error) in
    // this handles any error returned from the previous chain, meaning any error
    // from `fetchUserCredentials()` or from `MyAPI.login(name:password:)`.
    self?.displayError(error)
}
```

When composing callbacks that return promises, you may run into issues with incompatible error types. There are convenience methods for working with promises
whose errors are compatible with `Error`, but they don't cover all cases. If you find yourself hitting one of these cases, any `Promise` whose error type conforms to
`Error` has a property `.upcast` that will convert that error into an `Error` to allow for easier composition of promises.

Tomorrowland also offers a typealias `StdPromise<Value>` as shorthand for `Promise<T,Error>`. This is frequently useful to avoid having to repeat the types,
such as with `StdPromise(fulfilled: someValue)` instead of `Promise<SomeValue,Error>(fulfilled: someValue)`.

### Cancelling and Invalidation

All promises expose a method `.requestCancel()`. It is named such because this doesn't actually guarantee that the promise will be cancelled. If the promise
supports cancellation, this method will trigger a callback that the promise can use to cancel its work. But promises that don't support cancellation will ignore this
and will eventually fulfill or reject as normal. Naturally, requesting cancellation of a promise that has already been resolved does nothing, even if the callbacks have
not yet been invoked.

In order to handle the issue of a promise being resolved after you no longer care about it, there is a separate mechanism called a `PromiseInvalidationToken`
that can be used to suppress callbacks. All callback methods have an optional `token` parameter that accepts a `PromiseInvalidationToken`.  If provided,
calling `invalidate()` on the token prior to the callback being executed guarantees the callback will not fire. If the callback returns a value that is required in order
to resolve the `Promise` returned from the callback registration method, the resulting `Promise` is cancelled instead. `PromiseInvalidationToken`s can be used
with multiple callbacks at once, and a single token can be re-used as much as desired. It is recommended that you take advantage of both invalidation tokens and
cancellation. This may look like

```swift
class URLImageView: UIImageView {
    private var promise: StdPromise<Void>?
    private let invalidationToken = PromiseInvalidationToken()
    
    enum LoadError: Error {
        case dataIsNotImage
    }
    
    /// Loads an image from the URL and displays it in the image view.
    func loadImage(from url: URL) {
        promise?.cancel()
        invalidationToken.invalidate()
        // Note: dataTaskAsPromise does not actually exist
        promise = URLSession.shared.dataTaskAsPromise(with: url)
        // Use `_ =` to avoid having to handle errors with `.catch`.
        _ = promise?.tryMap(on: .utility, { (data) -> UIImage in
            if let image = UIImage(data: data) {
                return image
            } else {
                throw LoadError.dataIsNotImage
            }
        }).then(token: invalidationToken, { [weak self] (image) in
            self?.image = image
        })
    }
}
```

`PromiseInvalidationToken` also has a method `.requestCancelOnInvalidate(_:)` that can register any number of `Promise`s to be automatically
requested to cancel (using `.requestCancel()`) the next time the token is invalidated. `Promise` also has the same method (except it takes a token as the
argument) as a convenience for calling `.requestCancelOnInvalidate(_:)` on the token. This can be used to terminate a promise chain without ever assigning
the promise to a local variable. `PromiseInvalidationToken` also has a method `.cancelWithoutInvalidating()` which cancels any associated promises
without invalidating the token.

By default `PromiseInvalidationToken`s will invalidate themselves automatically when deinitialized. This is primarily useful in conjunction with
`requestCancelOnInvalidate(_:)` as it allows you to automatically cancel your promises when object that owns the token deinits. This behavior can be
disabled with an optional parameter to `init`.

`Promise` also has a convenience method `requestCancelOnDeinit(_:)` which can be used to request the `Promise` to be cancelled when a given object
deinits. This is equivalent to adding a `PromiseInvalidationToken` property to the object (configured to invalidate on deinit) and requesting cancellation when
the token invalidates, but can be used if the token would otherwise not be explicitly invalidated.

Using these methods, the above `loadImage(from:)` can be rewritten as the following including cancellation:

```swift
class URLImageView: UIImageView {
    private let promiseToken = PromiseInvalidationToken()
    
    enum LoadError: Error {
        case dataIsNotImage
    }
    
    /// Loads an image from the URL and displays it in the image view.
    func loadImage(from url: URL) {
        promiseToken.invalidate()
        // Note: dataTaskAsPromise does not actually exist
        promise = URLSession.shared.dataTaskAsPromise(with: url)
        // Use `_ =` to avoid having to handle errors with `.catch`.
        _ = promise?.tryMap(on: .utility, { (data) -> UIImage in
            if let image = UIImage(data: data) {
                return image
            } else {
                throw LoadError.dataIsNotImage
            }
        }).then(token: promiseToken, { [weak self] (image) in
            self?.image = image
        }).requestCancelOnInvalidate(invalidationToken)
    }
}
```

#### Invalidation token chaining

`PromiseInvalidationToken`s can be arranged in a tree such that invalidating one token will cascade this invalidation down to other tokens. This is
accomplished by calling `childToken.chainInvalidation(from: parentToken)`. Practically speaking this is no different than just manually invalidating each
child token yourself after invalidating the parent token, but it's provided as a convenience to make it easy to have fine-grained invalidation control while also having
a simple way to bulk-invalidate tokens. For example, you might have separate tokens for different view controllers that all chain invalidation from a single token that
gets invalidated when the user logs out, thus automatically invalidating all your user-dependent network requests at once while still allowing each view controller the
ability to invalidate just its own requests independently.

#### `TokenPromise`

In order to avoid the repetition of passing a `PromiseInvalidationToken` to multiple `Promise` methods as well as cancelling the resulting promise, a type
`TokenPromise` exists that handles this for you. You can create a `TokenPromise` with the `Promise.withToken(_:)` method. This allows you to take code like
the following:

```swift
func loadModel() {
    promiseToken.invalidate()
    MyModel.fetchFromNetworkAsPromise()
        .then(token: promiseToken, { [weak self] (model) in
            self?.updateUI(with: model)
        }).catch(token: promiseToken, { [weak self] (error) in
            self?.handleError(error)
        }).requestCancelOnInvalidate(promiseToken)
}
```

And rewrite it to be less repetitive:

```swift
func loadModel() {
    promiseToken.invalidate()
    MyModel.fetchFromNetworkAsPromise()
        .withToken(promiseToken)
        .then({ [weak self] (model) in
            self?.updateUI(with: model)
        }).catch({ [weak self] (error) in
            self?.handleError(error)
        })
}
```

#### Automatic cancellation propagation

Nearly all callback registration methods will automatically propagate cancellation requests from the child to the parent if the parent has no other observers. If all
observers for a promise request cancellation, the cancellation request will propagate upwards at this time. This means that a promise will not automatically cancel
as long as there's at least one interested observer. Do note that promises that have no observers do not get automatically cancelled, this only happens if there's at
least one observer (which then requests cancellation). Automatic cancellation propagation also requires that the promise itself no longer be in scope. For this reason
you should avoid holding onto promises long-term and instead use the `.cancellable` property or `PromiseInvalidationToken`'s
`requestCancelOnInvalidate(_:)` if you want to be able to cancel the promise later.

Automatic cancellation propagation also works with the utility functions `when(fulfilled:)` and `when(first:)` as well as the convenience methods
`timeout(on:delay:)` and `delay(on:_:)`.

Promises have a couple of methods that do not participate in automatic cancellation propagation. You can use `tap(on:token:_:)` as an alternative to `always` in
order to register an observer that won't interfere with the existing automatic cancellation propagation (this is suitable for inserting into the middle of a promise
chain). You can also use `tap()` as a more generic version of this.

Note that `ignoringCancel()` disables automatic cancellation propagation on the receiver. Once you invoke this on a promise, it will never automatically cancel.

##### `propagatingCancellation(on:cancelRequested:)`

In some cases you may need to hold onto a promise without blocking cancellation propagation from its children. The primary use-case here is deduplicating access to
an asynchronous resource (such as a network load). In this scenario you may wish to hold onto a promise and return a new child for every client requesting the same
resource, without preventing cancellation of the resource load if all clients cancel their requests. This can be accomplished by holding onto the result of calling
`.propagatingCancellation(on:cancelRequested:)`. The promise returned from this method will propagate cancellation to its parent as soon as all children
have requested cancellation even if the promise is still in scope. When cancellation is requested, the `cancelRequested` handler will be invoked immediately prior to
propagating cancellation upwards; this enables you to release your reference to the promise (so a new request by a client will create a brand new resource load). An
example of this might look like:

```swift
func loadResource(at url: URL) {
    let promise: StdPromise<Model>
    if let existingPromise = resourceLoads[url] {
        promise = existingPromise
    } else {
        promise = makeResourceRequest(for: url).propagatingCancellation(on: .main, cancelRequested: { (promise) in
            if self.resourceLoads[url] == promise {
                self.resourceLoads[url] = nil
            }
        })
        resourceLoads[url] = promise
    }
    // Return a new child for each request so all clients have to cancel, not just one.
    return promise.then(on: .immediate, { _ in })
}
```

### The special `.nowOr(_:)` context

There is a special context `PromiseContext.nowOr(_:)` that behaves a bit differently than other contexts. This context is special in that its callback executes
differently depending on whether the promise it's being registered on has already resolved by the time the callback is registered. If the promise has already
resolved then `.nowOr(context)` behaves like `.immediate`, otherwise it behaves like the wrapped `context`. This context is intended to be used to replace
code that would otherwise check if the `promise.result` is non-`nil` prior to registering a callback.

If this context is used in `Promise.init(on:_:)` it always behaves like `.immediate`, and if it's used in `DelayedPromise.init(on:_:)` it always behaves
like the wrapped context.

There is a property `PromiseContext.isExecutingNow` that can be accessed from within a callback registered with `.nowOr(_:)` to determine if the callback
is executing synchronously or asynchronously. When accessed from any other context it returns `false`. When registering a callback with `.immediate` from
within a callback where `PromiseContext.isExecutingNow` is `true`, the nested callback will inherit the `PromiseContext.isExecutingNow` flag if and only
if the nested callback is also executing synchronously. This is a bit subtle but is intended to allow `Promise(on: .immediate, { … })` to inherit the flag from
its surrounding scope.

An example of how this context might be used is when populating an image view from a network request:

```swift
createNetworkRequestAsPromise()
    .then(on: .nowOr(.main), { [weak imageView] (image) in
        guard let imageView = imageView else { return }
        let duration: TimeInterval = PromiseContext.isExecutingNow
            ? 0 // no transition if we're synchronous
            : 0.25
        UIView.transition(with: imageView, duration: duration, options: .transitionCrossDissolve, animations: {
            imageView.image = image
        })
    })
```

### Promise Helpers

There are a few helper functions that can be used to deal with multiple promises.

#### `when(fulfilled:)`

`when(fulfilled:)` is a global function that takes either an array of promises or 2–6 promises as separate arguments, and returns a single promise that is
eventually fulfilled with the values of all input promises. With the array version all input promises must have the same type and the result is fulfilled with an array.
With the separate argument version the promises may have unique value types (but the same error type) and the result is fulfilled with a tuple.

If any of the input promises is rejected or cancelled, the resulting promise is immediately rejected or cancelled as well. If multiple input promises are rejected or
cancelled, the first such one affects the result.

This function has an optional parameter `cancelOnFailure:` that, if provided as `true`, will cancel all input promises if any of them are rejected.

#### `when(first:)`

`when(first:)` is a global function that takes an array of promises of the same type, and returns a single promise that eventually adopts the same value or error as
the first input promise that gets fulfilled or rejected. Cancelled input promises are ignored, unless all input promsies are cancelled, at which point the resulting
promise will be cancelled as well.

This function has an optional parameter `cancelRemaining:` that, if provided as `true`, will cancel the remaining input promises as soon as one of them is fulfilled
or rejected.

#### `Promise.timeout(on:delay:)`

`Promise.timeout(on:delay:)` is a method that returns a new promise that adopts the same value as the receiver, or is rejected with an error if the receiver isn't
resolved within the given interval.

#### `Promise.delay(on:_:)`

`Promise.delay(on:_:)` is a method that returns a new promise that adopts the same result as the receiver after the specified delay. It is intended primarily for
testing purposes.

### Objective-C

Tomorrowland has Obj-C compatibility in the form of `TWLPromise<ValueType,ErrorType>`. This is a parallel promise implementation that can be bridged to/from
`Promise` and supports all of the same functionality. Note that some of the method names are different (due to lack of overloading), and while `TWLPromise` is
generic over its types, the return values of callback registration methods that return new promises are not parameterized (due to inability to have generic methods).

### Callback lifetimes

Callbacks registered on promises will be retained until the promise is resolved. If a callback is invoked (or would be invoked if the relevant invalidation token hadn't
been invalidated), Tomorrowland guarantees that it will release the callback on the context it was invoked on. If the callback is not invoked (e.g. it's a `then(on:_:)`
callback but the promise was rejected) then no guarantees are made as to the context the callback is released on. If you need to ensure it's released on the
appropriate context (e.g. if it captures an object that must deallocate on the main thread) then you can use `.always` or one of the `.mapResult` variants.

## Requirements

Requires a minimum of iOS 9, macOS 10.10, watchOS 2.0, or tvOS 9.0.

## License

Licensed under either of
* Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
http://www.apache.org/licenses/LICENSE-2.0)
* MIT license ([LICENSE-MIT](LICENSE-MIT) or
http://opensource.org/licenses/MIT) at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you shall be dual licensed as above, without any additional terms or conditions.

## Version History

### Development

- Slightly optimized stack usage when chaining one promise to another.

### v1.3.0

- Add `PromiseContext.isExecutingNow` (`TWLPromiseContext.isExecutingNow` in Obj-C) that returns `true` if accessed from within a callback registered
  with `.nowOr(_:)` and executing synchronously, or `false` otherwise. If accessed from within a callback (or `Promise.init(on:_:)`) registered with
  `.immediate` and running synchronously, it inherits the surrounding scope's `PromiseContext.isExecutingNow` flag. This is intended to allow
  `Promise(on: .immediate, { … })` to query the surrounding scope's flag ([#53][]).
- Add convenience methods to Obj-C for doing then+catch together, as this is a common pattern and chaining Obj-C methods is a little awkward ([#45][]).
- Change `Promise.timeout`'s default context to `.nowOr(.auto)` for the `Error` overload as well.
- Change the behavior of `Promise.timeout(on:delay:)` when the `delay` is less than or equal to zero, the `context` is `.immediate` or `.nowOr(_:)`, and the
  upstream promise hasn't resolved yet. Previously the timeout would occur asynchronously and the upstream promise would get a chance to race the timeout. With
  the new behavior the timeout occurs synchronously ([#49][]).

[#45]: https://github.com/lilyball/Tomorrowland/issues/45 "Add convenience methods to Obj-C for then+catch"
[#49]: https://github.com/lilyball/Tomorrowland/issues/49 "timeout should skip the timer if the delay is <= 0"
[#53]: https://github.com/lilyball/Tomorrowland/issues/53 "Can we add something like PromiseContext.isExecutingNow?"

### v1.2.0

- Add `PromiseContext.nowOr(context)` (`+[TWLContext nowOrContext:]` in Obj-C) that runs the callback synchronously when registered if the promise
  has already resolved, otherwise registers the callback to run on `context`. This can be used to replace code that previously would have required checking
  `promise.result` prior to registering the callback ([#34][]).
  
  For example:
  
  ```swift
  networkImagePromise.then(on: .nowOr(.main), { [weak button] (image) in
      button?.setImage(image, for: .normal)
  })
  ```
- Add `Promise.Resolver.hasRequestedCancel` (`TWLResolver.cancelRequested` in Obj-C) that returns `true` if the promise has been requested to
  cancel or is already cancelled, or `false` if it hasn't been requested to cancel or is fulfilled or rejected. This can be used when a promise initializer takes
  significant time in a manner not easily interrupted by an `onRequestCancel` handler ([#47][]).
- Change `Promise.timeout`'s default context from `.auto` to `.nowOr(.auto)`. This behaves the same as `.auto` in most cases, except if the receiver has
  already been resolved this will cause the returned promise to likewise already be resolved ([#50][]).
- Ensure `when(first:cancelRemaining:)` returns an already-cancelled promise if all input promises were previously cancelled, instead of cancelling the
  returned promise asynchronously ([#51][]).
- Ensure `when(fulfilled:qos:cancelOnFailure:)` returns an already-resolved promise if either all input promises were previously fulfliled or any input
  promise was previously rejected or cancelled ([#52][]).

[#34]: https://github.com/lilyball/Tomorrowland/issues/34 "Add a .mainImmediate context"
[#47]: https://github.com/lilyball/Tomorrowland/issues/47 "Add Promise.Resolver.isCancelled property"
[#50]: https://github.com/lilyball/Tomorrowland/issues/50 "Consider changing timeout's default context to .nowOr(.auto)"
[#51]: https://github.com/lilyball/Tomorrowland/issues/51 "when(first:cancelRemaining:) won't cancel synchronously if all inputs have cancelled"
[#52]: https://github.com/lilyball/Tomorrowland/issues/52 "when(fulfilled:…) should be able to resolve synchronously"

### v1.1.1

- Fix memory leaks in `PromiseInvalidationToken.requestCancelOnInvalidate(_:)` and
  `PromiseInvalidationToken.chainInvalidation(from:includingCancelWithoutInvalidating:)` when cleaning up `nil` nodes prior to pushing on the
  new node ([#48][]).

[#48]: https://github.com/lilyball/Tomorrowland/issues/48 "Memory leak in PromiseInvalidationToken"

### v1.1.0

- Add new method `.propagatingCancellation(on:cancelRequested:)` that can be used to create a long-lived promise that propagates cancellation from its
  children to its parent while it's still alive. Normally promises don't propagate cancellation until they themselves are released, in case more children are going to be
  added. This new method is intended to be used when deduplicating requests for an asynchronous resource (such as a network load) such that the resource request
  can be cancelled in the event that no children care about it anymore ([#46][]).

[#46]: https://github.com/lilyball/Tomorrowland/issues/46 "A way to hold onto a promise without blocking cancellation propagation from children"

### v1.0.1

- Suppress a warning from the Swift 5.1 compiler about code that the Swift 5.0 compiler requires.

### v1.0.0

- Fix a rather serious bug where `PromiseInvalidationToken`s would not deinit as long as any promise whose callback was tied to the token was still unresolved.
  This meant that the default `invalidateOnDeinit` behavior would not trigger and the callback would still fire even though there were no more external references
  to the token, and this meant any promises configured to be cancelled when the promise invalidated would not cancel. Tokens used purely for
  `requestCancelOnInvalidate(_:)` would still deallocate, and tokens would still deallocate after any associated promises had resolved.
- Tweak the atomic memory ordering used in `PromiseInvalidationToken`s. After a careful re-reading I don't believe I was issuing the correct fences previously,
  making it possible for tokens whose associated promise callbacks were executing concurrently with a call to `requestCancelOnInvalidate(_:)` to read the
  wrong generation value, and for tokens that had `requestCancelOnInvalidate(_:)` invoked concurrently on multiple threads to corrupt the generation.
- Add `PromiseInvalidationToken.chainInvalidation(from:)` to invalidate a token whenever another token invalidates. This allows for building a tree of
  tokens in order to have both fine-grained and bulk invalidation at the same time. Tokens chained together this way stay chained forever ([#43][]).
- Update project file to Swift 5.0. The source already supported this. This change should only affect people using [Carthage][] or anyone adding building this
  framework from source.
- Update the podspec to list both Swift 4.2 and Swift 5.0. With CocoaPods 1.7.0 or later your `Podfile` can now declare which version of Swift it's compatible with.
  For anyone using CocoaPods 1.6 or earlier it will default to Swift 5.0.

[#43]: https://github.com/lilyball/Tomorrowland/issues/43 "Add PromiseInvalidationToken.chainInvalidation(from: PromiseInvalidationToken)"

### v0.6.0

- Make `DelayedPromise` conform to `Equatable` ([#37][]).
- Add convenience functions for working with `Swift.Result` ([#39][]).
- Mark all the deprecated functions as unavailable instead. This restores the ability to write code like `promise.then({ foo?($0) })` without it incorrectly
  resolving to the deprecated form of `map(_:)` ([#35][]).
- Rename `Promise.init(result:)` and `Promise.init(on:result:after:)` to `Promise.init(with:)` and `Promise.init(on:with:after:)` ([#40][]).

[#35]: https://github.com/lilyball/Tomorrowland/issues/35 "Move deprecations to unavailable"
[#37]: https://github.com/lilyball/Tomorrowland/issues/37 "DelayedPromise should conform to Equatable"
[#39]: https://github.com/lilyball/Tomorrowland/issues/39 "Add some minimal support for Result"
[#40]: https://github.com/lilyball/Tomorrowland/issues/40 "Rename Promise.init(result:) to Promise.init(with:)"

### v0.5.1

- When chaining multiple `.main` context blocks in the same runloop pass, ensure we release each block before executing the next one.
- Ensure that if a user-supplied callback is invoked, it is also released on the context where it was invoked ([#38][]).
  
  This guarantee is only made for callbacks that are invoked (ignoring tokens). What this means is when using e.g. `.then(on:_:)` if the promise is fulfilled, the
  `onSuccess` block will be released on the provided context, but if the promise is rejected no such guarantee is made. If you rely on the context it's released on
  (e.g. it captures an object that must deallocate on the main thread) then you can use `.always` or one of the `mapResult` variants.

[#38]: https://github.com/lilyball/Tomorrowland/issues/38 "Dealloc completion blocks on the context they're scheduled on"

### v0.5.0

- Rename a lot of methods on `Promise` and `TokenPromise` ([#5][]).

  This gets rid of most overrides, leaving the only overridden methods to be ones that handle either `Swift.Error` or `E: Swift.Error`, and even these overrides
  are removed in the Swift 5 compiler.
  
  `then`  is now `map` or `flatMap`, `recover`'s override is now `flatMapError`, `always`'s override is now `flatMapResult`, and similar renames were made for
  the `try` variants.
- Add a new `then` method whose block returns `Void`. The returned promise resolves to the same result as the original promise.
- Add new `mapError` and `tryMapError` methods.
- Add new `mapResult` and `tryMapResult` methods.
- Extend `tryFlatMapError` to be available on all `Promise`s instead of just those whose error type is `Swift.Error`.
- Remove the default `.auto` value for the `on context:` parameter to most calls. It's now only provided for the "terminal" callbacks, the ones that don't return a
  value from the handler. This avoids the common problem of running trivial maps on the main thread unnecessarily ([#33][]).

[#5]: https://github.com/lilyball/Tomorrowland/issues/5 "Should we adopt .map, .flatMap terminology?"
[#33]: https://github.com/lilyball/Tomorrowland/issues/33 "Remove default context parameter from map, etc"

### v0.4.3

- Fix compatibility with Xcode 10.2 / Swift 5 compiler ([#31][], [SR-9753][]).

[#31]: https://github.com/lilyball/Tomorrowland/issues/31 "\"Ambiguous use of Promise.pipe(to:)\" error building with Xcode 10.2 Beta 1 in Swift 4 mode"
[SR-9753]: https://bugs.swift.org/browse/SR-9753 "REGRESSION: Ambiguity involving overloads and generics constrained by Error"

### v0.4.2

- Add new method `Promise.Resolver.resolve(with: somePromise)` that resolves the receiver using another promise ([#30][]).

[#30]: https://github.com/lilyball/Tomorrowland/issues/30 "Add Promise.Resolver.resolve(with: somePromise)"

### v0.4.1

- Mark `PromiseCancellable.requestCancel()` as `public` ([#29][]).

[#29]: https://github.com/lilyball/Tomorrowland/issues/29 "PromiseCancellable.requestCancel() isn't public"

### v0.4

- Improve the behavior of `.delay(on:_:)` and `.timeout(on:delay:)` when using `PromiseContext.operationQueue`. The relevant operation is now added
  to the queue immediately and only becomes ready once the delay/timeout has elapsed.
- Add `-[TWLPromise initCancelled]` to construct a pre-cancelled promise.
- Add `Promise.init(on:fulfilled:after:)`, `Promise.init(on:rejected:after:)`, and `Promise.init(on:result:after:)`. These initializers produce
  something akin to `Promise(fulfilled: value).delay(after)` except they respond to cancellation immediately. This makes them more suitable for use as
  cancellable timers, as opposed to `.delay(_:)` which is more intended for debugging ([#27][]).
- Try to clean up the callback list when calling `PromiseInvalidationToken.requestCancelOnInvalidate(_:)`. Any deallocated promises at the head of the
  callback list will be removed. This will help keep the callback list from growing uncontrollably when a token is used merely to cancel all promises when the owner
  deallocates as opposed to being periodically invalidated during its lifetime ([#25][]).
- Cancel the `.delay(_:)` timer if `.requestCancel()` is invoked and the upstream promise cancelled. This way requested cancels will skip the delay, but
  unexpected cancels will still delay the result ([#26][]).

[#25]: https://github.com/lilyball/Tomorrowland/issues/25 "PromiseInvalidationTokenBox should clean up the callback list when possible"
[#26]: https://github.com/lilyball/Tomorrowland/issues/26 "Make delay cancelable"
[#27]: https://github.com/lilyball/Tomorrowland/issues/27 "Add Promise(fulfilled:after:) and Promise(rejected:after:)"


### v0.3.4

- Add `PromiseInvalidationToken.cancelWithoutInvalidating()`. This method cancels any associated promises without invalidating the token, thus
  allowing for any `onCancel` and `always` handlers on the promises to fire ([#23][]).
- Add missing `Promise`↔`ObjCPromise` bridging methods for the case of `Value: AnyObject, Error == Swift.Error` ([#24][]).

[#23]: https://github.com/lilyball/Tomorrowland/issues/23 "Add PromiseInvalidationToken.cancelWithoutInvalidation()"
[#24]: https://github.com/lilyball/Tomorrowland/issues/24 "Add Swift<->ObjC bridging methods for Value: AnyObject, Error == Swift.Error"

### v0.3.3

- Add initializer `Promise.init(result:)` for creating a `Promise` from a `PromiseResult`.
- Fix cancellation propagation issue with `when(resolved: …, cancelOnFailure: true)` and `when(first: …, cancelRemaining: true)` ([#20][]).
- Update some documentation.
- Enable `APPLICATION_EXTENSION_API_ONLY`.

[#20]: https://github.com/lilyball/Tomorrowland/issues/20 "when does not work as expected when using `cancelOnFailure: true`"

### v0.3.2

- Add `Hashable` / `Equatable` conformance to `PromiseInvalidationToken`.
- Add a new type `TokenPromise` that wraps a `Promise` and automatically applies a `PromiseInvalidationToken`. This API is Swift-only.

### v0.3.1

- Add a missing Swift->ObjC convenience bridging method.
- Add `Decodable` conformance to `NoError`.
- Add method `Promise.fork(_:)`.
- Fix compilation failure when targeting 32-bit iOS 9 simulator in Xcode 9.3.
- Fix cancellation propagation test cases on iOS 9 simulators.

### v0.3

- Add `Promise.requestCancelOnInvalidate(_:)` as a convenience for `token.requestCancelOnInvalidate(_:)`.
- Add `Promise.requestCancelOnDeinit(_:)` as a convenience for adding a token property to an object that invalites on deinit.
- Better support for `OperationQueue` with `delay`/`timeout`. Instead of using the `OperationQueue`'s underlying queue, we instead use a `.userInitiated`
  queue for the timer and hop onto the `OperationQueue` to resolve the promise.

### v0.2

- Implement automatic cancellation propagation and remove the `.linkCancel` option.
- Remove the `cancelOnTimeout:` parameter to `timeout(on:delay:)` in favor of automatic cancellation propagation.
- Automatically invalidate `PromiseInvalidationToken`s on `deinit`. This behavior can be disabled via a parameter to `init`.

### v0.1

Initial alpha release.
