#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COContainer.h>

/**
 * COColection is an unordered, weak (an object can be in any number of collections)
 * collection class.
 */
@interface COCollection : COContainer // FIXME: it's only a subclass of COContainer to avoid code duplication, since the code is identical
{
}

@end
