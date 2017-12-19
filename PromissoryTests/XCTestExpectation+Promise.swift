//
//  XCTestExpectation+Promise.swift
//  PromissoryTests
//
//  Created by Kevin Ballard on 12/18/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//

import XCTest
import Promissory

extension XCTestExpectation {
    
}

class PromiseExpectation: XCTestExpectation {
    init<T,E>(description: String? = nil, onSuccess promise: Promise<T,E>) {
        super.init(description: description ?? "Expectation for \(type(of: promise)) success")
        
    }
}
