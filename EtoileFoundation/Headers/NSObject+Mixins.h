#import <Foundation/Foundation.h>

/**
 * Adds support for traits and mixins to Objective-C, as methods of class
 * composition, in addition to inheritance.  Mixins allow a single class to be
 * in the class hierarchy in multiple locations, while traits allow methods to
 * be added to another class.  Traits are similar to categories in their
 * composition while mixins are similar to classes.
 */
@interface NSObject (Mixins)
/** 
 * Apply aClass to this class as a mixin.
 */
+ (void) mixInClass:(Class)aClass;
/**
 * Compose aClass with this one as a trait.
 */
+ (void) applyTraitsFromClass:(Class)aClass;
/**
 * Compose aClass with this one using mixin-style composition rules and
 * traits-style composition.  Methods in aClass may replace methods in this
 * class if their types match.
 */
+ (void) flattenedMixinFromClass:(Class)aClass;
@end
