#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COGroup.h"
#import "COCollection.h"
#import "TestCommon.h"

@interface TestGroup : NSObject <UKTest>
{
}
@end

@implementation TestGroup

- (void)testGroup
{
	COStore *store = [[COStore alloc] initWithURL: STORE_URL];
	COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
	COGroup *obj = [ctx insertObjectWithEntityName: @"Anonymous.COGroup"];
	UKNotNil(obj);	

	[ctx release];
	[store release];
	DELETE_STORE;
}

- (void)testCollection
{
	COStore *store = [[COStore alloc] initWithURL: STORE_URL];
	COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
	COCollection *obj = [ctx insertObjectWithEntityName: @"Anonymous.COCollection"];
	UKNotNil(obj);
	[ctx release];
	[store release];
	DELETE_STORE;
}

@end
