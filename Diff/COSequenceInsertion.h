#import "COSequenceModification.h"

@interface COSequenceInsertion : COSequenceModification

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
		   location: (NSUInteger)aLocation
			   type: (COType)aType
			objects: (NSArray *)anArray;

@end
