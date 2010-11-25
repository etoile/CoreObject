#import <Foundation/NSSet.h>
#import "COObjectGraphDiff.h"
#import "COArrayDiff.h"
#import "COSetDiff.h"

// FIXME: do something like this
#if 0
static NSArray *ArrayCopyWithCOObjectsReplacedWithUUIDs(NSArray *array)
{
	NSUInteger c = [array count];
	NSMutableArray *result = [NSMutableArray arrayWithCapacity: c];
	for (NSUInteger i=0; i<c; i++)
	{
		id val = [array objectAtIndex: i];
		if ([val isKindOfClass: [COObject class]])
		{
			[result addObject: [val UUID]];
		}
		else
		{
			[result addObject: val];
		}
	}
}
#endif


/**
 * COObjectGraphEdit classes. These are simple wrapper objects.
 */

@interface COObjectGraphEdit : NSObject
{
	ETUUID *UUID;
	NSString *propertyName;
}
@property (nonatomic, retain) ETUUID *UUID;
@property (nonatomic, retain) NSString *propertyName;
- (void) applyToObject: (COObject*)obj;
@end

@implementation COObjectGraphEdit
@synthesize UUID;
@synthesize propertyName;
- (void) dealloc
{
	[UUID release];
	[propertyName release];
	[super dealloc];
}
- (void) applyToObject: (COObject*)obj
{
	[self doesNotRecognizeSelector: _cmd];
}
@end





@interface COObjectGraphRemoveProperty : COObjectGraphEdit
{
}
+ (COObjectGraphRemoveProperty*)removeProperty: (NSString*)p forUUID: (ETUUID*)u;
@end

@implementation COObjectGraphRemoveProperty
+ (COObjectGraphRemoveProperty*)removeProperty: (NSString*)p forUUID: (ETUUID*)u
{
	COObjectGraphRemoveProperty *r = [[COObjectGraphRemoveProperty alloc] init];
	[r setPropertyName: p];
	[r setUUID: u];
	return [r autorelease];
}
- (void) applyToObject: (COObject*)obj
{
	[obj setValue: nil forProperty: propertyName];
}
- (NSString *)description
{
	return [NSString stringWithFormat: @"%@:%@ remove", UUID, propertyName];
}

@end



@interface COObjectGraphSetProperty : COObjectGraphEdit
{
	id newValue;
}
@property (nonatomic, retain) id newValue;
+ (COObjectGraphSetProperty*)setProperty: (NSString*)p to: (id)v forUUID: (ETUUID*)u;
@end

@implementation COObjectGraphSetProperty
@synthesize newValue;
- (void)dealloc
{
	[newValue release];
	[super dealloc];
}
+ (COObjectGraphSetProperty*)setProperty: (NSString*)p to: (id)v forUUID: (ETUUID*)u
{
	COObjectGraphSetProperty *s = [[COObjectGraphSetProperty alloc] init];
	[s setPropertyName: p];
	[s setNewValue: v];
	[s setUUID: u];
	return [s autorelease];
}
- (void) applyToObject: (COObject*)obj
{
	[obj setValue: newValue forProperty: propertyName];
}
- (NSString *)description
{
	return [NSString stringWithFormat: @"%@:%@ set to '%@'", UUID, propertyName, newValue];
}

@end



@interface COObjectGraphModifyArray : COObjectGraphEdit
{
	COArrayDiff *diff;
}
@property (nonatomic, retain) COArrayDiff *diff;
+ (COObjectGraphModifyArray*)modifyArray: (NSString*)p diff: (COArrayDiff*)d forUUID: (ETUUID*)u;
@end

@implementation COObjectGraphModifyArray
@synthesize diff;
- (void)dealloc
{
	[diff release];
	[super dealloc];
}
+ (COObjectGraphModifyArray*)modifyArray: (NSString*)p diff: (COArrayDiff*)d forUUID: (ETUUID*)u
{
	COObjectGraphModifyArray *m = [[COObjectGraphModifyArray alloc] init];
	[m setPropertyName: p];
	[m setDiff: d];
	[m setUUID: u];
	return [m autorelease];
}
- (void) applyToObject: (COObject*)obj
{
	// FIXME: slow
	NSArray *oldArray = [obj valueForProperty: propertyName];
	NSArray *temp = [diff arrayWithDiffAppliedTo: oldArray];
	NSArray *newArray = temp; 
	
	[obj setValue: newArray
	  forProperty: propertyName];
}
- (NSString *)description
{
	return [NSString stringWithFormat: @"%@:%@ modify array '%@'", UUID, propertyName, diff];
}
@end





