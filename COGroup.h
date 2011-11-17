#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <ObjectMerging/COContainer.h>

/**
 * COColection is an unordered, weak (an object can be in any number of collections)
 * collection class.
 */
@interface COGroup : COContainer // FIXME: it's only a subclass of COContainer to avoid code duplication, since the code is identical
{
}

/*+ (COGroup *) allObjectGroup;

+ (void) registerLibrary: (COOGroup *)aGroup forType: (NSString *)libraryType;
+ (COGroup *) libraryForType: (NSString *)libraryType;
+ (id) photoLibrary;
+ (id) musicLibrary;*/

@end


@interface COSmartGroup : COGroup
{
	COGroup *targetGroup;
}

@property (nonatomic, retain) COGroup *targetGroup;

@end
