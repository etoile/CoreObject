/*
    Copyright (C) 2011 Eric Wasylishen

    Date:  December 2011
    License:  MIT  (see COPYING)
 */

#import "COItem.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>
#import "COPath.h"
#import "COType.h"
#import "COAttachmentID.h"

NSString *kCOObjectEntityNameProperty = @"org.etoile-project.coreobject.entityname";
NSString *kCOObjectVersionsProperty = @"org.etoile-project.coreobject.versions";
NSString *kCOObjectDomainsProperty = @"org.etoile-project.coreobject.domains";
NSString *kCOObjectIsSharedProperty = @"isShared";

static NSDictionary *copyValueDictionary(NSDictionary *input, BOOL mutable)
{
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	
	for (NSString *key in input)
	{
		id obj = [input objectForKey: key];
		
		if ([obj isKindOfClass: [NSCountedSet class]])
		{
			// FIXME: Always mutable
			[result setObject: obj
					   forKey: key];
		}
		else if ([obj isKindOfClass: [NSSet class]])
		{
			[result setObject: [(mutable ? [NSMutableSet class] : [NSSet class]) setWithSet: obj]
					   forKey: key];
		}
		else if ([obj isKindOfClass: [NSArray class]])
		{
			[result setObject: [(mutable ? [NSMutableArray class] : [NSArray class]) arrayWithArray: obj]
					   forKey: key];
		}
		else
		{
			[result setObject: obj forKey: key];
		}
	}
	
	if (!mutable)
	{
		NSDictionary *immutable = [[NSDictionary alloc] initWithDictionary: result];
		return immutable;
	}
	return result;
}

@implementation COItem

- (id) initWithUUID: (ETUUID *)aUUID
 typesForAttributes: (NSDictionary *)typesForAttributes
valuesForAttributes: (NSDictionary *)valuesForAttributes
{
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(typesForAttributes);
	NILARG_EXCEPTION_TEST(valuesForAttributes);
		
	SUPERINIT;
	uuid =  aUUID;
	// FIXME: These casts are not truly elegant
	types = (NSMutableDictionary *)[[NSDictionary alloc] initWithDictionary: typesForAttributes];
	values = (NSMutableDictionary *)copyValueDictionary(valuesForAttributes, NO);
    
    for (NSString *key in values)
    {
        ETAssert(COTypeValidateObject([[types objectForKey: key] intValue], [values objectForKey: key]));
    }

	return self;
}


+ (COItem *) itemWithTypesForAttributes: (NSDictionary *)typesForAttributes
						 valuesForAttributes: (NSDictionary *)valuesForAttributes
{
	return [[self alloc] initWithUUID: [ETUUID UUID]
					typesForAttributes: typesForAttributes
				   valuesForAttributes: valuesForAttributes];
}

- (ETUUID *)UUID
{
	return uuid;
}

- (NSArray *) attributeNames
{
	return [types allKeys];
}

- (COType) typeForAttribute: (NSString *)anAttribute
{
	return [[types objectForKey: anAttribute] intValue];
}

- (id) valueForAttribute: (NSString *)anAttribute
{
	return [values objectForKey: anAttribute];
}


/** @taskunit equality testing */

- (BOOL) isEqual: (id)object
{
	if (object == self)
	{
		return YES;
	}
	if (![object isKindOfClass: [COItem class]])
	{
		return NO;
	}
	COItem *otherItem = (COItem*)object;
	
	if (![otherItem->uuid isEqual: uuid]) return NO;
	if (![otherItem->types isEqual: types]) return NO;
	if (![otherItem->values isEqual: values]) return NO;
	return YES;
}

- (NSUInteger) hash
{
	return [uuid hash] ^ [types hash] ^ [values hash] ^ 9014972660509684524LL;
}

/** @taskunit convenience */

- (NSString *)entityName
{
	return [self valueForAttribute: kCOObjectEntityNameProperty];
}