@interface COObjectGraphModifySet : COObjectGraphEdit
{
	COSetDiff *diff;
}
@property (nonatomic, retain) COSetDiff *diff;
+ (COObjectGraphModifySet*)modifySet: (NSString*)p diff: (COSetDiff*)d forUUID: (ETUUID*)u;
@end

@implementation COObjectGraphModifySet
@synthesize diff;
- (void)dealloc
{
	[diff release];
	[super dealloc];
}
+ (COObjectGraphModifySet*)modifySet: (NSString*)p diff: (COSetDiff*)d forUUID: (ETUUID*)u
{
	COObjectGraphModifySet *m = [[COObjectGraphModifySet alloc] init];
	[m setPropertyName: p];
	[m setDiff: d];
	[m setUUID: u];
	return [m autorelease];
}
- (void) applyToObject: (COObject*)obj
{
	NSSet *temp = [diff setWithDiffAppliedTo: [obj valueForProperty: propertyName]];
	NSSet *result = temp;
	
	// FIXME: slow
	[obj setValue: result
	  forProperty: propertyName];
}
- (NSString *)description
{
	return [NSString stringWithFormat: @"%@:%@ modify set '%@'", UUID, propertyName, diff];
}
@end



/**
 * Object graph diff class. This is a collection of COObjectGraphEdit
 * objects.
 */
@implementation COObjectGraphDiff

