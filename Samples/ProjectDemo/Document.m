#import "Document.h"

@implementation Document

+ (void)initialize
{
	if (self == [Document class])
	{
		ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
		
		// DocumentItem entity (super-entity of OutlineItem, DraawingItem, TextItem)
		{
			ETEntityDescription *docItemEntity = [ETEntityDescription descriptionWithName: @"DocumentItem"];
			
			ETPropertyDescription *documentProperty = [ETPropertyDescription descriptionWithName: @"document"
																							type: (id)@"Document"];
			[documentProperty setIsContainer: YES];
			
			[docItemEntity setPropertyDescriptions: A(documentProperty)];
			
			[repo addUnresolvedDescription: docItemEntity];
		}
		
		
		// Document entity
		{
			ETEntityDescription *docEntity = [ETEntityDescription descriptionWithName: @"Document"];
			
			ETPropertyDescription *screenRectProperty = [ETPropertyDescription descriptionWithName: @"screenRect"
																							  type: (id)@"NSString"];
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

- (NSRect) screenRectValue
{
	[self willAccessValueForProperty: @"screenRect"]; // FIXME: shouldn't need, valueForProperty: is broken
	return NSRectFromString([self valueForProperty:@"screenRect"]);
}
- (void) setScreenRectValue:(NSRect)r
{
	[self willChangeValueForProperty: @"screenRect"]; // FIXME: shouldn't need; setValue:forProperty: is broken
	[self setValue: NSStringFromRect(r) forProperty:@"screenRect"];
	[self didChangeValueForProperty: @"screenRect"]; // FIXME: shouldn't need; setValue:forProperty: is broken
}

- (BOOL) isOpen
{
	[self willAccessValueForProperty: @"isOpen"];
	return isOpen;
}
- (void) setIsOpen:(BOOL)i
{
	[self willChangeValueForProperty: @"isOpen"];
	isOpen = i;
	[self didChangeValueForProperty: @"isOpen"];
}

- (NSString*) documentType
{
	[self willAccessValueForProperty: @"documentType"];
	return documentType;
}
- (void) setDocumentType:(NSString*)t
{
	[self willChangeValueForProperty: @"documentType"];
	ASSIGN(documentType, t);
	[self didChangeValueForProperty: @"documentType"];
}

- (id) rootObject
{
	[self willAccessValueForProperty: @"rootObject"];
	return rootObject;
}
- (void) setRootObject:(id)r
{
	[self willChangeValueForProperty: @"rootObject"];
	ASSIGN(rootObject, r);
	[self didChangeValueForProperty: @"rootObject"];
}

- (NSString*) documentName
{
	[self willAccessValueForProperty: @"documentName"];
	return documentName;
}
- (void) setDocumentName:(NSString*)n
{
	[self willChangeValueForProperty: @"documentName"];
	ASSIGN(documentName, n);
	[self didChangeValueForProperty: @"documentName"];
}

- (NSSet*) tags
{
	[self willAccessValueForProperty: @"tags"];
	return tags;
}
- (void) addTag: (Tag *)tag
{
	[self willChangeValueForProperty: @"tags"];
	[tags addObject: tag];
	[self didChangeValueForProperty: @"tags"];
}
- (void) removeTag: (Tag *)tag
{
	[self willChangeValueForProperty: @"tags"];
	[tags removeObject: tag];
	[self didChangeValueForProperty: @"tags"];
}

- (void)dealloc
{
	[documentType release];
	[documentName release];
	[rootObject release];
	[tags release];
	[super dealloc];
}

@end
