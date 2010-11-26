#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "TestCommon.h"

@interface TestEditingContext : NSObject <UKTest>
{
}
@end

@implementation TestEditingContext

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
	UKTrue([obj isKindOfClass: [COObject class]]);
	
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


@end
