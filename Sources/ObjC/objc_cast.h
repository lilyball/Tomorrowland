//
//  objc_cast.h
//  Tomorrowland
//
//  Created by Kevin Ballard on 1/4/18.
//  Copyright © 2018 Kevin Ballard. All rights reserved.
//

#import <Foundation/Foundation.h>

// NB: We can't use nullability annotations here or it claims we need one on `T`, but we can't put
// one there or we get an error when we try and call it with a non-pointer template parameter.

/// Returns \c object cast to \c T* iff it's a member of that class.
///
/// \param object An Obj-C object. May be \c nil.
/// \returns That same object cast to \c T* or \c nil if \a object is \c nil or isn't a member of \c
/// T.
template<class T>
T *objc_cast(id object) {
    if ([object isKindOfClass:[T class]]) {
        return reinterpret_cast<T*>(object);
    } else {
        return nil;
    }
}