- (int64_t) entityVersion
{
	NSArray *versions = [values objectForKey: kCOObjectVersionsProperty];
	if ([versions count] > 0)
	{
		return [versions[0] longLongValue];
	}
	return -1;
}

- (NSString *) packageName
{
	NSArray *domains = [values objectForKey: kCOObjectDomainsProperty];
	if ([domains count] > 0)
	{
		return domains[0];
	}
	return nil;
}

- (NSDictionary *)versionsByDomain
{
	NSArray *versions = [values objectForKey: kCOObjectVersionsProperty];
	NSArray *domains = [values objectForKey: kCOObjectDomainsProperty];

	return [NSDictionary dictionaryWithObjects: versions forKeys: domains];
}

- (int64_t)versionForDomain: (NSString *)aDomain
{
	NILARG_EXCEPTION_TEST(aDomain);
	NSNumber *version = self.versionsByDomain[aDomain];
	
	if (version == nil)
		return -1;

	return [version longLongValue];
}

- (NSArray *) allObjectsForAttribute: (NSString *)attribute
{
	id value = [self valueForAttribute: attribute];
	
	if (COTypeIsUnivalued([self typeForAttribute: attribute]))
	{
		return ([value isEqual: [NSNull null]] ? [NSArray array] : [NSArray arrayWithObject: value]);
	}
	else
	{
		if ([value isKindOfClass: [NSSet class]])
		{
			return [(NSSet *)value allObjects];
		}
		else if ([value isKindOfClass: [NSArray class]])
		{
			return value;
		}
		else
		{
			return [NSArray array];
		}
	}
}

- (NSSet *) compositeReferencedItemUUIDs
{
	NSMutableSet *result = [NSMutableSet set];
	
	for (NSString *key in [self attributeNames])
	{
		COType type = [self typeForAttribute: key];
		if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
		{		
			for (ETUUID *embedded in [self allObjectsForAttribute: key])
			{
				[result addObject: embedded];
			}
		}
	}
	return [NSSet setWithSet: result];
}

- (NSSet *) referencedItemUUIDs
{
	NSMutableSet *result = [NSMutableSet set];
	
	for (NSString *key in [self attributeNames])
	{
		COType type = [self typeForAttribute: key];
		if (COTypePrimitivePart(type) == kCOTypeReference)
		{
			for (ETUUID *embedded in [self allObjectsForAttribute: key])
			{
				// FIXME: May return COPath!
				[result addObject: embedded];
			}
		}
	}
	return [NSSet setWithSet: result];
}

- (NSSet *) allInnerReferencedItemUUIDs
{
	NSMutableSet *result = [NSMutableSet set];
	
	for (NSString *key in [self attributeNames])
	{
		COType type = [self typeForAttribute: key];
		if (COTypePrimitivePart(type) == kCOTypeCompositeReference
			|| COTypePrimitivePart(type) == kCOTypeReference)
		{
			for (id aChild in [self allObjectsForAttribute: key])
			{
				// Ignore cross-persistent root references
				if ([aChild isKindOfClass: [COPath class]])
					continue;
				
				// Ignore NSNull (that means the relationship is set to nil)
				if ([aChild isKindOfClass: [NSNull class]])
					continue;
				
				[result addObject: aChild];
			}
		}
	}
	return [NSSet setWithSet: result];
}

// Helper methods for doing GC

- (NSArray *) attachments
{
	NSMutableArray *result = [NSMutableArray array];
	
	for (NSString *key in [self attributeNames])
	{
		COType type = [self typeForAttribute: key];
		if (COTypePrimitivePart(type) == kCOTypeAttachment)
		{
			for (COAttachmentID *embedded in [self allObjectsForAttribute: key])
			{
				[result addObject: embedded];
			}
		}
	}
	return result;
}

