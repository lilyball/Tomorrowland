//
//  ObjectiveC.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 2/4/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Foundation
import ObjectiveC

extension Promise {
    /// Requests that the `Promise` should be cancelled when the object deinits.
    ///
    /// This is equivalent to having the object hold a `PromiseInvalidationToken` in a property
    /// (configured to invalidate on deinit) and requesting the promise cancel on that token.
    ///
    /// - Parameter object: Any object. When the object deinits the receiver will be requested to
    ///   cancel.
    /// - Returns: The receiver. This value can be ignored.
    @discardableResult
    public func requestCancelOnDeinit(_ object: AnyObject) -> Promise<Value,Error> {
        // We store a PromiseInvalidationToken on the object using associated objects.
        // As an optimization, we try to reuse tokens when possible. For safety's sake we can't just
        // use a single associated object key or we'll have a problem in a multithreaded scenario.
        // So instead we'll use a separate key per thread.
        let keyObject: AnyObject
        if let object_ = Thread.current.threadDictionary[tokenKey] {
            keyObject = object_ as AnyObject
        } else {
            keyObject = NSObject()
            Thread.current.threadDictionary[tokenKey] = keyObject
        }
        let key = UnsafeRawPointer(Unmanaged.passUnretained(keyObject).toOpaque())
        // NB: We don't need an autorelease pool here because objc_getAssociatedObject only
        // autoreleases the returned value when using an atomic association policy, and we're using
        // a nonatomic one.
        if let token = objc_getAssociatedObject(object, key) as? PromiseInvalidationToken {
            requestCancelOnInvalidate(token)
        } else {
            let token = PromiseInvalidationToken()
            objc_setAssociatedObject(object, key, token, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            requestCancelOnInvalidate(token)
        }
        return self
    }
}

private let tokenKey = ThreadDictionaryKey("key for PromiseInvalidationToken")

private class ThreadDictionaryKey: NSObject, NSCopying {
    let _description: String
    
    init(_ description: String) {
        _description = description
        super.init()
    }
    
    override var description: String {
        let address = UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque())
        return "<\(type(of: self)): 0x\(String(address, radix: 16)) \(_description)>"
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
}
