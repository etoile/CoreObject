#import "COObjectGraphDiff.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "CORevision.h"
#import "COContainer.h"
#import "COArrayDiff.h"
#import "COSetDiff.h"


static NSArray *ArrayWithCOObjectsReplacedWithUUIDs(NSArray *array)
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
	return result;
}

static NSSet *SetWithCOObjectsReplacedWithUUIDs(NSSet *set)
{
	NSUInteger c = [set count];
	NSMutableSet *result = [NSMutableSet setWithCapacity: c];
	for (id val in set)
	{
		if ([val isKindOfClass: [COObject class]])
		{
			[result addObject: [val UUID]];
		}
		else
		{
			[result addObject: val];
		}
	}
	return result;
}


@interface COObjectGraphPath : NSObject
{
	ETUUID *objectUUID;
	NSString *property;
	NSNumber *index;
}
@property (readwrite, retain, nonatomic) ETUUID *objectUUID;
@property (readwrite, retain, nonatomic) NSString *property;
@property (readwrite, retain, nonatomic) NSNumber *index;
@end

@implementation COObjectGraphPath

@synthesize objectUUID; 
@synthesize property;
@synthesize index;

- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass: [COObjectGraphPath class]])
	{
		COObjectGraphPath *rhs = object;
		return [objectUUID isEqual: [rhs objectUUID]]
			&& [property isEqual: [rhs property]]
			&& ([index isEqual: [rhs index]] || (index == nil && [rhs index] == nil));
	}
	return NO;
}

- (void)dealloc
{
	[objectUUID release];
	[property release];
	[index release];
	[super dealloc];
}

@end


@interface COMoveInfo : NSObject
{
	COObjectGraphPath *sourcePath, *destPath;
	ETUUID *movedObjectUUID;
}
@property (readwrite, retain, nonatomic) COObjectGraphPath *sourcePath;
@property (readwrite, retain, nonatomic) COObjectGraphPath *destPath;
@property (readwrite, retain, nonatomic) ETUUID *movedObjectUUID;
@end

@implementation COMoveInfo

@synthesize sourcePath; 
@synthesize destPath;
@synthesize movedObjectUUID;

- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass: [COMoveInfo class]])
	{
		return [sourcePath isEqual: [object sourcePath]]
		&& [destPath isEqual: [object destPath]]
		&& [movedObjectUUID isEqual: [object movedObjectUUID]];
	}
	return NO;
}

- (void)dealloc
{
	[sourcePath release];
	[destPath release];
	[movedObjectUUID release];
	[super dealloc];
}

@end



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
	id newlySetValue;
}
@property (nonatomic, retain) id newlySetValue;
+ (COObjectGraphSetProperty*)setProperty: (NSString*)p to: (id)v forUUID: (ETUUID*)u;
@end

