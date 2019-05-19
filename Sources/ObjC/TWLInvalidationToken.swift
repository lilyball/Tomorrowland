//
//  TWLInvalidationToken.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 1/1/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Foundation

/// An invalidation token that can be used to cancel callbacks registered to a `TWLPromise`.
@objc(TWLInvalidationToken)
@objcMembers
public final class ObjCPromiseInvalidationToken: NSObject {
    fileprivate let _token: PromiseInvalidationToken
    
    /// Creates and returns a new `TWLInvalidationToken`.
    ///
    /// The token automatically invalidates itself when deallocated. See `-initInvalidateOnDealloc:`
    /// for details.
    public convenience override init() {
        self.init(invalidateOnDealloc: true)
    }
    
    /// Creates and returns a new `TWLInvalidationToken`.
    ///
    /// - Parameter invalidateOnDealloc: If `YES` the token will invalidate itself when deallocated.
    ///   If `NO` it only invalidates if you explicitly call `-invalidate`. Invalidating on dealloc
    ///   is primarily useful in conjunction with `-requestCancelOnInvalidate:` so you don't have to
    ///   cancel your promises when the object that owns the invalidation token deallocates.
    @objc(initInvalidateOnDealloc:)
    public init(invalidateOnDealloc: Bool) {
        _token = PromiseInvalidationToken(invalidateOnDeinit: invalidateOnDealloc)
        super.init()
    }
    
    /// Creates and returns a new `TWLInvalidationToken`.
    ///
    /// - Parameter invalidateOnDealloc: If `YES` the token will invalidate itself when deallocated.
    ///   If `NO` it only invalidates if you explicitly call `-invalidate`. Invalidating on dealloc
    ///   is primarily useful in conjunction with `-requestCancelOnInvalidate:` so you don't have to
    ///   cancel your promises when the object that owns the invalidation token deallocates.
    @available(swift, obsoleted: 1.0)
    @objc(newInvalidateOnDealloc:)
    public class func new(invalidateOnDealloc: Bool) -> ObjCPromiseInvalidationToken {
        return self.init(invalidateOnDealloc: invalidateOnDealloc)
    }
    
    public init(_ token: PromiseInvalidationToken) {
        _token = token
        super.init()
    }
    
    /// Invalidates the token and cancels any associated promises.
    ///
    /// After invoking this method, all `TWLPromise` callbacks registered with this token will be
    /// suppressed. Any callbacks whose return value is used for a subsequent promise (e.g. with
    /// `-thenOnContext:token:handler:`) will result in a cancelled promise instead if the callback
    /// would otherwise have been executed.
    ///
    /// In addition, any promises that have been registered with `-requestCancelOnInvalidate:` will
    /// be requested to cancel.
    public func invalidate() {
        _token.invalidate()
    }
    
    /// Cancels any associated promises without invalidating the token.
    ///
    /// After invoking this method, any promises that have been registered with
    /// `requestCancelOnInvalidate(_:)` will be requested to cancel.
    public func cancelWithoutInvalidating() {
        _token.cancelWithoutInvalidating()
    }
    
    /// Registers a `TWLPromise` to be requested to cancel automatically when the token is
    /// invalidated.
    public func requestCancelOnInvalidate<V,E>(_ promise: ObjCPromise<V,E>) {
        _token.requestCancelOnInvalidate(promise)
    }
    
    /// Registers a `TWLPromise` to be requested to cancel automatically when the token is
    /// invalidated.
    @available(swift, obsoleted: 1.0)
    @objc(requestCancelOnInvalidate:)
    public func __objc_requestCancelOnInvalidate(_ promise: ObjCPromise<AnyObject,AnyObject>) {
        _token.requestCancelOnInvalidate(promise)
    }
    
    @objc(box) // hack to allow TWLPromise to query this
    internal var box: TWLPromiseInvalidationTokenBox {
        return _token.__objcBox
    }
}

extension PromiseInvalidationToken {
    public init(_ token: ObjCPromiseInvalidationToken) {
        self = token._token
    }
}
