#import <Foundation/NSSet.h>
#import "COObjectGraphDiff.h"
#import "COArrayDiff.h"
#import "COSetDiff.h"

/* These three functions are a hack */

static id EnsureObjectIsFromContext(id object, COEditingContext *ctx)
{
  if ([object isKindOfClass: [COObject class]] && [object objectContext] != ctx)
  {
    return [ctx objectForUUID: [object uuid]];
  }
  return object;
}

static NSArray *EnsureObjectsAreFromContextInArray(NSArray *arr, COEditingContext *ctx)
{
  NSMutableArray *result = [NSMutableArray array];
  for (id obj in arr)
  {
    [result addObject: EnsureObjectIsFromContext(obj, ctx)];
  }
  return result;
}

static NSSet *EnsureObjectsAreFromContextInSet(NSSet *set, COEditingContext *ctx)
{
  NSMutableSet *result = [NSMutableSet set];
  for (id obj in set)
  {
    [result addObject: EnsureObjectIsFromContext(obj, ctx)];
  }
  return result;
}



/**
 * COObjectGraphEdit classes. These are simple wrapper objects.
 */

@interface COObjectGraphEdit : NSObject
{
  ETUUID *uuid;
  NSString *propertyName;
}
@property (nonatomic, retain) ETUUID *uuid;
@property (nonatomic, retain) NSString *propertyName;
- (void) applyToObject: (COObject*)obj;
@end

@implementation COObjectGraphEdit
@synthesize uuid;
@synthesize propertyName;
- (void) dealloc
{
  [uuid release];
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
  [r setUuid: u];
  return [r autorelease];
}
- (void) applyToObject: (COObject*)obj
{
  [obj setValue: nil forProperty: propertyName];
}
- (NSString *)description
{
  return [NSString stringWithFormat: @"%@:%@ remove", uuid, propertyName];
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
  [s setUuid: u];
  return [s autorelease];
}
- (void) applyToObject: (COObject*)obj
{
  [obj setValue: EnsureObjectIsFromContext(newValue, [obj objectContext]) forProperty: propertyName];
}
- (NSString *)description
{
  return [NSString stringWithFormat: @"%@:%@ set to '%@'", uuid, propertyName, newValue];
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
  [m setUuid: u];
  return [m autorelease];
}
- (void) applyToObject: (COObject*)obj
{
  // FIXME: slow
  NSArray *oldArray = [obj valueForProperty: propertyName];
  NSArray *temp = [diff arrayWithDiffAppliedTo: oldArray];
  NSArray *newArray = EnsureObjectsAreFromContextInArray(temp, [obj objectContext]); 
  
  [obj setValue: newArray
    forProperty: propertyName];
}
- (NSString *)description
{
  return [NSString stringWithFormat: @"%@:%@ modify array '%@'", uuid, propertyName, diff];
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
  [m setUuid: u];
  return [m autorelease];
}
- (void) applyToObject: (COObject*)obj
{
  NSSet *temp = [diff setWithDiffAppliedTo: [obj valueForProperty: propertyName]];
  NSSet *result = EnsureObjectsAreFromContextInSet(temp, [obj objectContext]);
  
  // FIXME: slow
  [obj setValue: result
    forProperty: propertyName];
}
- (NSString *)description
{
  return [NSString stringWithFormat: @"%@:%@ modify set '%@'", uuid, propertyName, diff];
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
  
  return self;
}

- (void)dealloc
{
  [_editsByPropertyAndUUID release];
  [super dealloc];
}

- (void)record: (COObjectGraphEdit*)edit
{
  NSMutableDictionary *propDict = [_editsByPropertyAndUUID objectForKey: [edit uuid]];
  if (nil == propDict)
  {
    assert([edit uuid] != nil);
    propDict = [NSMutableDictionary dictionary];
    [_editsByPropertyAndUUID setObject: propDict forKey: [edit uuid]];
  } 
  
  [propDict setObject: edit forKey: [edit propertyName]];
}

- (void)recordRemoveProperty: (NSString*)name ofObject: (ETUUID*)obj
{
  [self record: [COObjectGraphRemoveProperty removeProperty: name forUUID: obj]];
}
- (void)recordSetValue: (id)value forProperty: (NSString*)name ofObject: (ETUUID*)obj
{
  [self record: [COObjectGraphSetProperty setProperty:name to:value forUUID:obj]];
}
- (void)recordModifyArray: (COArrayDiff *)diff forProperty: (NSString*)name ofObject: (ETUUID*)obj
{
  [self record: [COObjectGraphModifyArray modifyArray:name diff:diff forUUID:obj]];
}
- (void)recordModifySet: (COSetDiff *)diff forProperty: (NSString*)name ofObject: (ETUUID*)obj
{
  [self record: [COObjectGraphModifySet modifySet:name diff:diff forUUID:obj]];
}

