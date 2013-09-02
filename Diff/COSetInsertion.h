#import "COItemGraphEdit.h"

@interface COSetInsertion : COItemGraphEdit
{
	COType type;
	id object;
}
@property (readonly, nonatomic) COType type;
@property (readonly, nonatomic) id object;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			   type: (COType)aType
			 object: (id)anObject;

@end