- (NSArray *) allReferencedPersistentRootUUIDs
{
	NSMutableArray *result = [NSMutableArray array];
	
	for (NSString *key in [self attributeNames])
	{
		COType type = [self typeForAttribute: key];
		if (COTypePrimitivePart(type) == kCOTypeReference)
		{
			for (id ref in [self allObjectsForAttribute: key])
			{
                if ([ref isKindOfClass: [COPath class]])
                {
                    [result addObject: [ref persistentRoot]];
                }
			}
		}
	}
	return result;
}

- (NSString *) fullTextSearchContent
{
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *key in [self attributeNames])
	{
		COType type = [self typeForAttribute: key];
		if (COTypePrimitivePart(type) == kCOTypeString)
		{
			[result addObject: [self valueForAttribute: key]];
		}
	}
    return [result componentsJoinedByString: @" "];
}

- (NSString *)description
{
	NSMutableString *result = [NSMutableString string];
		
	[result appendFormat: @"{ COItem %@\n", uuid];
	
	for (NSString *attrib in [self attributeNames])
	{
		[result appendFormat: @"\t%@ <%@> = '%@'\n",
			attrib,
			COTypeDescription([self typeForAttribute: attrib]),
			[self valueForAttribute:attrib]];
	}
	
	[result appendFormat: @"}"];
	
	return result;
}

/** @taskunit copy */

- (id) copyWithZone: (NSZone *)zone
{
	return self;
}

- (id) mutableCopyWithZone: (NSZone *)zone
{
	return [[COMutableItem alloc] initWithUUID: uuid			
								 typesForAttributes: types
								valuesForAttributes: values];
}

- (id)mutableCopyWithNameMapping: (NSDictionary *)aMapping
{
	COMutableItem *aCopy = [self mutableCopy];
	
	ETUUID *newUUIDForSelf = [aMapping objectForKey: [self UUID]];
	if (newUUIDForSelf != nil)
	{
		[aCopy setUUID: newUUIDForSelf];
	}
	
	for (NSString *attr in [aCopy attributeNames])
	{
		id value = [aCopy valueForAttribute: attr];
		COType type = [aCopy typeForAttribute: attr];
		
		if (COTypeIsUnivalued(type))
		{
            /* For COPath and primitive values, the mapping is not used */
			if ([value isKindOfClass: [ETUUID class]] && [aMapping objectForKey: value] != nil)
            {
                [aCopy setValue: [aMapping objectForKey: value]
                   forAttribute: attr
				           type: type];
			}
		}
		else
		{
			id newCollection = [value mutableCopy];
			[newCollection removeAllObjects];
    
            for (id subValue in value)
			{
				if ([subValue isKindOfClass: [ETUUID class]] && [aMapping objectForKey: subValue] != nil)
				{
                    [newCollection addObject: [aMapping objectForKey: subValue]];
				}
				else
				{
                    /* For COPath and primitive values */
					[newCollection addObject: subValue];
				}
			}
			
			[aCopy setValue: newCollection
			   forAttribute: attr
					   type: type];
		}
	}
	
	return aCopy;
}

@end




@implementation COMutableItem

+ (COMutableItem *) itemWithTypesForAttributes: (NSDictionary *)typesForAttributes
						   valuesForAttributes: (NSDictionary *)valuesForAttributes
{
    return (COMutableItem *)[super itemWithTypesForAttributes: typesForAttributes
                                          valuesForAttributes: valuesForAttributes];
}

- (id) initWithUUID: (ETUUID *)aUUID
 typesForAttributes: (NSDictionary *)typesForAttributes
valuesForAttributes: (NSDictionary *)valuesForAttributes
{
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(typesForAttributes);
	NILARG_EXCEPTION_TEST(valuesForAttributes);
	
	SUPERINIT;
	uuid =  aUUID;
	types = [[NSMutableDictionary alloc] initWithDictionary: typesForAttributes];
	values = (NSMutableDictionary *)copyValueDictionary(valuesForAttributes, YES);
	
    for (NSString *key in values)
    {
        ETAssert(COTypeValidateObject([[types objectForKey: key] intValue], [values objectForKey: key]));
    }
    
	return self;
}

