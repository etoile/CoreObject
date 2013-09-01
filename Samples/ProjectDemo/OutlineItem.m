#import <EtoileFoundation/EtoileFoundation.h>

#import "OutlineItem.h"
#import "Document.h"

@implementation OutlineItem

+ (void)initialize
{
	if (self == [OutlineItem class])
	{
		ETEntityDescription *outlineEntity = [ETEntityDescription descriptionWithName: @"OutlineItem"];
		
		[Document class]; // FIXME: ugly hack to ensure the DocumentItem (superentity of OutlineItem) is registered
		[outlineEntity setParent: (id)@"DocumentItem"];
		
		ETPropertyDescription *parentProperty = [ETPropertyDescription descriptionWithName: @"parent"
																					  type: outlineEntity];
		[parentProperty setIsContainer: YES];
		
		
		ETPropertyDescription *contentsProperty = [ETPropertyDescription descriptionWithName: @"contents"
																						type: outlineEntity];
		[contentsProperty setMultivalued: YES];
		[contentsProperty setOpposite: parentProperty];
		[contentsProperty setOrdered: YES];
		assert([contentsProperty isComposite]);
		
		ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
																					 type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
		
		[outlineEntity setPropertyDescriptions: A(parentProperty, contentsProperty, labelProperty)];
		
		[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: outlineEntity];
		[[ETModelDescriptionRepository mainRepository] setEntityDescription: outlineEntity
																   forClass: self];
		
		[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
	}
}

- (id)initWithObjectGraphContext:(COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	[self setLabel:@"Untitled Item"];
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

/* Accessor Methods */

@dynamic label;
@dynamic parent;
@dynamic contents;

- (OutlineItem*)root
{
	id root = self;
	while ([root parent] != nil)
	{
		root = [root parent];
	}
	return root;
}

- (NSArray *)allContents
{
	NSMutableSet *all = [NSMutableSet setWithArray: [self contents]];
	for (OutlineItem *item in [self contents])
	{
		[all addObjectsFromArray: [item allContents]];
	}
	return [all allObjects];
}

- (void) addItem: (OutlineItem*)item
{
	[self addItem: item atIndex: [[self contents] count]];
}

- (void) addItem: (OutlineItem*)item atIndex: (NSUInteger)index
{
	[[self mutableArrayValueForKey: @"contents"] insertObject: item atIndex: index];
}

- (void) removeItemAtIndex: (NSUInteger)index
{
	[[self mutableArrayValueForKey: @"contents"] removeObjectAtIndex: index];}

@end
