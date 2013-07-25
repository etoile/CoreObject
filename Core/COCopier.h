#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COItemGraph.h>

// TODO: Store the state relating to copying, e.g. which context to copy into.

@interface COCopier : NSObject


// TODO: Implement
/**
 * Creates a copier to copy into the destination graph.
 *
 * The entity descriptions for COItems will be obtained from the given model
 * description repository.
 *
 * We need to the model description for 
 */
//- (id) initWithDestinationGraph: (id<COItemGraph>)dest
//     modelDescriptionRepository: (ETModelDescriptionRepository *)repository;

/**
 * Basic copying method implementing the semantics in "copy semantics.key".
 *
 * Handles copying into the same context, or another one.
 */
- (ETUUID*) copyItemWithUUID: (ETUUID*)aUUID
                   fromGraph: (id<COItemGraph>)source
                     toGraph: (id<COItemGraph>)dest;
@end
