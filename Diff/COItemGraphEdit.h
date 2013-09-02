#import <Foundation/Foundation.h>
#import <CoreObject/COType.h>

@class ETUUID;


#pragma mark base class

@interface COItemGraphEdit : NSObject <NSCopying>
{
	ETUUID *UUID;
	NSString *attribute;
	id sourceIdentifier;
}

@property (readonly, nonatomic) ETUUID *UUID;
@property (readonly, nonatomic) NSString *attribute;
@property (readonly, nonatomic) id sourceIdentifier;

// NO applyTo: (applying a set of array edits requires a special procedure)
// NO doesntConflictWith: (checking a set of array edits for conflicts requires a special procedure)

- (BOOL) isEqualIgnoringSourceIdentifier: (id)other;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier;

// information

- (NSSet *) insertedEmbeddedItemUUIDs;

- (BOOL) isSameKindOfEdit: (COItemGraphEdit*)anEdit;

@end









