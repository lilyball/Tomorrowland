//
//  ObjCBridgingGenerics.swift
//  TomorrowlandTests
//
//  Created by Lily Ballard on 3/25/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

// This is a simple generic wrapper around the ObjC promise bridging machinery.
// It's meant to prove that there's no ambiguity when using generics.

import Tomorrowland
import Foundation.NSError

private protocol _BridgeToObjC {
    associatedtype _ObjCType: AnyObject
    func _bridgeToObjC() -> _ObjCType
}

private protocol _BridgeToSwift {
    associatedtype _SwiftType
    func _bridgeToSwift() -> _SwiftType
}

private extension Promise {
    init<V, E>(_ promise: ObjCPromise<V,E>)
        where V: _BridgeToSwift, V._SwiftType == Value,
        E: _BridgeToSwift, E._SwiftType == Error
    {
        self.init(bridging: promise, mapValue: { $0._bridgeToSwift() }, mapError: { $0._bridgeToSwift() })
    }
}

private extension Promise where Error == Swift.Error {
    init<V>(_ promise: ObjCPromise<V,NSError>)
        where V: _BridgeToSwift, V._SwiftType == Value
    {
        self.init(bridging: promise, mapValue: { $0._bridgeToSwift() })
    }
}

private extension Promise where Value: _BridgeToObjC {
    func objc<E: AnyObject>(mapError: @escaping (Error) -> E) -> ObjCPromise<Value._ObjCType, E> {
        return objc(mapValue: { $0._bridgeToObjC() }, mapError: mapError)
    }
}

private extension Promise where Error: _BridgeToObjC {
    func objc<V: AnyObject>(mapValue: @escaping (Value) -> V) -> ObjCPromise<V, Error._ObjCType> {
        return objc(mapValue: mapValue, mapError: { $0._bridgeToObjC() })
    }
}

private extension Promise where Value: _BridgeToObjC, Error: _BridgeToObjC {
    func objc() -> ObjCPromise<Value._ObjCType, Error._ObjCType> {
        return objc(mapValue: { $0._bridgeToObjC() }, mapError: { $0._bridgeToObjC() })
    }
}
