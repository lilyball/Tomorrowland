//
//  TWLPromise+Convenience.m
//  Tomorrowland
//
//  Created by Lily Ballard on 5/23/20.
//  Copyright © 2020 Lily Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLPromise+Convenience.h"

@implementation TWLPromise (Convenience)

- (TWLPromise *)then:(void (^)(id value))thenHandler catch:(void (^)(id error))catchHandler {
    return [[self then:thenHandler] catch:catchHandler];
}

- (TWLPromise *)onContext:(TWLContext *)context then:(void (^)(id value))thenHandler catch:(void (^)(id error))catchHandler {
    return [[self thenOnContext:context handler:thenHandler] catchOnContext:context handler:catchHandler];
}

- (TWLPromise *)onContext:(TWLContext *)context token:(nullable TWLInvalidationToken *)token then:(void (^)(id value))thenHandler catch:(void (^)(id error))catchHandler {
    return [[self thenOnContext:context token:token handler:thenHandler] catchOnContext:context token:token handler:catchHandler];
}

@end
