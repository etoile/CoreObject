#import <Foundation/Foundation.h>
#import <EtoileFoundation/Macros.h>

/**
 * @group Language Extensions
 *
 * Adds support for traits and mixins to Objective-C, as methods of class
 * composition, in addition to inheritance.  Mixins allow a single class to be
 * in the class hierarchy in multiple locations, while traits allow methods to
 * be added to another class.  Traits are similar to categories in their
 * composition while mixins are similar to classes.
 */
@interface NSObject (Trait)
/**
 * Apply aClass to this class as a trait.
 */
+ (void) applyTraitFromClass:(Class)aClass;
+ (void) applyTraitFromClass: (Class)aClass 
         excludedMethodNames: (NSSet *)excludedNames
          aliasedMethodNames: (NSDictionary *)aliasedNames;
+ (void) applyTraitFromClass: (Class)aClass 
         excludedMethodNames: (NSSet *)excludedNames
          aliasedMethodNames: (NSDictionary *)aliasedNames
              allowsOverride: (BOOL)override;
/**
 * Compose aClass with this one using mixin-style composition rules and
 * traits-style composition.  Methods in aClass may replace methods in this
 * class if their types match.
 */
//+ (void) flattenedMixinFromClass:(Class)aClass;
@end

/** Exception thrown by NSObject(Trait). */
EMIT_STRING(ETTraitInvalidSizeException)
/** Exception thrown by NSObject(Trait). */
EMIT_STRING(ETTraitIVarTypeMismatchException)
/** Exception thrown by NSObject(Trait). */
EMIT_STRING(ETTraitMethodTypeMismatchException)
/** Exception thrown by NSObject(Trait). */
EMIT_STRING(ETTraitApplicationException)