@implementation COObjectGraphSetProperty
@synthesize newlySetValue;
- (void)dealloc
{
	[newlySetValue release];
	[super dealloc];
}
+ (COObjectGraphSetProperty*)setProperty: (NSString*)p to: (id)v forUUID: (ETUUID*)u
{
	COObjectGraphSetProperty *s = [[COObjectGraphSetProperty alloc] init];
	[s setPropertyName: p];
	[s setNewlySetValue: v];
	[s setUUID: u];
	return [s autorelease];
}
- (void) applyToObject: (COObject*)obj
{
	if ([newlySetValue isKindOfClass: [ETUUID class]])
	{
		newlySetValue = [[obj editingContext] objectWithUUID: newlySetValue];
		//assert(newlySetValue != nil); //FIXME: remove
	}
	[obj setValue: newlySetValue forProperty: propertyName];
}
- (NSString *)description
{
	return [NSString stringWithFormat: @"%@:%@ set to '%@'", UUID, propertyName, newlySetValue];
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
	NSMutableArray *newArray = [NSMutableArray array]; 
	for (id value in temp)
	{
		if ([value isKindOfClass: [ETUUID class]])
		{
			id newValue = [[obj editingContext] objectWithUUID: value];
			assert(newValue != nil); //FIXME: remove
			[newArray addObject: newValue];
		}
		else
		{
			[newArray addObject: value];
		}
	}
	
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
	NSMutableSet *newSet = [NSMutableSet set]; 
	for (id value in temp)
	{
		if ([value isKindOfClass: [ETUUID class]])
		{
			id newValue = [[obj editingContext] objectWithUUID: value];
			assert(newValue != nil); //FIXME: remove
			[newSet addObject: newValue];
		}
		else
		{
			[newSet addObject: value];
		}
	}
	
	// FIXME: slow
	[obj setValue: newSet
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
	_deletedObjectUUIDs = [[NSMutableSet alloc] init];
	_insertedObjectsByUUID = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc
{
	[_editsByPropertyAndUUID release];
	[_deletedObjectUUIDs release];
	[_insertedObjectsByUUID release];
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
- (void)recordInsertObject: (COObject*)obj
{
	[_insertedObjectsByUUID setObject: obj forKey: [obj UUID]];
}

- (void)applyToContext: (COEditingContext*)ctx
{
	for (COObject *obj in [_insertedObjectsByUUID allValues])
	{
		[ctx insertObject: obj withRelationshipConsistency: NO newUUID: NO];
	}	
	for (ETUUID *uuid in _deletedObjectUUIDs)
	{
		[ctx deleteObject: [ctx objectWithUUID: uuid]];
	}
	for (ETUUID *uuid in _editsByPropertyAndUUID)
	{
		NSDictionary *propDict = [_editsByPropertyAndUUID objectForKey: uuid];
		COObject *obj = [ctx objectWithUUID: uuid];
		
		assert(![obj isIgnoringRelationshipConsistency]);
		[obj setIgnoringRelationshipConsistency: YES];
		for (COObjectGraphEdit *edit in [propDict allValues])
		{
			[edit applyToObject: obj];
		}
		[obj setIgnoringRelationshipConsistency: NO];
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

- (NSDictionary*)movedObjects
{
	/*
	 { uuid : COMoveInfo } 
	 */
	
/*	NSSet *
	for (ETUUID *uuid in _editsByPropertyAndUUID)
	{
		NSDictionary *propDict = [_editsByPropertyAndUUID objectForKey: uuid];
		for (COObjectGraphEdit *edit in [propDict allValues])
		{
			
		}
	}
	
	return nil*/
	return nil;
}

@end


@implementation COObjectGraphDiff (Factory)

/**
 * Note this is nonrecursive; it doesn't compare COObjects referenced by the given ones
 */
+ (void) _diffObject: (COObject*)base with: (COObject*)other addToDiff: (COObjectGraphDiff*)diff
{

	//NSLog(@"Diff %@ with %@", base, other);
	
	if (base == nil && other == nil)
	{
		return;
	}
	else if (base == nil)
	{
		[diff recordInsertObject: other];
		return;
	}
	else if (other == nil)
	{
		[diff recordDeleteObjectWithUUID: [base UUID]];
		return;
	}
	
	NSMutableSet *props = [NSMutableSet setWithArray: [base persistentPropertyNames]];
	[props unionSet: [NSSet setWithArray: [other persistentPropertyNames]]];
    
	for (NSString *prop in props)
	{
		id baseVal = [base valueForProperty: prop];
		id otherVal = [other valueForProperty: prop];
		if (![baseVal isEqual: otherVal]
			&& !(baseVal == nil && otherVal == nil))
		{
			if ([baseVal isKindOfClass: [NSArray class]] && [otherVal isKindOfClass: [NSArray class]])
			{
				COArrayDiff *arrayDiff = [[[COArrayDiff alloc] initWithFirstArray: ArrayWithCOObjectsReplacedWithUUIDs(baseVal)
																	  secondArray: ArrayWithCOObjectsReplacedWithUUIDs(otherVal)] autorelease];
				[diff recordModifyArray: arrayDiff forProperty: prop ofObjectUUID: [base UUID]];
			}
			else if ([baseVal isKindOfClass: [NSSet class]] && [otherVal isKindOfClass: [NSSet class]])
			{
				COSetDiff *setDiff = [[[COSetDiff alloc] initWithFirstSet: SetWithCOObjectsReplacedWithUUIDs(baseVal)
																secondSet: SetWithCOObjectsReplacedWithUUIDs(otherVal)] autorelease];
				[diff recordModifySet: setDiff forProperty: prop ofObjectUUID: [base UUID]];
			}
			else if (baseVal != nil && otherVal == nil)
			{
				[diff recordRemoveProperty: prop ofObjectUUID: [base UUID]];
			}
			else
			{
				if ([otherVal isKindOfClass: [COObject class]])
				{
					otherVal = [otherVal UUID];
				}
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
		assert([uuid isKindOfClass: [ETUUID class]]);
		
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

// + (COObjectGraphDiff *)diffHistoryNode: (id)n1 withHistoryNode: (id)n2
// {
// 	if ([n1 isEqual: n2])
// 	{
// 		return [[[COObjectGraphDiff alloc] init] autorelease];
// 	}
// 	
// 	COEditingContext *c1 = [[COEditingContext alloc] initWithHistoryGraphNode: n1];
// 	COEditingContext *c2 = [[COEditingContext alloc] initWithHistoryGraphNode: n2];
// 	
// 	NSArray *uuids = [[n1 storeCoordinator] objectUUIDsChangedBetweenNode:n1 andNode:n2];
// 	
// 	COObjectGraphDiff *result = [COObjectGraphDiff diffObjectsWithUUIDs: uuids
// 															  inContext:c1
// 															withContext:c2];
// 	[c1 release];
// 	[c2 release];
// 	return result;
// }	

+ (COObjectGraphDiff *)diffContainer: (COContainer*)group1 withContainer: (COContainer*)group2
{
	NSMutableSet *set = [NSMutableSet set];
	[set addObjectsFromArray: [group1 allStronglyContainedObjectsIncludingSelf]];
	[set addObjectsFromArray: [group2 allStronglyContainedObjectsIncludingSelf]];
	set = (NSMutableSet*)[[set mappedCollection] UUID];
	
	return [COObjectGraphDiff diffObjectsWithUUIDs: [set allObjects]
										 inContext: [group1 editingContext]
									   withContext: [group2 editingContext]];
}

+ (COObjectGraphDiff *)diffRootObject: (COObject *)baseObject 
                       withRootObject: (COObject *)otherObject
{
	NSMutableSet *set = [NSMutableSet set];
	[set unionSet: [baseObject allInnerObjectsIncludingSelf]];
	[set unionSet: [otherObject allInnerObjectsIncludingSelf]];
	set = (id)[[set mappedCollection] UUID];

	return [COObjectGraphDiff diffObjectsWithUUIDs: [set allObjects]
										 inContext: [baseObject editingContext]
									   withContext: [otherObject editingContext]];
}

+ (COObjectGraphDiff *)selectiveUndoDiffWithRootObject: (COObject *)aRootObject 
                                        revisionToUndo: (CORevision *)revToUndo
{
	// NOTE: Check the editing context is sane and we don't have an outdated 
	// root object instance.
	assert(aRootObject == [[aRootObject editingContext] objectWithUUID: [aRootObject UUID]]);

	CORevision *revBeforeUndo = [revToUndo baseRevision];

	/* Load both the revision to be undone and the revision just before in two sandbox-like contexts  */
	
	COEditingContext *revToUndoCtxt = [[COEditingContext alloc] initWithStore: [revToUndo store] 
	                                                        maxRevisionNumber: [revToUndo revisionNumber]];
	COEditingContext *revBeforeUndoCtxt = [[COEditingContext alloc] initWithStore: [revBeforeUndo store] 
	                                                            maxRevisionNumber: [revBeforeUndo revisionNumber]];

	/* Retrieve the object targeted by the undo in its two past states and in its current state  */

	COObject *revToUndoObj = [revToUndoCtxt objectWithUUID: [aRootObject UUID] atRevision: revToUndo];
	COObject *revBeforeUndoObj = [revBeforeUndoCtxt objectWithUUID: [aRootObject UUID] atRevision: revBeforeUndo];
	COObject *currentObj = aRootObject;

	/* Compute a selective undo that can be applied to the object state bound to revToUndo

	   We use revToUndoObj as the base for the diff, except in the last case 
	   where we use currentObject:
	   - oa is a patch that removes all the changes between revToUndo and 
	     revBeforeUndo
	   - ob is a patch that adds all the changes between revToUndo and now (the 
	     current revision)
	   - undoDiff is a patch that combines oa and ob, it represents the 
	     selective undo in a valid way, but can only be applied correctly to the 
		 object state bound to revToUndo
	   - finalDiff is a patch that removes all the changes between revToUndo and 
	     revBeforeUndo, but unlike oa, it has been adjusted to ensure all the 
		 changes involved by ob that overlap with oa have been resolved, so 
		 it can be applied without weird results to the current object state */

	COObjectGraphDiff *oa = [COObjectGraphDiff diffRootObject: revToUndoObj withRootObject: revBeforeUndoObj];
	COObjectGraphDiff *ob = [COObjectGraphDiff diffRootObject: revToUndoObj withRootObject: currentObj];	
	COObjectGraphDiff *undoDiff = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
	
	[undoDiff applyToContext: revToUndoCtxt];

	/* Return selective undo changes that can be replicated into the current root object context
	
	   Once done, revToUndoCtxt and editingContext will contain two object 
	   instances in the same state. */

	return [COObjectGraphDiff diffRootObject: currentObj withRootObject: revToUndoObj];
}

@end


@implementation COObjectGraphDiff (Merge)

+ (COObjectGraphDiff*) mergeDiff: (COObjectGraphDiff*)diff1 withDiff: (COObjectGraphDiff*)diff2
{
	COObjectGraphDiff *result = [[[COObjectGraphDiff alloc] init] autorelease];
	//NSLog(@"Merging %@ and %@...", diff1, diff2);
	
	NILARG_EXCEPTION_TEST(diff1);
	NILARG_EXCEPTION_TEST(diff2);
	
	// Merge inserts and deletes

	NSSet *diff1Inserts = [NSSet setWithArray: [diff1->_insertedObjectsByUUID allKeys]];
	NSSet *diff2Inserts = [NSSet setWithArray: [diff2->_insertedObjectsByUUID allKeys]];	
			
	NSMutableSet *insertConflicts = [NSMutableSet setWithSet: diff1Inserts];
	[insertConflicts intersectSet: diff2Inserts];
	for (ETUUID *aUUID in insertConflicts)
	{
		// Warn about conflicts
		if ([[diff1->_insertedObjectsByUUID objectForKey: aUUID] editingContext] != 
			[[diff2->_insertedObjectsByUUID objectForKey: aUUID] editingContext])
		{
			//NSLog(@"ERROR: Insert/Insert conflict with UUID %@. LHS wins.", aUUID);
		}
	}
	
	NSMutableDictionary *allInserts = [NSMutableDictionary dictionary];
	[allInserts addEntriesFromDictionary: diff2->_insertedObjectsByUUID];
	[allInserts addEntriesFromDictionary: diff1->_insertedObjectsByUUID]; // If there are duplicate keys diff1 wins
	[result->_insertedObjectsByUUID setDictionary: allInserts];
	
	NSSet *allDeletedUUIDs = [diff1->_deletedObjectUUIDs setByAddingObjectsFromSet: diff2->_deletedObjectUUIDs];
	[result->_deletedObjectUUIDs setSet: allDeletedUUIDs];
	
	
	// Merge edits
	
	NSSet *allUUIDs = [[NSSet setWithArray: [diff1->_editsByPropertyAndUUID allKeys]]
					   setByAddingObjectsFromArray: [diff2->_editsByPropertyAndUUID allKeys]];
	
	
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
					//NSLog(@"Both are remove %@ (no conflict)", prop);
					[result record: edit1];
				}
				else if ([edit1 isKindOfClass: [COObjectGraphSetProperty class]] && [edit2 isKindOfClass: [COObjectGraphSetProperty class]]
						 && [[(COObjectGraphSetProperty*)edit1 newlySetValue] isEqual: [(COObjectGraphSetProperty*)edit2 newlySetValue]])
				{
					//NSLog(@"Both are set %@ to %@ (no conflict)", prop, [(COObjectGraphSetProperty*)edit1 newValue]);
					[result record: edit1];
				}
				else if ([edit1 isKindOfClass: [COObjectGraphModifyArray class]] && [edit2 isKindOfClass: [COObjectGraphModifyArray class]])
				{
					//NSLog(@"Both are modifying array %@.. trying array merge", prop);
					COMergeResult *merge = [[(COObjectGraphModifyArray*)edit1 diff] mergeWith: [(COObjectGraphModifyArray*)edit2 diff]];
					
					[result recordModifyArray: [[[COArrayDiff alloc] initWithOperations: [merge nonconflictingOps]] autorelease] forProperty: prop ofObjectUUID: uuid];
				}
				else if ([edit1 isKindOfClass: [COObjectGraphModifySet class]] && [edit2 isKindOfClass: [COObjectGraphModifySet class]])
				{
					//NSLog(@"Both are modifying set %@.. trying set merge", prop);
					COMergeResult *merge = [[(COObjectGraphModifySet*)edit1 diff] mergeWith: [(COObjectGraphModifySet*)edit2 diff]];
					
					[result recordModifySet: [[[COSetDiff alloc] initWithOperations: [merge nonconflictingOps]] autorelease] forProperty: prop ofObjectUUID: uuid];
				}
				else
				{
					// FIXME: handle modifying arrays
					//NSLog(@"Conflict: {\n\t%@\n\t%@\n}", edit1, edit2);
					//NSLog(@"WARNING: accepting left-hand-side..");
					[result record: edit1]; // FIXME: decide on output format...
				}
			}
			else if (edit1 != nil)
			{
				//NSLog(@"Accept/reject: {\n\t%@\n\t%@\n}", edit1, edit2);      
				[result record: edit1];
			}
			else if (edit2 != nil)
			{
				//NSLog(@"Reject/accept: {\n\t%@\n\t%@\n}", edit1, edit2);      
				[result record: edit2];
			}
			else assert(0);
		}
	}
	
	return result;
}

@end
