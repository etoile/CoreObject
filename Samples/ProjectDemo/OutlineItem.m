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
		[outlineEntity setParent: @"DocumentItem"];
		
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

- (id)initWithParent: (OutlineItem*)p context: (COEditingContext*)ctx
{
	self = [super initWithContext: ctx];
	contents = [[NSMutableArray alloc] init];
	[self setParent: p];
	[self setLabel:@"Untitled Item"];
	return self;
}

- (void)dealloc
{
	[contents release];
	[label release];
	[super dealloc];
}

/* Accessor Methods */

- (NSString*)label
{
	[self willAccessValueForProperty: @"label"];
	return label;
}
- (void)setLabel:(NSString*)l
{
	[self willChangeValueForProperty: @"label"];
	ASSIGN(label, l);
	[self didChangeValueForProperty: @"label"];
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


- (NSArray *)contents
{
	[self willAccessValueForProperty: @"contents"];
	return contents;
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
	[self willChangeValueForProperty: @"contents"];
	[contents insertObject: item atIndex: index];
	[self didChangeValueForProperty: @"contents"];
	[item setParent: self];
}
- (void) removeItemAtIndex: (NSUInteger)index
{
	[self willChangeValueForProperty: @"contents"];
	[contents removeObjectAtIndex: index];
	[self didChangeValueForProperty: @"contents"];
}

- (void)didAwaken
{
}

@end