- (id) init
{
	SUPERINIT;
	
	_editsByPropertyAndUUID = [[NSMutableDictionary alloc] init];
	_deletedObjectUUIDs = [[NSMutableArray alloc] init];
	_insertedObjectDataByUUID = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc
{
	[_editsByPropertyAndUUID release];
	[_deletedObjectUUIDs release];
	[_insertedObjectDataByUUID release];
	[super dealloc];
}

- (void)record: (COObjectGraphEdit*)edit
{
	NSMutableDictionary *propDict = [_editsByPropertyAndUUID objectForKey: [edit UUID]];
	if (nil == propDict)
	{
		assert([edit UUID] != nil);
		propDict = [NSMutableDictionary dictionary];
		[_editsByPropertyAndUUID setObject: propDict forKey: [edit UUID]];
	} 
	
	[propDict setObject: edit forKey: [edit propertyName]];
}

- (void)recordRemoveProperty: (NSString*)name ofObjectUUID: (ETUUID*)obj
{
	[self record: [COObjectGraphRemoveProperty removeProperty: name forUUID: obj]];
}
- (void)recordSetValue: (id)value forProperty: (NSString*)name ofObjectUUID: (ETUUID*)obj
{
	[self record: [COObjectGraphSetProperty setProperty:name to:value forUUID:obj]];
}
- (void)recordModifyArray: (COArrayDiff *)diff forProperty: (NSString*)name ofObjectUUID: (ETUUID*)obj
{
	[self record: [COObjectGraphModifyArray modifyArray:name diff:diff forUUID:obj]];
}
- (void)recordModifySet: (COSetDiff *)diff forProperty: (NSString*)name ofObjectUUID: (ETUUID*)obj
{
	[self record: [COObjectGraphModifySet modifySet:name diff:diff forUUID:obj]];
}
- (void)recordDeleteObjectWithUUID: (ETUUID*)uuid
{
	[_deletedObjectUUIDs addObject: uuid];
}
- (void)recordInsertObjectWithUUID: (ETUUID*)uuid
							  data: (NSDictionary*)data
{
	[_insertedObjectDataByUUID setObject: data forKey: uuid];
}

- (void)applyToContext: (COEditingContext*)ctx
{
	// FIXME: write
	/*
	for (ETUUID *uuid in [_insertedObjectsByUUID allKeys])
	{
		[ctx insertObjectWithEntityName:<#(NSString *)aFullName#>
	}	
	for (ETUUID *uuid in _deletedObjectUUIDs)
	{
		[ctx deleteObjectWithID: uuid];
	}*/
	for (ETUUID *uuid in _editsByPropertyAndUUID)
	{
		NSDictionary *propDict = [_editsByPropertyAndUUID objectForKey: uuid];
		COObject *obj = [ctx objectWithUUID: uuid];
		
		for (COObjectGraphEdit *edit in [propDict allValues])
		{
			[edit applyToObject: obj];
		}
	}
}

- (NSString *)description
{
	NSMutableString *desc = [NSMutableString stringWithFormat: @"<COObjectGraphDiff: %p> {\n", self];
	
	for (NSDictionary *propDict in [_editsByPropertyAndUUID allValues])
	{
		for (COObjectGraphEdit *edit in [propDict allValues])
		{
			[desc appendFormat: @"\t%@\n", edit];
		}
	}
	[desc appendFormat: @"}\n"];
	return desc;
}

@end


@implementation COObjectGraphDiff (Factory)

/**
 * Note this is nonrecursive; it doesn't compare COObjects referenced by the given ones
 */
+ (void) _diffObject: (COObject*)base with: (COObject*)other addToDiff: (COObjectGraphDiff*)diff
{

	NSLog(@"Diff %@ with %@", base, other);
	
	if (base == nil && other == nil)
	{
		return;
	}
	else if (base == nil)
	{
		[diff recordInsertObjectWithUUID: [other UUID] data: [other propertyList]];
		return;
	}
	else if (other == nil)
	{
		[diff recordDeleteObjectWithUUID: [base UUID]];
		return;
	}
	
	NSMutableSet *props = [NSMutableSet setWithArray: [base properties]];
	[props unionSet: [NSSet setWithArray: [other properties]]];
    
	for (NSString *prop in props)
	{
		id baseVal = [base valueForProperty: prop];
		id otherVal = [other valueForProperty: prop];
		if (![baseVal isEqual: otherVal]
			&& !(baseVal == nil && otherVal == nil))
		{
			if ([baseVal isKindOfClass: [NSArray class]] && [otherVal isKindOfClass: [NSArray class]])
			{
				COArrayDiff *arrayDiff = [[[COArrayDiff alloc] initWithFirstArray: (NSArray*)baseVal
																	  secondArray: (NSArray*)otherVal] autorelease];
				[diff recordModifyArray: arrayDiff forProperty: prop ofObjectUUID: [base UUID]];
			}
			else if ([baseVal isKindOfClass: [NSSet class]] && [otherVal isKindOfClass: [NSSet class]])
			{
				COSetDiff *setDiff = [[[COSetDiff alloc] initWithFirstSet: (NSSet*)baseVal
																secondSet: (NSSet*)otherVal] autorelease];
				[diff recordModifySet: setDiff forProperty: prop ofObjectUUID: [base UUID]];
			}
			else if (baseVal != nil && otherVal == nil)
			{
				[diff recordRemoveProperty: prop ofObjectUUID: [base UUID]];
			}
			else
			{
				[diff recordSetValue: otherVal forProperty: prop ofObjectUUID: [base UUID]];
			}
		}
	}  
}

+ (COObjectGraphDiff *)diffObjectsWithUUIDs: (NSArray*)objectUUIDs
								  inContext: (COEditingContext*)base 
								withContext: (COEditingContext*)other
{
	COObjectGraphDiff *result = [[[COObjectGraphDiff alloc] init] autorelease];
	for (ETUUID *uuid in objectUUIDs)
	{
		COObject *o1 = [base objectWithUUID: uuid];
		COObject *o2 = [other objectWithUUID: uuid];
		
		if (o1 == nil && o2 == nil)
		{
			NSLog(@"Warning: neither context %@ nor %@ contains %@", base, other, uuid);
		}
		
		[self _diffObject: o1 with: o2 addToDiff: result];
	}
	return result;
}

+ (COObjectGraphDiff *)diffHistoryNode: (COHistoryNode*)n1 withHistoryNode: (COHistoryNode*)n2
{
	if ([n1 isEqual: n2])
	{
		return [[[COObjectGraphDiff alloc] init] autorelease];
	}
	
	COEditingContext *c1 = [[COEditingContext alloc] initWithHistoryGraphNode: n1];
	COEditingContext *c2 = [[COEditingContext alloc] initWithHistoryGraphNode: n2];
	
	NSArray *uuids = [[n1 storeCoordinator] objectUUIDsChangedBetweenNode:n1 andNode:n2];
	
	COObjectGraphDiff *result = [COObjectGraphDiff diffObjectsWithUUIDs: uuids
															  inContext:c1
															withContext:c2];
	[c1 release];
	[c2 release];
	return result;
}	
@end


@implementation COObjectGraphDiff (Merge)

+ (COObjectGraphDiff*) mergeDiff: (COObjectGraphDiff*)diff1 withDiff: (COObjectGraphDiff*)diff2
{
	COObjectGraphDiff *result = [[[COObjectGraphDiff alloc] init] autorelease];
	
	NSSet *allUUIDs = [[NSSet setWithArray: [diff1->_editsByPropertyAndUUID allKeys]]
					   setByAddingObjectsFromArray: [diff2->_editsByPropertyAndUUID allKeys]];
	
	// FIXME: Do move detection; detect conflicting moves.
	// Should be pretty easy, just construct sets containing all objects that
	// are both removed somewhere and added somewhere in a diff, and treat the
	// intersection of those sets as moves.
	// Do that for both diffs, and then check if there are any moves which
	// have the same source in both diffs but different destinations.
	
	for (ETUUID *uuid in allUUIDs)
	{
		NSDictionary *propDict1 = [diff1->_editsByPropertyAndUUID objectForKey: uuid];
		NSDictionary *propDict2 = [diff2->_editsByPropertyAndUUID objectForKey: uuid];
		NSSet *allProperties = [[NSSet setWithArray: [propDict1 allKeys]]
								setByAddingObjectsFromArray: [propDict2 allKeys]];
		
		for (NSString *prop in allProperties)
		{
			COObjectGraphEdit *edit1 = [propDict1 objectForKey: prop]; // possibly nil
			COObjectGraphEdit *edit2 = [propDict2 objectForKey: prop]; // possibly nil
			
			// FIXME: modularize this
			
			if (edit1 != nil && edit2 != nil) 
			{
				if ([edit1 isKindOfClass: [COObjectGraphRemoveProperty class]] && [edit2 isKindOfClass: [COObjectGraphRemoveProperty class]])
				{
					NSLog(@"Both are remove %@ (no conflict)", prop);
					[result record: edit1];
				}
				else if ([edit1 isKindOfClass: [COObjectGraphSetProperty class]] && [edit2 isKindOfClass: [COObjectGraphSetProperty class]]
						 && [[(COObjectGraphSetProperty*)edit1 newValue] isEqual: [(COObjectGraphSetProperty*)edit2 newValue]])
				{
					NSLog(@"Both are set %@ to %@ (no conflict)", prop, [(COObjectGraphSetProperty*)edit1 newValue]);
					[result record: edit1];
				}
				else if ([edit1 isKindOfClass: [COObjectGraphModifyArray class]] && [edit2 isKindOfClass: [COObjectGraphModifyArray class]])
				{
					NSLog(@"Both are modifying array %@.. trying array merge", prop);
					COMergeResult *merge = [[(COObjectGraphModifyArray*)edit1 diff] mergeWith: [(COObjectGraphModifyArray*)edit2 diff]];
					
					[result recordModifyArray: [[[COArrayDiff alloc] initWithOperations: [merge nonconflictingOps]] autorelease] forProperty: prop ofObjectUUID: uuid];
				}
				else if ([edit1 isKindOfClass: [COObjectGraphModifySet class]] && [edit2 isKindOfClass: [COObjectGraphModifySet class]])
				{
					NSLog(@"Both are modifying set %@.. trying set merge", prop);
					COMergeResult *merge = [[(COObjectGraphModifySet*)edit1 diff] mergeWith: [(COObjectGraphModifySet*)edit2 diff]];
					
					[result recordModifySet: [[[COSetDiff alloc] initWithOperations: [merge nonconflictingOps]] autorelease] forProperty: prop ofObjectUUID: uuid];
				}
				else
				{
					// FIXME: handle modifying arrays
					NSLog(@"Conflict: {\n\t%@\n\t%@\n}", edit1, edit2);
					NSLog(@"WARNING: accepting left-hand-side..");
					[result record: edit1]; // FIXME: decide on output format...
				}
			}
			else if (edit1 != nil)
			{
				NSLog(@"Accept/reject: {\n\t%@\n\t%@\n}", edit1, edit2);      
				[result record: edit1];
			}
			else if (edit2 != nil)
			{
				NSLog(@"Reject/accept: {\n\t%@\n\t%@\n}", edit1, edit2);      
				[result record: edit2];
			}
			else assert(0);
		}
	}
	
	return result;
}

@end