#import "COItemGraphEdit.h"

@interface COSetAttribute : COItemGraphEdit
{
	COType type;
	id value;
}
@property (readonly, nonatomic) COType type;
@property (readonly, nonatomic) id value;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			   type: (COType)aType
			  value: (id)aValue;

@end
