# Tomorrowland

[![Version](https://img.shields.io/badge/version-v0.9-blue.svg)](https://github.com/kballard/Tomorrowland/releases/latest)
![Platforms](https://img.shields.io/badge/platforms-ios%20%7C%20osx%20%7C%20watchos%20%7C%20tvos-lightgrey.svg)
![Languages](https://img.shields.io/badge/languages-swift-orange.svg)
![License](https://img.shields.io/badge/license-MIT%2FApache-blue.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)][Carthage]

[Carthage]: https://github.com/carthage/carthage

Tomorrowland is an implementation of [Promises](https://en.wikipedia.org/wiki/Futures_and_promises) for Swift. A Promise is a wrapper around an asynchronous
task that provides a standard way of subscribing to task resolution as well as chaining promises together.

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
github "kballard/Tomorrowland" master
```

### CocoaPods

Tomorrowland has not yet been submitted to CocoaPods. This will happen when it hits v1.0. In the meantime, you can pull it directly from our repository.

```ruby
pod 'Tomorrowland', :git => 'https://github.com/kballard/Tomorrowland.git'
```

### SwiftPM

Tomorrowland currently relies on a private Obj-C module for its atomics. This arrangement means it is not compatible with Swift Package Manager (as adding
compatibility would necessitate publicly exposing the private Obj-C module).

## Quick Start

### Creating Promises

Promises can be created using code like the following:

```swift
let promise = Promise<String,Error>(on: .utility, { (resolver) in
    let value = try expensiveCalculation()
    resolver.resolve(value)
})
```

The body of this promise runs on the specified `PromiseContext`, which in this case is `.utility` (which means `DispatchQueue.global(qos: .utility)`).
Unlike callbacks, all created promises must specify a context, so as to avoid accidentally running expensive computations on th main thread. The available contexts
include `.main`, every Dispatch QoS, a specific `DispatchQueue`, a specific `OperationQueue`, or the value `.immediate` which means to run the block
synchronously. There's also the special context `.auto`, which evaluates to `.main` on the main thread and `.default` otherwise. This special context is the default
context for all callbacks that don't otherwise specify one.

The body of a `Promise` receives a "resolver", which it must use to fulfill, reject, or cancel the promise. If the resolver goes out of scope without being used, the
promise is automatically cancelled. If the promise's error type is `Error`, the promise body may also throw an error (as seen above), which is then used to reject the
promise. This resolver can also be used to observe cancellation requests using `resolver.onRequestCancel`, as seen here:

```swift
let promise = Promise<Data,Error>(on: .immediate, { (resolver) in
    let task = urlSession.dataTask(with: url, completionHandler: { (data, response, error) in
        if let data = data {
            resolver.fulfill(data)
        } else if case URLError.cancelled? = error {
            resolver.cancel()
        } else {
            resolver.reject(error!)
        }
    })
    resolver.onRequestCancel(on: .immediate, { _ in
        task.cancel()
    })
    task.resume()
})
```

### Using Promises

Once you have a promise, you can register callbacks to be executed when the promise is resolved. As mentioned above, you can specify the context for the
callback, but if you don't specify it then it defaults to `.auto`, which means the main thread if the callback is registered from the main thread, otherwise the dispatch
queue with QoS `.default`.

When you register a callback, the method also returns a `Promise`. In most cases it's a new `Promise` whose value is affected by the callback, and in some cases
it's the same `Promise` you just had, being returned again to make chaining convenient. For example, the `then` callback returns a value which is used to fulfill the
promise returned from `then`. However, `catch` just returns the original `Promise`, so you can call `always` on it.

Most callback registration methods also have versions that allow you to return a `Promise` from your callback. In this event, the resulting `Promise` waits for the
promise you returned to resolve before adopting its value. This allows for easy composition of promises.

```swift
showLoadingIndicator()
fetchUserCredentials().then { (credentials) in
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

Note that when your callback returns a `Promise`, its error type must be the same as the original promise's error type. The exception to this is when the original
promise's error type is `Error` and the callback's returned `Promise` has an error type that is compatible with `Error`. The convenience methods for working with
`Error`-compatible errors don't cover all cases; if you find yourself hitting one of these cases, any `Promise` whose error type conforms to `Error` has a property
`.upcast` that will convert that error into an `Error` to allow for easier composition of promises.

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
        _ = promise?.then(on: .utility, { (data) in
            if let image = UIImage(data: data) {
                return image
            } else {
                throw LoadError.dataIsNotImage
            }
        }).then(token: token, { [weak self] (image) in
            self?.image = image
        })
    }
}
```

`PromiseInvalidationToken` also has a method `.requestCancelOnInvalidate(_:)` that can register any number of `Promise`s to be automatically
requested to cancel (using `.requestCancel()`) the next time the token is invalidated. This is mostly useful in conjunction with the `.linkCancel` option.

#### `.linkCancel`

Most promise callback registration methods have an optional `options:` parameter. Right now there is only one option, called `.linkCancel`. This option makes it
so requesting the resulting `Promise` to cancel automatically requests its parent to cancel. This should be used whenever you have a child promise whose parent is
cancellable and is guaranteed to be non-observable by any other promise. This is also commonly used with `PromiseInvalidationToken`'s
`requestCancelOnInvalidate(_:)` method, so invalidating the child promise's callbacks will then automatically cancel the parent.

We might modify the above `URLImageView` to take advantage of this like so:

```swift
class URLImageView: UIImageView {
    private let invalidationToken = PromiseInvalidationToken()
    
    enum LoadError: Error {
        case dataIsNotImage
    }
    
    /// Loads an image from the URL and displays it in the image view.
    func loadImage(from url: URL) {
        invalidationToken.invalidate()
        // Note: dataTaskAsPromise does not actually exist
        let promise = URLSession.shared.dataTaskAsPromise(with: url)
            .then(on: .utility, options: [.linkCancel], { (data) in
                if let image = UIImage(data: data) {
                    return image
                } else {
                    throw LoadError.dataIsNotImage
                }
            }).then(token: token, options: [.linkCancel], { [weak self] (image) in
                self?.image = image
            })
        token.requestCancelOnInvalidate(promise)
    }
}
```

This is particularly useful when writing methods that return chained promises

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

#### `Promise.delay(on:_:)`

`Promise.delay(on:_:)` is a method that returns a new promise that adopts the same result as the receiver after the specified delay. It is intended primarily for
testing purposes.

## Requirements

Requires a minimum of iOS 8, macOS 10.10, watchOS 2.0, or tvOS 9.0.

## License

Licensed under either of
* Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
http://www.apache.org/licenses/LICENSE-2.0)
* MIT license ([LICENSE-MIT](LICENSE-MIT) or
http://opensource.org/licenses/MIT) at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you shall be dual licensed as above, without any additional terms or conditions.

## Version History

No releases yet.
