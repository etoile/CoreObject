#import "COCommit.h"
#import "COSerializer.h"
#import "NSData+sha1.h"

const NSString *kCOAuthorHistoryGraphNodeProperty = @"COAuthorHistoryGraphNodeProperty";
const NSString *kCODateHistoryGraphNodeProperty = @"CODateHistoryGraphNodeProperty";
const NSString *kCOTypeHistoryGraphNodeProperty = @"COTypeHistoryGraphNodeProperty";
const NSString *kCOShortDescriptionHistoryGraphNodeProperty = @"COShortDescriptionHistoryGraphNodeProperty";
const NSString *kCODescriptionHistoryGraphNodeProperty = @"CODescriptionHistoryGraphNodeProperty";

const NSString *kCOTypeMinorEdit = @"COTypeMinorEdit";
const NSString *kCOTypeCheckpoint = @"COTypeCheckpoint";
const NSString *kCOTypeMerge = @"COTypeMerge";
const NSString *kCOTypeCreateBranch = @"COTypeCreateBranch";
const NSString *kCOTypeHidden = @"COTypeHidden";

@implementation COCommit

- (NSString*) description
{
	return [NSString stringWithFormat: @"<Commit UUID %@ affecting %d objects. metadata: '%@'>", 
		[[self commitUUID] stringValue],
		[_parentNodeUUIDsForObjectUUID count],
		_commitMetadata];
}

- (NSString*) detailedDescription
{
	NSMutableString *str = [NSMutableString string];
	for (ETUUID *uuid in [_parentNodeUUIDsForObjectUUID allKeys])	
	{
		[str appendFormat: @"Object %@:\n"];
		
		[str appendFormat: @"\tParents (%d):\n", (int)[[_parentNodeUUIDsForObjectUUID objectForKey: uuid] count]];
		for (ETUUID *commitUUID in [_parentNodeUUIDsForObjectUUID objectForKey: uuid])
		{
			[str appendFormat: @"\t\t%@\n", commitUUID];
		}
		[str appendFormat: @"\tBranches (%d):\n", (int)[[_childNodeUUIDsForObjectUUID objectForKey: uuid] count]];
		for (ETUUID *commitUUID in [_childNodeUUIDsForObjectUUID objectForKey: uuid])
		{
			[str appendFormat: @"\t\t%@\n", commitUUID];
		}
		[str appendFormat: @"\tObject Data:\n\t\t%@\n\n", 
			[COSerializer unserializeData: [_storeCoordinator->_store dataForKey: [[_objectUUIDToObjectVersionMaping objectForKey: uuid] hexString]]]]; // FIXME
	}
	return str;
}

- (BOOL) isEqual:(id)object
{
	if ([object isKindOfClass: [COCommit class]])
	{
		return [[self commitUUID] isEqual: [object commitUUID]];
	}
	return NO;
}

- (COStoreCoordinator *) storeCoordinator
{
	return _storeCoordinator;
}

static NSArray *ArrayWithCommitsForUUIDs(COStoreCoordinator *store, NSArray *uuids)
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity: [uuids count]];
	for (ETUUID *uuid in uuids)
	{
		COCommit *node = [store historyGraphNodeForUUID: uuid];
		assert(node != nil);
		[result addObject: node];
	}
	return result;		
}

- (COCommit *)parentCommitInObjectHistoryGraph: (ETUUID*)uuid
{
	NSArray *parents = ArrayWithCommitsForUUIDs(_storeCoordinator, [_parentNodeUUIDsForObjectUUID objectForKey: uuid]);
	if ([parents count] > 0)
	{
		return [parents firstObject];
	}
	else
	{
		return nil;
	}	
}

- (NSArray *)additionalParentCommitsInObjectHistoryGraph: (ETUUID*)uuid
{
	NSArray *parents = ArrayWithCommitsForUUIDs(_storeCoordinator, [_parentNodeUUIDsForObjectUUID objectForKey: uuid]);
	if ([parents count] > 1)
	{
		return [parents subarrayWithRange: NSMakeRange(1, [parents count] - 1)];
	}
	else
	{
		return [NSArray array];
	}
}

