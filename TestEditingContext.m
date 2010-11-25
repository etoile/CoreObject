#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "TestCommon.h"

@interface TestEditingContext : NSObject <UKTest>
{
}
@end

@implementation TestEditingContext

static COEditingContext *NewContext()
{
	COStore *store = [[[COStore alloc] initWithURL: STORE_URL] autorelease];
	assert(store != nil);
	return [[COEditingContext alloc] initWithStore: store];
}

static void TearDownContext(COEditingContext *ctx)
{
	assert(ctx != nil);
	[ctx release];
	DELETE_STORE;
}



- (id) init
{
	self = [super init];
	return self;
}
- (void)testCreate
{
	COEditingContext *ctx = NewContext();
	UKNotNil(ctx);
	TearDownContext(ctx);
}

- (void)testInsertObject
{
	COEditingContext *ctx = NewContext();
	UKFalse([ctx hasChanges]);
	
	
	COObject *obj = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	UKNotNil(obj);
	UKObjectsSame([COObject class], [obj class]);
	
	NSArray *expectedProperties = [NSArray arrayWithObjects: @"parentGroup", @"parentCollections", @"contents", @"label", nil];
	UKObjectsEqual([NSSet setWithArray: expectedProperties],
				   [NSSet setWithArray: [obj properties]]);

	UKObjectsSame(obj, [ctx objectWithUUID: [obj UUID]]);
	
	UKTrue([ctx hasChanges]);
	
	TearDownContext(ctx);
}

- (void)testBasicPersistence
{
	ETUUID *objUUID;
	
	{
		COStore *store = [[COStore alloc] initWithURL: STORE_URL];
		COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
		COObject *obj = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
		objUUID = [[obj UUID] retain];
		[obj setValue: @"Hello" forProperty: @"label"];
		[ctx commit];
		[ctx release];
		[store release];
	}
	
	{
		COStore *store = [[COStore alloc] initWithURL: STORE_URL];
		COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
		COObject *obj = [ctx objectWithUUID: objUUID];
		UKNotNil(obj);
		NSArray *expectedProperties = [NSArray arrayWithObjects: @"parentGroup", @"parentCollections", @"contents", @"label", nil];
		UKObjectsEqual([NSSet setWithArray: expectedProperties],
					   [NSSet setWithArray: [obj properties]]);
		UKStringsEqual(@"Hello", [obj valueForProperty: @"label"]);
		[ctx release];
		[store release];
	}
	[objUUID release];
	DELETE_STORE;
}

- (void)testHistoryTracks
{
	COEditingContext *ctx = NewContext();
	
	COObject *container = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *subcontainer1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *subcontainer2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COObject *leaf1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COObject *leaf2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];	
	COObject *leaf3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	
	
	
	TearDownContext(ctx);
}

@end
