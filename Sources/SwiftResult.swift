//
//  SwiftResult.swift
//  Tomorrowland
//
//  Created by Lily Ballard on 4/26/19.
//  Copyright © 2019 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#if compiler(>=5)

// Add support for Swift.Result where it makes sense
extension Promise where Error: Swift.Error {
    /// Returns a `Promise` that is already resolved with the given result.
    public init(with result: Result<Value,Error>) {
        self.init(with: PromiseResult(result))
    }
}

extension Promise.Resolver where Error: Swift.Error {
    /// Resolves the promise with the given result.
    ///
    /// If the promise has already been resolved or cancelled, this does nothing.
    public func resolve(with result: Result<Value,Error>) {
        self.resolve(with: PromiseResult(result))
    }
}

extension PromiseResult where Error: Swift.Error {
    /// Returns a `PromiseResult` from a `Result`.
    public init(_ result: Result<Value,Error>) {
        switch result {
        case .success(let value): self = .value(value)
        case .failure(let error): self = .error(error)
        }
    }
}

#endif
