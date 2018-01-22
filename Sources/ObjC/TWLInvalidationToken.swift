//
//  TWLInvalidationToken.swift
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/1/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
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
    
    public override init() {
        _token = PromiseInvalidationToken()
        super.init()
    }
    
    public init(_ token: PromiseInvalidationToken) {
        _token = token
        super.init()
    }
    
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
    
    @objc(generation) // hack to allow TWLPromise to query this
    internal var generation: UInt {
        return _token.generation
    }
}

extension PromiseInvalidationToken {
    public init(_ token: ObjCPromiseInvalidationToken) {
        self = token._token
    }
}

extension ObjCPromise: RequestCancellable {}