- (NSArray *)childCommitsInObjectHistoryGraph: (ETUUID*)uuid
{
	return ArrayWithCommitsForUUIDs(_storeCoordinator, [_childNodeUUIDsForObjectUUID objectForKey: uuid]);
}

- (NSDictionary *)objectUUIDToObjectVersionMaping;
{
	return _objectUUIDToObjectVersionMaping;
}

- (NSDictionary *)properties
{
	return _commitMetadata;
}
- (void)setValue: (NSObject*)value forProperty: (NSString*)property
{
	[_commitMetadata setValue: value forKey: property];
}

@end


@implementation COCommit (Factory)

+ (COCommit*)commitWithStoreCoordinator: (COStoreCoordinator*)sc
{
	return [[[COCommit alloc] initWithUUID: [ETUUID UUID]
						  storeCoordinator: sc
								properties: [NSDictionary dictionary]
			 parentNodeUUIDsForObjectUUIDs: [NSDictionary dictionary]
			  childNodeUUIDsForObjectUUIDs: [NSDictionary dictionary]
				 uuidToObjectVersionMaping: [NSDictionary dictionary]] autorelease];
}

- (void)  addObjectUUID: (ETUUID*)uuid
		  objectVersion: (NSData*)version
           parentCommit: (COCommit*)parent
additionalParentCommits: (NSArray*)additionalParents
{
	[_objectUUIDToObjectVersionMaping setObject: version forKey: uuid];

	NSMutableArray *parents = [NSMutableArray arrayWithObject: [parent commitUUID]];
	[parent addObjectsFromArray: [[additionalParents mappedCollection] commitUUID]]];
	[_parentNodeUUIDsForObjectUUID setObject: parents forKey: uuid];
}

@end


// FIXME: this code is a bit of a mess

static NSArray *ArrayWithUUIDsForUUIDStrings(NSArray *arr)
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity: [arr count]];
	for (NSString *str in arr)
	{
		assert([str isKindOfClass: [NSString class]]);
		[result addObject: [ETUUID UUIDWithString: str]];
	}
	return result;
}

static NSArray *ArrayWithUUIDStringsForUUIDs(NSArray *arr)
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity: [arr count]];
	for (ETUUID *uuid in arr)
	{
		assert([uuid isKindOfClass: [ETUUID class]]);
		[result addObject: [uuid stringValue]];
	}
	return result;
}

static NSArray *ArrayWithHexStringsForDatas(NSArray *arr)
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity: [arr count]];
	for (NSData *data in arr)
	{
		assert([data isKindOfClass: [NSData class]]);
		[result addObject: [data hexString]];
	}
	return result;
}

static NSArray *ArrayWithDatasForHexStrings(NSArray *arr)
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity: [arr count]];
	for (NSString *str in arr)
	{
		[result addObject: [NSData dataWithHexString: str]];
	}
	return result;
}

@implementation COCommit (Private)

- (id)		initWithUUID: (ETUUID*)uuid
		storeCoordinator: (COStoreCoordinator*)store
			  properties: (NSDictionary*)properties
	parentNodeUUIDsForObjectUUIDs: (NSDictionary*)parents
	childNodeUUIDsForObjectUUIDs: (NSDictionary*)children
	uuidToObjectVersionMaping: (NSDictionary*)mapping
{
	SUPERINIT;
	_commitUUID = [uuid retain];
	_storeCoordinator = store; // Weak reference
	_commitMetadata = [[NSMutableDictionary alloc] initWithDictionary: properties];
	
	_parentNodeUUIDsForObjectUUID = [[NSMutableDictionary alloc] initWithDictionary: parents copyItems: YES];
	_childNodeUUIDsForObjectUUID = [[NSMutableDictionary alloc] initWithDictionary: children copyItems: YES];	
	_objectUUIDToObjectVersionMaping = [[NSDictionary alloc] initWithDictionary: mapping];

	return self;
}