- (id) initWithUUID: (ETUUID*)aUUID
{
	return [self initWithUUID: aUUID
		   typesForAttributes: [NSDictionary dictionary]
		  valuesForAttributes: [NSDictionary dictionary]];
}

- (id) init
{
	return [self initWithUUID: [ETUUID UUID]];
}

+ (COMutableItem *) item
{
	return [[self alloc] init];
}

+ (COMutableItem *) itemWithUUID: (ETUUID *)aUUID
{
	return [(COMutableItem *)[self alloc] initWithUUID: aUUID];
}

- (void) setUUID: (ETUUID *)aUUID
{
	NILARG_EXCEPTION_TEST(aUUID);
	uuid =  aUUID;
}

- (void) setValue: (id)aValue
	 forAttribute: (NSString *)anAttribute
			 type: (COType)aType
{
	NILARG_EXCEPTION_TEST(aValue);
	NILARG_EXCEPTION_TEST(anAttribute);
	
    ETAssert(COTypeValidateObject(aType, aValue));
    
	[(NSMutableDictionary *)types setObject: [NSNumber numberWithInt: aType] forKey: anAttribute];
	[(NSMutableDictionary *)values setObject: aValue forKey: anAttribute];
}

- (void)removeValueForAttribute: (NSString*)anAttribute
{
	[(NSMutableDictionary *)types removeObjectForKey: anAttribute];
	[(NSMutableDictionary *)values removeObjectForKey: anAttribute];
}

/** @taskunit convenience */

- (void)setEntityName: (NSString *)entityName
{
	[self setValue: entityName
	  forAttribute: kCOObjectEntityNameProperty
	          type: kCOTypeString];
}

- (void)setEntityVersion:(int64_t)entityVersion
{
	NSMutableArray *versions = [[values objectForKey: kCOObjectVersionsProperty] mutableCopy];
	if ([versions count] > 0)
	{
		versions[0] = @(entityVersion);
		[self setValue: versions
		  forAttribute: kCOObjectVersionsProperty
				  type: kCOTypeInt64 | kCOTypeArray];
	}
	else
	{
		[self setValue: @[@(entityVersion)]
		  forAttribute: kCOObjectVersionsProperty
				  type: kCOTypeInt64 | kCOTypeArray];
	}
}

- (void)setPackageName:(NSString *)packageName
{
	NSMutableArray *domains = [[values objectForKey: kCOObjectDomainsProperty] mutableCopy];
	if ([domains count] > 0)
	{
		domains[0] = [packageName copy];
		[self setValue: domains
		  forAttribute: kCOObjectDomainsProperty
				  type: kCOTypeString | kCOTypeArray];
	}
	else
	{
		[self setValue: @[[packageName copy]]
		  forAttribute: kCOObjectDomainsProperty
				  type: kCOTypeString | kCOTypeArray];
	}
}

- (void) setVersion: (int64_t)aVersion
          forDomain: (NSString *)aDomain
{
	NSMutableArray *versions = [[values objectForKey: kCOObjectVersionsProperty] mutableCopy];
	NSArray *domains = [values objectForKey: kCOObjectDomainsProperty];
	
	[versions replaceObjectAtIndex: [domains indexOfObject: aDomain]
	                    withObject: @(aVersion)];
	
	[self setValue: versions forAttribute: kCOObjectVersionsProperty];
}

- (void) setValue: (id)aValue
	 forAttribute: (NSString*)anAttribute
{
	[self setValue: aValue 
	  forAttribute: anAttribute
			  type: [self typeForAttribute: anAttribute]];
}

- (id) copyWithZone: (NSZone *)zone
{
	return [[COItem alloc] initWithUUID: uuid
                     typesForAttributes: types
                    valuesForAttributes: values];
}

@end

