#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <ObjectMerging/COObject.h>

/**
 * COContainer is a COObject subclass which has an ordered, strong container
 * (contained objects can only be in one COContainer).
 */
@interface COContainer : COObject <ETCollection, ETCollectionMutation>
{
}

@end
