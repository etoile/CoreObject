#import <EtoileFoundation/EtoileFoundation.h>

#import "ItemReference.h"
#import "OutlineItem.h"
#import "Document.h"

@implementation ItemReference

+ (void)initialize
{
	if (self == [ItemReference class])
	{
		ETEntityDescription *itemReference = [ETEntityDescription descriptionWithName: @"ItemReference"];
		
		[Document class]; // FIXME: ugly hack to ensure the DocumentItem (superentity of OutlineItem) is registered
		[itemReference setParent: (id)@"DocumentItem"];
		
		ETPropertyDescription *parentProperty = [ETPropertyDescription descriptionWithName: @"parent"
																					  type: (id)@"Anonymous.OutlineItem"];
		[parentProperty setIsContainer: YES];
		
    ETPropertyDescription *referencedItemProperty = [ETPropertyDescription descriptionWithName: @"referencedItem"
																					 type: (id)@"Anonymous.OutlineItem"];
		
		[itemReference setPropertyDescriptions: A(parentProperty, referencedItemProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: itemReference];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: itemReference
																   forClass: self];
		
		[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
	}
}

- (id)initWithParent: (OutlineItem*)p referencedItem: (OutlineItem*)ref context: (COEditingContext*)ctx
{
	self = [super initWithObjectGraphContext: ctx];
	[self setParent: p];
  [self setReferencedItem: ref];
	return self;
}

- (void)dealloc
{
  DESTROY(referencedItem);
	[super dealloc];
}

/* Accessor Methods */

- (OutlineItem*)referencedItem
{
	[self willAccessValueForProperty: @"referencedItem"];
	return referencedItem;
}
- (void)setReferencedItem:(OutlineItem *)r
{
	[self willChangeValueForProperty: @"referencedItem"];
	ASSIGN(referencedItem, r);
	[self didChangeValueForProperty: @"referencedItem"];
}

- (OutlineItem*)parent
{
	[self willAccessValueForProperty: @"parent"];
	return parent;
}
- (OutlineItem*)root
{
	id root = self;
	while ([root parent] != nil)
	{
		root = [root parent];
	}
	return root;
}
- (void)setParent:(OutlineItem *)p
{
	[self willChangeValueForProperty: @"parent"];
	parent = p;
	[self didChangeValueForProperty: @"parent"];
}

- (void)didAwaken
{
}

- (NSString*)label
{
	return [NSString stringWithFormat: @"Link to %@", [[self referencedItem] uuid]];	
}

@end
