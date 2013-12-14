/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"
#import "COItem+Binary.h"

/**
 * COMutableItem subclass which returns -attributeNames in ascending order
 */
@interface MutableItemAscendingAttributes : COMutableItem
@end

/**
 * COMutableItem subclass which returns -attributeNames in descending order
 */
@interface MutableItemDescendingAttributes : COMutableItem
@end

/**
 * NSSet subclass which enumerates in a provided order
 */
@interface OrderedSet : NSSet
{
	NSArray *objects;
}
- (instancetype) initWithArray:(NSArray *)array;
@end

@implementation MutableItemAscendingAttributes
- (NSArray *)attributeNames
{
	NSArray *attrs = [[super attributeNames] sortedArrayUsingSelector: @selector(compare:)];
	return attrs;
}
@end

@implementation MutableItemDescendingAttributes
- (NSArray *)attributeNames
{
	NSArray *attrs = [[super attributeNames] sortedArrayUsingSelector: @selector(compare:)];
	NSArray *reversed = [[attrs reverseObjectEnumerator] allObjects];
	return reversed;
}
@end

@implementation OrderedSet
- (instancetype) initWithArray: (NSArray *)array
{
	SUPERINIT;
	objects = [array copy];
	return self;
}
- (NSUInteger) count
{
	return [objects count];
}
- (id) member:(id)object
{
	NSUInteger index = [objects indexOfObject: object];
	if (index != NSNotFound)
	{
		return objects[index];
	}
	return nil;
}
- (NSEnumerator *) objectEnumerator
{
	return [objects objectEnumerator];
}
@end


/**
 * Test that the unordered parts of COItem are always serialized in the same way
 */
@interface TestItemStableSerialization : NSObject <UKTest>
{
	COItem *asc;
	COItem *dsc;
}
@end

@implementation TestItemStableSerialization

static ETUUID *ItemUUID;

+ (void) initialize
{
	if (self == [TestItemStableSerialization class])
	{
		ItemUUID = [[ETUUID alloc] init];
	}
}

static NSData *Data(unsigned char byte)
{
	return [NSData dataWithBytes: &byte length: 1];
}

static NSData *Data2(unsigned char byte1, unsigned char byte2)
{
	unsigned char bytes[2] = {byte1, byte2};
	return [NSData dataWithBytes: &bytes length: 2];
}

static COAttachmentID *Attach(unsigned char byte)
{
	return [[COAttachmentID alloc] initWithData: Data(byte)];
}

static ETUUID *UUID(unsigned char num)
{
	unsigned char uuid[16];
	memset(uuid, 0, 16);
	uuid[0] = num;
	
	return [ETUUID UUIDWithData: [NSData dataWithBytes: uuid length: 16]];
}

static COPath *Path(unsigned char num)
{
	if ((num % 2) == 0) /* Even: just a persistent root */
	{
		return [COPath pathWithPersistentRoot: UUID(num / 2)];
	}
	else /* Odd: persistent root and branch */
	{
		return [COPath pathWithPersistentRoot: UUID(num / 2) branch: UUID(1)];
	}
}


- (void) setSetWithOrder: (NSArray *)order reverse: (BOOL)reverse forAttribute: (NSString *)attrib primitiveType: (COType)type inItem: (COMutableItem *)item
{
	if (reverse)
	{
		order = [[order reverseObjectEnumerator] allObjects];
	}
	
	[item setValue: [[OrderedSet alloc] initWithArray: order]
	  forAttribute: attrib
			  type: COTypeMakeSetOf(type)];
}


- (COItem *) makeItemAscending: (BOOL)ascend
{
	COMutableItem *item;
	if (ascend)
	{
		item = [[MutableItemAscendingAttributes alloc] initWithUUID: ItemUUID];
	}
	else
	{
		item = [[MutableItemDescendingAttributes alloc] initWithUUID: ItemUUID];
	}
	
	const BOOL reverse = !ascend;
	
	// Add a bunch of NSSets with a fixed, known order
	
	[self setSetWithOrder: @[@1, @2, @3] reverse: reverse forAttribute: @"int64" primitiveType: kCOTypeInt64 inItem: item];
	[self setSetWithOrder: @[@1.1, @1.2, @1.3] reverse: reverse forAttribute: @"double" primitiveType: kCOTypeDouble inItem: item];
	[self setSetWithOrder: @[@"a", @"b", @"c", @"aa"] reverse: reverse forAttribute: @"string" primitiveType: kCOTypeString inItem: item];
	[self setSetWithOrder: @[Data(0), Data(1), Data(2), Data2(0, 0)] reverse: reverse forAttribute: @"data" primitiveType: kCOTypeBlob inItem: item];
	[self setSetWithOrder: @[UUID(0), UUID(1), UUID(2)] reverse: reverse forAttribute: @"composite" primitiveType: kCOTypeCompositeReference inItem: item];
	[self setSetWithOrder: @[UUID(0), UUID(1), UUID(2), Path(0), Path(1), Path(2)] reverse: reverse forAttribute: @"ref" primitiveType: kCOTypeReference inItem: item];
	[self setSetWithOrder: @[Attach(0), Attach(1), Attach(2)] reverse: reverse forAttribute: @"attachment" primitiveType: kCOTypeAttachment inItem: item];
	
	return item;
}

- (id) init
{
	SUPERINIT;
	asc = [self makeItemAscending: YES];
	dsc = [self makeItemAscending: NO];
	return self;
}

- (void) testItemsPreparedCorrectly
{
	UKObjectsEqual(SA([asc attributeNames]), SA([dsc attributeNames]));
	UKObjectsNotEqual([asc attributeNames], [dsc attributeNames]);

	for (NSString *key in [asc attributeNames])
	{
		id ascValue = [asc valueForAttribute: key];
		id dscValue = [dsc valueForAttribute: key];
		
		UKObjectKindOf(ascValue, NSSet);
		UKObjectKindOf(dscValue, NSSet);
		UKObjectsEqual(ascValue, dscValue);
		UKObjectsNotEqual([ascValue allObjects], [dscValue allObjects]);
	}
}

- (void) testItemsHaveIdenticalBinarySerialization
{
	NSData *ascData = [asc dataValue];
	NSData *dscData = [dsc dataValue];
	UKObjectsEqual(ascData, dscData);
}

@end
