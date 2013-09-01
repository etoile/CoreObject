#import "Document.h"

@implementation Document

+ (void)initialize
{
	if (self == [Document class])
	{
		ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
		
		// Document entity
		{
			ETEntityDescription *docEntity = [ETEntityDescription descriptionWithName: @"Document"];
			
			ETPropertyDescription *screenRectProperty = [ETPropertyDescription descriptionWithName: @"screenRect"
																							  type: (id)@"NSRect"];
			ETPropertyDescription *isOpenProperty = [ETPropertyDescription descriptionWithName: @"isOpen"
																						  type: (id)@"NSNumber"];
			ETPropertyDescription *documentTypeProperty = [ETPropertyDescription descriptionWithName: @"documentType"
																								type: (id)@"NSString"];                                                                                            
			ETPropertyDescription *documentNameProperty = [ETPropertyDescription descriptionWithName: @"documentName"
																								type: (id)@"NSString"];                                                                                            
			ETPropertyDescription *rootObjectProperty = [ETPropertyDescription descriptionWithName: @"rootObject"
																							  type: (id)@"NSObject"];
			[rootObjectProperty setOpposite: (id)@"DocumentItem.document"];
			
			[Tag class];
			ETPropertyDescription *tagsProperty = [ETPropertyDescription descriptionWithName: @"tags"
																						type: (id)@"Tag"];
			[tagsProperty setMultivalued: YES];
			
			
			[docEntity setPropertyDescriptions: A(screenRectProperty, isOpenProperty, documentTypeProperty, rootObjectProperty, documentNameProperty, tagsProperty)];
			
			[repo addUnresolvedDescription: docEntity];
			
			[repo setEntityDescription: docEntity
							  forClass: [Document class]];
		}
		[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
	}
}

- (NSRect) screenRect
{
	return [[self valueForProperty:@"screenRect"] rectValue];
}
- (void) setScreenRect:(NSRect)r
{
    [self willChangeValueForProperty: @"screenRect"];
    [self setPrimitiveValue: [NSValue valueWithRect: r] forKey: @"screenRect"];
	[self didChangeValueForProperty: @"screenRect"];
}

- (BOOL) isOpen
{
	return [[self valueForProperty: @"isOpen"] boolValue];
}
- (void) setIsOpen:(BOOL)i
{
	[self willChangeValueForProperty: @"isOpen"];
    [self setPrimitiveValue: @(i) forKey: @"isOpen"];
	[self didChangeValueForProperty: @"isOpen"];
}

@dynamic documentType;
@dynamic rootObject;
@dynamic documentName;
@dynamic tags;

- (void) addTag: (Tag *)tag
{
    [[self mutableSetValueForKey: @"tags"] addObject: tag];
}
- (void) removeTag: (Tag *)tag
{
    [[self mutableSetValueForKey: @"tags"] removeObject: tag];}

@end
