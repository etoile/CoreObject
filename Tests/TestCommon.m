#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"
#import "COObject+Private.h"
#import "COObject+RelationshipCache.h"
#import "COPersistentRoot.h"
#import "COSQLiteStore.h"
#import "TestCommon.h"

NSString * const kCOLabel = @"label";
NSString * const kCOContents = @"contents";
NSString * const kCOParent = @"parentContainer";

@implementation SQLiteStoreTestCase

+ (void) initialize
{
    if (self == [SQLiteStoreTestCase class])
    {
        [self deleteStore];
    }
}

- (id) init
{
    self = [super init];
    
    store = [[COSQLiteStore alloc] initWithURL: [SQLiteStoreTestCase storeURL]];
    [store clearStore];
    
    return self;
}

+ (void) deleteStore
{
	[[NSFileManager defaultManager] removeItemAtURL: [self storeURL] error: NULL];
}

+ (NSURL *) storeURL
{
	return [NSURL fileURLWithPath: [@"~/TestStore.sqlite" stringByExpandingTildeInPath]];
}

@end

@implementation EditingContextTestCase

- (id) init
{
	SUPERINIT;
	ctx = [[COEditingContext alloc] initWithStore: store];
    return self;
}

- (void) testBranchWithExistingAndNewContext: (COBranch *)aBranch
									 inBlock: (void (^)(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext))block
{
	block([aBranch editingContext], [aBranch persistentRoot], aBranch, NO);
	
	// Create a second, isolated context that opens a new store object
	// at the current one's URL
	
	COEditingContext *ctx2 = [COEditingContext contextWithURL: [[[aBranch persistentRoot] store] URL]];
	COPersistentRoot *ctx2PersistentRoot = [ctx2 persistentRootForUUID: [[aBranch persistentRoot] UUID]];
	COBranch *ctx2Branch = [ctx2PersistentRoot branchForUUID: [aBranch UUID]];
	
	// Run the tests again
	
	block(ctx2, ctx2PersistentRoot, ctx2Branch, YES);
}

- (void) testPersistentRootWithExistingAndNewContext: (COPersistentRoot *)aPersistentRoot
											 inBlock: (void (^)(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext))block
{
	[self testBranchWithExistingAndNewContext: [aPersistentRoot editingBranch]
									  inBlock: block];
}

@end

@implementation COObjectGraphContext (TestCommon)

- (id)insertObjectWithEntityName: (NSString *)aFullName
{
    return [self insertObjectWithEntityName: aFullName UUID: [ETUUID UUID]];
}

- (id)insertObjectWithEntityName: (NSString *)aFullName
                            UUID: (ETUUID *)aUUID
{
    ETEntityDescription *desc = [[self modelRepository] descriptionForName: aFullName];
    if (desc == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"Entity name %@ invalid", aFullName];
	}
	Class objClass = [[self modelRepository] classForEntityDescription: desc];
    
    /* Nil root object means the new object will be a root */
	COObject *obj = [[objClass alloc] initWithUUID: aUUID
                                 entityDescription: desc
                                objectGraphContext: self];
    
    [obj addCachedOutgoingRelationships];
    
	return obj;
}

@end