- (void)applyToContext: (COEditingContext*)ctx
{
  for (ETUUID *uuid in _editsByPropertyAndUUID)
  {
    NSDictionary *propDict = [_editsByPropertyAndUUID objectForKey: uuid];
    COObject *obj = [ctx objectForUUID: uuid];
    
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
 * Note this is nonrecursive, you must call it on COObjects contained inside as well
 */
+ (void) _diffObject: (COObject*)base with: (COObject*)other addToDiff: (COObjectGraphDiff*)diff
{
  assert(base != nil || other != nil);
  
  NSLog(@"Diff %@ with %@", base, other);
  
  if (base == nil)
  {
    // The object is being inserted, copy all property values
    for (NSString *prop in [other properties])
    {
      [diff recordSetValue: [other valueForProperty: prop] forProperty: prop ofObject: [other uuid]];
    }     
    return; 
  }
  else if (other == nil)
  {
    return; // The object was deleted.. but we don't bother recording this.
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
        [diff recordModifyArray: arrayDiff forProperty: prop ofObject: [base uuid]];
      }
      else if ([baseVal isKindOfClass: [NSSet class]] && [otherVal isKindOfClass: [NSSet class]])
      {
        COSetDiff *setDiff = [[[COSetDiff alloc] initWithFirstSet: (NSSet*)baseVal
                                                        secondSet: (NSSet*)otherVal] autorelease];
        [diff recordModifySet: setDiff forProperty: prop ofObject: [base uuid]];
      }
      else if (baseVal != nil && otherVal == nil)
      {
        [diff recordRemoveProperty: prop ofObject: [base uuid]];
      }
      else
      {
        [diff recordSetValue: otherVal forProperty: prop ofObject: [base uuid]];
      }
    }
  }  
}

+ (COObjectGraphDiff *)diffObjectContext: (COEditingContext*)base with: (COEditingContext*)modified;
{
  COObjectGraphDiff *result = [[[COObjectGraphDiff alloc] init] autorelease];
  
  assert(0);
  
  // FIXME: find all objects that could have changed between base and modified, 
  // and call a nonrecursive version of _diffObject
  
  // if there is a history link between the contexts, we can use a fast path
  // if not, we need to take the union of all UUIDs in each context.
  
  return result;
}

+ (COObjectGraphDiff *)diffHistoryNode: (COHistoryGraphNode*)n1 withHistoryNode: (COHistoryGraphNode*)n2
{
  // either n1 must be a parent of n2, or vice-versa
  BOOL n2IsParent = NO;
  COHistoryGraphNode *p=n1;
  while (p != nil && [[p parents] count] > 0)
  {    
    p = [[p parents] objectAtIndex: 0];
    if (p == n2)
    {
      n2IsParent = YES;
      break;
    }
  }
  
  if (!n2IsParent)
  {
    BOOL n1IsParent = NO;
    p = n2;
    while (p != nil && [[p parents] count] > 0)
    {    
      p = [[p parents] objectAtIndex: 0];
      if (p == n1)
      {
        n1IsParent = YES;
        break;
      }
    }  
    if (!n1IsParent)
    {
      NSLog(@"ERROR: +[COObjectGraphDiff diffHistoryNode:withHistoryNode:] failed, it requires n1 and n2 to be on the same line of history");
      assert(0);
      return nil;
    }
  }
  
  // Collect the UUIDs of all objects modified between (inclusive) the two nodes
  NSMutableSet *objectUUIDs = [NSMutableSet set];
  
  p = (n2IsParent ? n1 : n2);
  while (p != (n2IsParent ? n2 : n1))
  {
    [objectUUIDs addObjectsFromArray: [[p uuidToObjectVersionMaping] allKeys]];
    p = [[p parents] objectAtIndex: 0];
  }
  [objectUUIDs addObjectsFromArray: [[p uuidToObjectVersionMaping] allKeys]];
  
  // Create temporary object contexts
  
  COEditingContext *c1 = [[COEditingContext alloc] initWithHistoryGraphNode: n1];
  COEditingContext *c2 = [[COEditingContext alloc] initWithHistoryGraphNode: n2];
  
  // Now create the diff
  
  COObjectGraphDiff *result = [[[COObjectGraphDiff alloc] init] autorelease];
  for (ETUUID *uuid in objectUUIDs)
  {
    COObject *o1 = [c1 objectForUUID: uuid];
    COObject *o2 = [c2 objectForUUID: uuid];
    // either may be nil, but not both
    assert(o1 != nil || o2 != nil);
    [self _diffObject: o1 with: o2 addToDiff: result];
  }
  
  [c1 release];
  [c2 release];
  
  return result;
}

+ (COObjectGraphDiff *)diffObject: (COObject *)base with: (COObject *)other;
{
  COObjectGraphDiff *result = [[[COObjectGraphDiff alloc] init] autorelease];
  
  [self _diffObject: base with: other addToDiff: result];
  
  // FXIME: recursively find all objects (uuids) referenced inside base and other,
  // and diff all pairs of UUIDs found on both sides.
  
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

          [result recordModifyArray: [[[COArrayDiff alloc] initWithOperations: [merge nonconflictingOps]] autorelease] forProperty: prop ofObject: uuid];
        }
        else if ([edit1 isKindOfClass: [COObjectGraphModifySet class]] && [edit2 isKindOfClass: [COObjectGraphModifySet class]])
        {
          NSLog(@"Both are modifying set %@.. trying set merge", prop);
          COMergeResult *merge = [[(COObjectGraphModifySet*)edit1 diff] mergeWith: [(COObjectGraphModifySet*)edit2 diff]];

          [result recordModifySet: [[[COSetDiff alloc] initWithOperations: [merge nonconflictingOps]] autorelease] forProperty: prop ofObject: uuid];
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