- (id) initWithPropertyList: (NSDictionary*)plist storeCoordinator: (COStoreCoordinator *)store
{
	NSDictionary *mapping = [NSDictionary dictionaryWithObjects: ArrayWithDatasForHexStrings([[plist valueForKey: @"mapping"] allObjects])
														forKeys: ArrayWithUUIDsForUUIDStrings([[plist valueForKey: @"mapping"] allKeys])];

	NSMutableDictionary *children = [NSMutableDictionary dictionary];
	for (NSString *key in [[plist valueForKey: @"childNodeUUIDsForObjectUUID"] allKeys])
	{
		[children setObject: ArrayWithUUIDsForUUIDStrings([[plist valueForKey: @"childNodeUUIDsForObjectUUID"] objectForKey: key])
					 forKey: [ETUUID UUIDWithString: key]];
		
	}
	
	NSMutableDictionary *parents = [NSMutableDictionary dictionary];
	for (NSString *key in [[plist valueForKey: @"parentNodeUUIDsForObjectUUID"] allKeys])
	{
		[parents setObject: ArrayWithUUIDsForUUIDStrings([[plist valueForKey: @"parentNodeUUIDsForObjectUUID"] objectForKey: key])
					 forKey: [ETUUID UUIDWithString: key]];
		
	}	
	
	return [self initWithUUID: [ETUUID UUIDWithString: [plist valueForKey: @"uuid"]]
			 storeCoordinator: store
				   properties: [plist valueForKey: @"properties"]
parentNodeUUIDsForObjectUUIDs: parents
 childNodeUUIDsForObjectUUIDs: children
	uuidToObjectVersionMaping: mapping];
}

- (NSDictionary *)propertyList
{
	NSDictionary *mapping = [NSDictionary dictionaryWithObjects: ArrayWithHexStringsForDatas([_objectUUIDToObjectVersionMaping allValues])
														forKeys: ArrayWithUUIDStringsForUUIDs([_objectUUIDToObjectVersionMaping allKeys])];
	
	NSMutableDictionary *children = [NSMutableDictionary dictionary];
	for (ETUUID *uuid in [_childNodeUUIDsForObjectUUID allKeys])
	{
		[children setObject: ArrayWithUUIDStringsForUUIDs([_childNodeUUIDsForObjectUUID objectForKey: uuid])
					 forKey: [uuid stringValue]];
		
	}
	
	NSMutableDictionary *parents = [NSMutableDictionary dictionary];
	for (ETUUID *uuid in [_parentNodeUUIDsForObjectUUID allKeys])
	{
		[parents setObject: ArrayWithUUIDStringsForUUIDs([_parentNodeUUIDsForObjectUUID objectForKey: uuid])
					forKey: [uuid stringValue]];
		
	}	
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[_commitUUID stringValue], @"uuid",
			_commitMetadata, @"properties",
			parents, @"parentNodeUUIDsForObjectUUID",
			children, @"childNodeUUIDsForObjectUUID",
			mapping, @"mapping",
			nil];
}

- (ETUUID*)commitUUID
{
	return _commitUUID;
}

- (void) dealloc
{
	[_commitUUID release];
	[_commitMetadata release];
	[_parentNodeUUIDsForObjectUUID release];
	[_childNodeUUIDsForObjectUUID release];
	[_objectUUIDToObjectVersionMaping release];
	[super dealloc];
}

- (void) addChildCommitUUID: (ETUUID*)commit inObjectHistoryGraph: (ETUUID*)obj
{
	assert([commit isKindOfClass: [ETUUID class]]);
	assert([obj isKindOfClass: [ETUUID class]]);
	
	NSMutableArray *commits = [NSMutableArray arrayWithArray: [_childNodeUUIDsForObjectUUID objectForKey: obj]];
	[commits addObject: commit];
	[_childNodeUUIDsForObjectUUID setObject: commit forKey: obj];
}

@end